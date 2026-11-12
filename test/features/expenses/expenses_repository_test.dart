import 'package:flutter_test/flutter_test.dart';
import 'package:lucid_core_flutter/lucid_core_flutter.dart' show LucidRecurrence, LucidRecurrenceUnit;
import 'package:palier/data/database.dart';
import 'package:palier/features/expenses/data/expenses_repository.dart';
import 'package:palier/features/expenses/domain/expense_kinds.dart';
import 'package:palier/features/expenses/domain/expenses.dart';
import 'package:palier/features/expenses/domain/recurring.dart';
import 'package:palier/features/expenses/domain/starter_kit.dart';
import 'package:palier/features/profiles/data/profiles_repository.dart';
import 'package:palier/features/profiles/domain/profile.dart';

import '../../helpers/test_database.dart';

void main() {
  late PalierDatabase db;
  late ExpensesRepository repo;
  late DateTime now;
  late String ama;

  setUp(() async {
    db = openTestDatabase();
    now = DateTime.utc(2026, 11, 9, 9);
    repo = ExpensesRepository(db, clock: () => now);
    ama = (await ProfilesRepository(db).create(const ProfileDraft(name: 'Ama'))).id;
  });

  tearDown(() => db.close());

  OperationDraft spend(int amount, String account, String category, {DateTime? at}) => OperationDraft(
    kind: OperationKind.expense,
    amount: amount,
    accountId: account,
    categoryId: category,
    occurredAt: at ?? now,
  );

  group('kit de départ', () {
    test('donne un compte Espèces et les catégories courantes', () async {
      await repo.ensureStarterKit(ama);

      final accounts = await repo.watchAccounts(ama).first;
      expect(accounts.single.name, 'Espèces');
      expect(accounts.single.kind, AccountKind.cash);
      final categories = await repo.watchCategories(ama).first;
      expect(categories.map((c) => c.name), StarterKit.categories.map((c) => c.name));
      expect(await repo.watchCategories(ama, kind: CategoryKind.income).first, hasLength(4));
    });

    test('ne revient pas une seconde fois, même après suppression', () async {
      await repo.ensureStarterKit(ama);
      for (final category in await repo.watchCategories(ama).first) {
        await repo.deleteCategory(category.id);
      }

      await repo.ensureStarterKit(ama);

      expect(await repo.watchCategories(ama).first, isEmpty);
      expect(await repo.watchAccounts(ama).first, hasLength(1));
    });
  });

  group('soldes', () {
    test('partent du solde de départ et suivent dépenses, revenus et virements', () async {
      final cash = await repo.createAccount(ama, const AccountDraft(name: 'Espèces', openingBalance: 20000));
      final momo = await repo.createAccount(ama, const AccountDraft(name: 'MoMo', kind: AccountKind.mobileMoney));
      final food = await repo.createCategory(
        ama,
        const CategoryDraft(name: 'Alimentation', kind: CategoryKind.expense, icon: 'basket'),
      );
      final salary = await repo.createCategory(
        ama,
        const CategoryDraft(name: 'Salaire', kind: CategoryKind.income, icon: 'salary'),
      );

      await repo.addOperation(ama, spend(3500, cash.id, food.id));
      await repo.addOperation(
        ama,
        OperationDraft(
          kind: OperationKind.income,
          amount: 50000,
          accountId: momo.id,
          categoryId: salary.id,
          occurredAt: now,
        ),
      );
      await repo.addOperation(
        ama,
        OperationDraft(
          kind: OperationKind.transfer,
          amount: 10000,
          accountId: momo.id,
          toAccountId: cash.id,
          occurredAt: now,
        ),
      );

      final balances = {for (final a in await repo.watchAccounts(ama).first) a.name: a.balance};
      expect(balances, {'Espèces': 20000 - 3500 + 10000, 'MoMo': 50000 - 10000});
    });

    test('ignorent une opération supprimée, et la retrouvent si on annule', () async {
      final cash = await repo.createAccount(ama, const AccountDraft(name: 'Espèces', openingBalance: 1000));
      final food = await repo.createCategory(
        ama,
        const CategoryDraft(name: 'Alimentation', kind: CategoryKind.expense, icon: 'basket'),
      );
      final id = await repo.addOperation(ama, spend(400, cash.id, food.id));

      await repo.deleteOperation(id);
      expect((await repo.watchAccounts(ama).first).single.balance, 1000);
      expect(await repo.findOperation(id), isNull);

      await repo.restoreOperation(id);
      expect((await repo.watchAccounts(ama).first).single.balance, 600);
    });

    test('ne mélangent pas les profils', () async {
      final kofi = (await ProfilesRepository(db).create(const ProfileDraft(name: 'Kofi'))).id;
      await repo.ensureStarterKit(ama);
      await repo.ensureStarterKit(kofi);
      final amaCash = (await repo.watchAccounts(ama).first).single;
      final amaFood = (await repo.watchCategories(ama).first).first;
      await repo.addOperation(ama, spend(700, amaCash.id, amaFood.id));

      expect((await repo.watchAccounts(kofi).first).single.balance, 0);
      expect(await repo.hasOperations(kofi), isFalse);
      expect(await repo.hasOperations(ama), isTrue);
    });
  });

  group('opérations', () {
    late Account cash;
    late Category food;

    setUp(() async {
      cash = await repo.createAccount(ama, const AccountDraft(name: 'Espèces'));
      food = await repo.createCategory(
        ama,
        const CategoryDraft(name: 'Alimentation', kind: CategoryKind.expense, icon: 'basket'),
      );
    });

    test('ne garde que celles du mois, la plus récente d’abord', () async {
      await repo.addOperation(ama, spend(100, cash.id, food.id, at: DateTime(2026, 10, 31, 23, 30)));
      await repo.addOperation(ama, spend(200, cash.id, food.id, at: DateTime(2026, 11, 1, 0, 10)));
      await repo.addOperation(ama, spend(300, cash.id, food.id, at: DateTime(2026, 11, 30, 23, 50)));
      await repo.addOperation(ama, spend(400, cash.id, food.id, at: DateTime(2026, 12)));

      final (from, to) = MonthView.bounds(DateTime(2026, 11));
      final entries = await repo.watchOperations(ama, from: from, to: to).first;

      expect(entries.map((e) => e.amount), [300, 200]);
      expect(entries.first.categoryName, 'Alimentation');
      expect(entries.first.accountName, 'Espèces');
    });

    test('se modifient, et un virement perd sa catégorie', () async {
      final momo = await repo.createAccount(ama, const AccountDraft(name: 'MoMo', kind: AccountKind.mobileMoney));
      final id = await repo.addOperation(ama, spend(1000, cash.id, food.id));
      now = now.add(const Duration(minutes: 5));

      await repo.updateOperation(
        id,
        OperationDraft(
          kind: OperationKind.transfer,
          amount: 2000,
          accountId: cash.id,
          toAccountId: momo.id,
          categoryId: food.id,
          note: '  dépôt  ',
          occurredAt: now,
        ),
      );

      final updated = (await repo.findOperation(id))!;
      expect(updated.kind, OperationKind.transfer);
      expect(updated.amount, 2000);
      expect(updated.categoryId, isNull);
      expect(updated.toAccountName, 'MoMo');
      expect(updated.note, 'dépôt');
    });

    test('refusent une opération incomplète', () async {
      expect(() => repo.addOperation(ama, spend(0, cash.id, food.id)), throwsArgumentError);
    });

    test('gardent le nom d’une catégorie supprimée', () async {
      final id = await repo.addOperation(ama, spend(1000, cash.id, food.id));
      await repo.deleteCategory(food.id);

      expect((await repo.findOperation(id))!.categoryName, 'Alimentation');
      expect(await repo.watchCategories(ama).first, isEmpty);
    });
  });

  group('frais d’un virement', () {
    late Account wave;
    late Account mtn;

    setUp(() async {
      wave = await repo.createAccount(
        ama,
        const AccountDraft(name: 'Wave', kind: AccountKind.mobileMoney, openingBalance: 50000),
      );
      mtn = await repo.createAccount(ama, const AccountDraft(name: 'MTN', kind: AccountKind.mobileMoney));
    });

    OperationDraft send(int amount, {int fee = 0}) => OperationDraft(
      kind: OperationKind.transfer,
      amount: amount,
      accountId: wave.id,
      toAccountId: mtn.id,
      occurredAt: now,
      fee: fee,
    );

    test('sortent du compte de départ, en dépense « Frais et taxes »', () async {
      await repo.addOperation(ama, send(20000, fee: 300));

      final balances = {for (final a in await repo.watchAccounts(ama).first) a.name: a.balance};
      expect(balances, {'Wave': 50000 - 20000 - 300, 'MTN': 20000});
      final (from, to) = MonthView.bounds(now);
      final month = await repo.watchOperations(ama, from: from, to: to).first;
      final fee = month.singleWhere((e) => e.kind == OperationKind.expense);
      expect(fee.amount, 300);
      expect(fee.accountId, wave.id);
      expect(fee.categoryName, StarterKit.feesCategory.name);
      expect(fee.note, 'Frais du virement vers MTN');
      expect(month.where((e) => e.kind == OperationKind.transfer).single.amount, 20000);
    });

    test('réutilisent la catégorie des frais, et la recréent si elle a été supprimée', () async {
      await repo.addOperation(ama, send(1000, fee: 100));
      await repo.addOperation(ama, send(1000, fee: 100));
      final fees = (await repo.watchCategories(ama).first).where((c) => c.name == StarterKit.feesCategory.name);
      expect(fees, hasLength(1));

      await repo.deleteCategory(fees.single.id);
      await repo.addOperation(ama, send(1000, fee: 100));
      expect(
        (await repo.watchCategories(ama).first).where((c) => c.name == StarterKit.feesCategory.name),
        hasLength(1),
      );
    });

    test('sans frais, ou hors virement, aucune dépense en plus', () async {
      await repo.addOperation(ama, send(1000));
      final food = await repo.createCategory(
        ama,
        const CategoryDraft(name: 'Alimentation', kind: CategoryKind.expense, icon: 'basket'),
      );
      await repo.addOperation(
        ama,
        OperationDraft(
          kind: OperationKind.expense,
          amount: 500,
          accountId: wave.id,
          categoryId: food.id,
          occurredAt: now,
          fee: 200,
        ),
      );

      final (from, to) = MonthView.bounds(now);
      expect(await repo.watchOperations(ama, from: from, to: to).first, hasLength(2));
    });
  });

  group('comptes', () {
    test('se suppriment seulement sans opération', () async {
      final cash = await repo.createAccount(ama, const AccountDraft(name: 'Espèces'));
      final bank = await repo.createAccount(ama, const AccountDraft(name: 'Banque', kind: AccountKind.bank));
      final food = await repo.createCategory(
        ama,
        const CategoryDraft(name: 'Alimentation', kind: CategoryKind.expense, icon: 'basket'),
      );
      await repo.addOperation(ama, spend(1000, cash.id, food.id));

      await expectLater(repo.deleteAccount(cash.id), throwsA(isA<AccountInUseException>()));
      await repo.deleteAccount(bank.id);

      expect((await repo.watchAccounts(ama).first).map((a) => a.name), ['Espèces']);
    });

    test('se modifient et gardent leur ordre de création', () async {
      final cash = await repo.createAccount(ama, const AccountDraft(name: 'Espèces'));
      await repo.createAccount(ama, const AccountDraft(name: 'Banque', kind: AccountKind.bank));

      await repo.updateAccount(cash.id, const AccountDraft(name: 'Porte-monnaie', openingBalance: 5000));

      final accounts = await repo.watchAccounts(ama).first;
      expect(accounts.map((a) => a.name), ['Porte-monnaie', 'Banque']);
      expect(accounts.first.balance, 5000);
    });

    test('d’épargne : les virements reçus remplissent l’objectif', () async {
      final momo = await repo.createAccount(
        ama,
        const AccountDraft(name: 'MoMo', kind: AccountKind.mobileMoney, openingBalance: 60000),
      );
      final tabaski = await repo.createAccount(
        ama,
        const AccountDraft(name: 'Tabaski', kind: AccountKind.savings, openingBalance: 10000, goal: 100000),
      );
      await repo.addOperation(
        ama,
        OperationDraft(
          kind: OperationKind.transfer,
          amount: 15000,
          accountId: momo.id,
          toAccountId: tabaski.id,
          occurredAt: now,
        ),
      );

      final saved = (await repo.watchAccounts(ama).first).firstWhere((a) => a.id == tabaski.id);
      expect((saved.balance, saved.goal, saved.goalProgress), (25000, 100000, 0.25));
    });

    test('seul un compte d’épargne garde un objectif', () async {
      final bank = await repo.createAccount(
        ama,
        const AccountDraft(name: 'Banque', kind: AccountKind.bank, goal: 5000),
      );
      expect(bank.goal, isNull);

      final box = await repo.createAccount(
        ama,
        const AccountDraft(name: 'Projet', kind: AccountKind.savings, goal: 50000),
      );
      // Redevenu compte courant, il perd son objectif ; sans montant, il n'en a pas.
      await repo.updateAccount(box.id, const AccountDraft(name: 'Projet', kind: AccountKind.bank, goal: 50000));
      expect((await repo.watchAccounts(ama).first).map((a) => a.goal), [null, null]);
      await repo.updateAccount(box.id, const AccountDraft(name: 'Projet', kind: AccountKind.savings));
      final reread = (await repo.watchAccounts(ama).first).last;
      expect((reread.goal, reread.goalProgress), (null, null));
    });
  });

  group('plafonds', () {
    late String cash;
    late Category food;
    late Category transport;

    setUp(() async {
      await repo.ensureStarterKit(ama);
      cash = (await repo.watchAccounts(ama).first).single.id;
      final expenses = await repo.watchCategories(ama, kind: CategoryKind.expense).first;
      food = expenses[0];
      transport = expenses[1];
    });

    test('un plafond par catégorie, dans l’ordre des catégories', () async {
      await repo.setBudget(ama, transport.id, 20000);
      await repo.setBudget(ama, food.id, 60000);

      final budgets = await repo.watchBudgets(ama).first;
      expect(budgets.map((b) => (b.categoryName, b.amount)), [(food.name, 60000), (transport.name, 20000)]);
      expect(budgets.first.categoryIcon, food.icon);
    });

    test('changer, retirer puis remettre un plafond garde une seule ligne', () async {
      await repo.setBudget(ama, food.id, 60000);
      await repo.setBudget(ama, food.id, 45000);
      expect((await repo.watchBudgets(ama).first).single.amount, 45000);

      await repo.removeBudget(food.id);
      expect(await repo.watchBudgets(ama).first, isEmpty);

      await repo.setBudget(ama, food.id, 50000);
      expect((await repo.watchBudgets(ama).first).single.amount, 50000);
      expect(await db.select(db.budgets).get(), hasLength(1));
    });

    test('une catégorie supprimée emporte son plafond', () async {
      await repo.setBudget(ama, food.id, 60000);
      await repo.deleteCategory(food.id);
      expect(await repo.watchBudgets(ama).first, isEmpty);
    });

    test('ce qu’une catégorie a coûté sur une période, suppressions exclues', () async {
      final (from, to) = MonthView.bounds(DateTime(2026, 11));
      await repo.addOperation(ama, spend(12000, cash, food.id));
      await repo.addOperation(ama, spend(3000, cash, food.id, at: DateTime.utc(2026, 10, 31, 12)));
      final removed = await repo.addOperation(ama, spend(500, cash, food.id));
      await repo.deleteOperation(removed);
      await repo.addOperation(ama, spend(700, cash, transport.id));

      expect(await repo.spentIn(ama, food.id, from: from, to: to), 12000);
      expect(await repo.spentIn(ama, 'aucune', from: from, to: to), 0);
    });
  });

  group('récurrences', () {
    late String cash;
    late String rent;

    setUp(() async {
      await repo.ensureStarterKit(ama);
      cash = (await repo.watchAccounts(ama).first).single.id;
      rent = (await repo.watchCategories(ama).first).first.id;
    });

    final monthly = LucidRecurrence(unit: LucidRecurrenceUnit.month, start: DateTime(2026, 1, 1));

    /// Fait [action] comme si l'on était le [day], puis revient au 9 novembre.
    Future<T> on<T>(DateTime day, Future<T> Function() action) async {
      final today = now;
      now = day.toUtc();
      try {
        return await action();
      } finally {
        now = today;
      }
    }

    test('une récurrence créée après son début n’en réclame pas les échéances passées', () async {
      await repo.createRecurring(
        ama,
        RecurringDraft(
          kind: OperationKind.expense,
          amount: 45000,
          accountId: cash,
          categoryId: rent,
          rule: LucidRecurrence(unit: LucidRecurrenceUnit.month, start: DateTime(2026, 11, 5)),
        ),
      );
      final recurring = (await repo.watchRecurrings(ama).first).single;
      expect(duesUntil([recurring], now), isEmpty, reason: 'le 5 est passé avant sa création, le 9');
      expect(recurring.nextFrom(DateTime(2026, 11, 9)), DateTime(2026, 12, 5));
    });

    test('« Répéter » crée la récurrence, et l’opération règle sa première échéance', () async {
      await on(
        DateTime(2026, 10, 5, 10),
        () => repo.addOperation(ama, spend(45000, cash, rent, at: DateTime(2026, 10, 5, 9)), repeat: monthly),
      );

      final recurring = (await repo.watchRecurrings(ama).first).single;
      expect(recurring.rule.start, DateTime(2026, 10, 5));
      expect(recurring.amount, 45000);
      expect(recurring.settled, {DateTime(2026, 10, 5)});
      // Le 9 novembre : l'échéance du 5 attend.
      expect(duesUntil([recurring], now).map((d) => d.day), [DateTime(2026, 11, 5)]);

      final (from, to) = MonthView.bounds(DateTime(2026, 10));
      final first = (await repo.watchOperations(ama, from: from, to: to).first).single;
      expect((first.recurrenceId, first.dueOn), (recurring.id, DateTime(2026, 10, 5)));
    });

    test('régler une échéance la retire ; supprimer l’opération la fait revenir', () async {
      await on(
        DateTime(2026, 10, 5, 10),
        () => repo.addOperation(ama, spend(45000, cash, rent, at: DateTime(2026, 10, 5, 9)), repeat: monthly),
      );
      var recurring = (await repo.watchRecurrings(ama).first).single;
      final due = duesUntil([recurring], now).single;

      final paid = await repo.addOperation(ama, recurring.draftFor(due.day), due: due);
      recurring = (await repo.watchRecurrings(ama).first).single;
      expect(duesUntil([recurring], now), isEmpty);

      await repo.deleteOperation(paid);
      recurring = (await repo.watchRecurrings(ama).first).single;
      expect(duesUntil([recurring], now), [due]);
    });

    test('passer une échéance, puis l’annuler, puis la repasser', () async {
      await on(
        DateTime(2026, 10, 5, 10),
        () => repo.addOperation(ama, spend(45000, cash, rent, at: DateTime(2026, 10, 5, 9)), repeat: monthly),
      );
      Future<List<Due>> dues() async => duesUntil(await repo.watchRecurrings(ama).first, now);
      final due = (await dues()).single;

      await repo.skipDue(ama, due);
      expect(await dues(), isEmpty);
      await repo.unskipDue(due);
      expect(await dues(), [due]);
      await repo.skipDue(ama, due);
      expect(await dues(), isEmpty);
    });

    test('changer la règle fait compter les échéances à partir d’aujourd’hui', () async {
      final id = await on(
        DateTime(2026, 11, 2, 8),
        () => repo.createRecurring(
          ama,
          RecurringDraft(
            kind: OperationKind.expense,
            amount: 3000,
            accountId: cash,
            categoryId: rent,
            rule: LucidRecurrence(unit: LucidRecurrenceUnit.week, start: DateTime(2026, 11, 2)),
          ),
        ),
      );
      final before = (await repo.watchRecurrings(ama).first).single;
      expect(duesUntil([before], now).map((d) => d.day), [DateTime(2026, 11, 2), DateTime(2026, 11, 9)]);

      // Le montant seul ne touche pas aux échéances.
      await repo.updateRecurring(id, RecurringDraft.fromOperation(before.draftFor(DateTime(2026, 11, 2)), before.rule));
      expect((await repo.watchRecurrings(ama).first).single.dueFrom, DateTime(2026, 11, 2));

      final daily = before.toDraft();
      await repo.updateRecurring(
        id,
        RecurringDraft(
          kind: daily.kind,
          amount: daily.amount,
          accountId: daily.accountId,
          categoryId: daily.categoryId,
          rule: daily.rule.copyWith(start: DateTime(2026, 11, 3)),
        ),
      );
      final after = (await repo.watchRecurrings(ama).first).single;
      expect(after.dueFrom, DateTime(2026, 11, 9));
      expect(duesUntil([after], now), isEmpty, reason: 'le mardi 10 n’est pas encore arrivé');
    });

    test('supprimer une récurrence s’annule, et un compte qui en porte une reste', () async {
      final id = await repo.createRecurring(
        ama,
        RecurringDraft(kind: OperationKind.expense, amount: 3000, accountId: cash, categoryId: rent, rule: monthly),
      );
      await expectLater(repo.deleteAccount(cash), throwsA(isA<AccountInUseException>()));

      await repo.deleteRecurring(id);
      expect(await repo.watchRecurrings(ama).first, isEmpty);
      expect(await repo.findRecurring(id), isNull);
      await repo.restoreRecurring(id);
      expect((await repo.findRecurring(id))?.amount, 3000);
    });
  });
}

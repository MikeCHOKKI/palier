import 'package:flutter_test/flutter_test.dart';
import 'package:palier/data/database.dart';
import 'package:palier/features/expenses/data/expenses_repository.dart';
import 'package:palier/features/expenses/domain/expense_kinds.dart';
import 'package:palier/features/expenses/domain/expenses.dart';
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
  });
}

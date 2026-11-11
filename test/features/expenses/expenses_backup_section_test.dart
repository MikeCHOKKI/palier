import 'package:flutter_test/flutter_test.dart';
import 'package:lucid_core_flutter/lucid_core_flutter.dart' show LucidRecurrence, LucidRecurrenceUnit;
import 'package:palier/app/providers.dart';
import 'package:palier/data/database.dart';
import 'package:palier/features/backup/data/backup_service.dart';
import 'package:palier/features/backup/domain/backup_codec.dart';
import 'package:palier/features/expenses/data/expenses_repository.dart';
import 'package:palier/features/expenses/domain/expense_kinds.dart';
import 'package:palier/features/expenses/domain/expenses.dart';
import 'package:palier/features/expenses/domain/recurring.dart';
import 'package:palier/features/profiles/data/profiles_repository.dart';
import 'package:palier/features/profiles/domain/profile.dart';

import '../../helpers/test_database.dart';

void main() {
  const password = 'lune-baobab-42';

  BackupService serviceFor(PalierDatabase db) =>
      BackupService(db, codec: const BackupCodec(iterations: 1000), sections: backupSections(db));

  test('les comptes, catégories et opérations suivent le profil sur un autre téléphone', () async {
    final phone = openTestDatabase();
    addTearDown(phone.close);
    final expenses = ExpensesRepository(phone);
    final ama = await ProfilesRepository(phone).create(const ProfileDraft(name: 'Ama'));
    await expenses.ensureStarterKit(ama.id);
    final cash = (await expenses.watchAccounts(ama.id).first).single;
    final momo = await expenses.createAccount(ama.id, const AccountDraft(name: 'MoMo', kind: AccountKind.mobileMoney));
    await expenses.createAccount(ama.id, const AccountDraft(name: 'Tabaski', kind: AccountKind.savings, goal: 100000));
    final food = (await expenses.watchCategories(ama.id).first).first;
    await expenses.addOperation(
      ama.id,
      OperationDraft(
        kind: OperationKind.expense,
        amount: 2500,
        accountId: cash.id,
        categoryId: food.id,
        note: 'marché',
        occurredAt: DateTime.utc(2026, 11, 9, 10),
      ),
    );
    final deleted = await expenses.addOperation(
      ama.id,
      OperationDraft(
        kind: OperationKind.transfer,
        amount: 1000,
        accountId: cash.id,
        toAccountId: momo.id,
        occurredAt: DateTime.utc(2026, 11, 9),
      ),
    );
    await expenses.deleteOperation(deleted);
    await expenses.setBudget(ama.id, food.id, 60000);

    final file = await serviceFor(phone).exportProfile(ama.id, password);

    final newPhone = openTestDatabase();
    addTearDown(newPhone.close);
    final service = serviceFor(newPhone);
    await service.import(await service.open(file, password));

    final restored = ExpensesRepository(newPhone);
    final balances = {for (final a in await restored.watchAccounts(ama.id).first) a.name: a.balance};
    expect(balances, {'Espèces': -2500, 'MoMo': 0, 'Tabaski': 0});
    final goals = {for (final a in await restored.watchAccounts(ama.id).first) a.name: a.goal};
    expect(goals, {'Espèces': null, 'MoMo': null, 'Tabaski': 100000});
    expect(await restored.watchCategories(ama.id).first, await expenses.watchCategories(ama.id).first);
    final (from, to) = MonthView.bounds(DateTime(2026, 11));
    final entries = await restored.watchOperations(ama.id, from: from, to: to).first;
    expect(entries.single.note, 'marché');
    expect(entries.single.occurredAt, DateTime.utc(2026, 11, 9, 10));
    expect((await restored.watchBudgets(ama.id).first).single.amount, 60000);
  });

  test('un import remplace les dépenses du profil au lieu de les additionner', () async {
    final phone = openTestDatabase();
    addTearDown(phone.close);
    final expenses = ExpensesRepository(phone);
    final ama = await ProfilesRepository(phone).create(const ProfileDraft(name: 'Ama'));
    await expenses.ensureStarterKit(ama.id);
    final file = await serviceFor(phone).exportProfile(ama.id, password);

    await expenses.createAccount(ama.id, const AccountDraft(name: 'Banque', kind: AccountKind.bank));
    // Un plafond posé après l'export pointe vers une catégorie que l'import remplace.
    final food = (await expenses.watchCategories(ama.id).first).first;
    await expenses.setBudget(ama.id, food.id, 60000);
    await serviceFor(phone).import(await serviceFor(phone).open(file, password));

    expect((await expenses.watchAccounts(ama.id).first).map((a) => a.name), ['Espèces']);
    expect(await expenses.watchCategories(ama.id).first, hasLength(15));
    expect(await expenses.watchBudgets(ama.id).first, isEmpty);
  });

  test('les récurrences et leurs échéances passées suivent le profil', () async {
    final phone = openTestDatabase();
    addTearDown(phone.close);
    var now = DateTime.utc(2026, 9, 5, 11);
    final expenses = ExpensesRepository(phone, clock: () => now);
    final ama = await ProfilesRepository(phone).create(const ProfileDraft(name: 'Ama'));
    await expenses.ensureStarterKit(ama.id);
    final cash = (await expenses.watchAccounts(ama.id).first).single;
    final rent = (await expenses.watchCategories(ama.id).first).first;
    await expenses.addOperation(
      ama.id,
      OperationDraft(
        kind: OperationKind.expense,
        amount: 45000,
        accountId: cash.id,
        categoryId: rent.id,
        occurredAt: DateTime.utc(2026, 9, 5, 10),
      ),
      repeat: LucidRecurrence(unit: LucidRecurrenceUnit.month, start: DateTime(2026, 9, 5)),
    );
    now = DateTime.utc(2026, 11, 11, 9);
    final recurring = (await expenses.watchRecurrings(ama.id).first).single;
    await expenses.skipDue(ama.id, Due(recurring: recurring, day: DateTime(2026, 10, 5)));

    final file = await serviceFor(phone).exportProfile(ama.id, password);
    // L'import remplace : une récurrence posée après l'export disparaît.
    await expenses.createRecurring(ama.id, recurring.toDraft());
    final service = serviceFor(phone);
    await service.import(await service.open(file, password));

    final restored = (await ExpensesRepository(phone, clock: () => now).watchRecurrings(ama.id).first).single;
    expect(restored.id, recurring.id);
    expect(restored.settled, {DateTime(2026, 9, 5), DateTime(2026, 10, 5)});
    expect(duesUntil([restored], now).map((d) => d.day), [DateTime(2026, 11, 5)]);
  });
}

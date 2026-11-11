import 'package:flutter_test/flutter_test.dart';
import 'package:lucid_core_flutter/lucid_core_flutter.dart' show LucidRecurrenceUnit;
import 'package:palier/data/database.dart';
import 'package:palier/features/expenses/data/expenses_repository.dart';
import 'package:palier/features/expenses/domain/expense_kinds.dart';
import 'package:palier/features/expenses/domain/expenses.dart';
import 'package:palier/features/expenses/domain/recurring.dart';
import 'package:palier/features/expenses/domain/tontines.dart';
import 'package:palier/features/profiles/data/profiles_repository.dart';
import 'package:palier/features/profiles/domain/profile.dart';

import '../../helpers/test_database.dart';

void main() {
  late PalierDatabase db;
  late ExpensesRepository repo;
  late DateTime now;
  late String ama;
  late Account momo;

  final TontineNotes notes = (contribution: (name) => 'Cotisation $name', hand: (name) => 'Main $name');

  // Dix membres, 5 000 F chaque vendredi depuis le 6 novembre, main au 3e tour (20 novembre).
  TontineDraft draft({String name = 'Marché', int rank = 3, int contribution = 5000}) => TontineDraft(
    name: name,
    accountId: momo.id,
    terms: TontineTerms(
      contribution: contribution,
      members: 10,
      rank: rank,
      unit: LucidRecurrenceUnit.week,
      firstRound: DateTime(2026, 11, 6),
    ),
  );

  Future<Account> accountOf(String id) async => (await repo.watchAccounts(ama).first).firstWhere((a) => a.id == id);

  setUp(() async {
    db = openTestDatabase();
    // Samedi 14 novembre : deux tours sont déjà passés.
    now = DateTime.utc(2026, 11, 14, 9);
    repo = ExpensesRepository(db, clock: () => now);
    ama = (await ProfilesRepository(db).create(const ProfileDraft(name: 'Ama'))).id;
    momo = await repo.createAccount(
      ama,
      const AccountDraft(name: 'MoMo', kind: AccountKind.mobileMoney, openingBalance: 100000),
    );
  });

  tearDown(() => db.close());

  test('une tontine en cours a son compte, avec les tours passés en solde de départ', () async {
    await repo.createTontine(ama, draft(), notes: notes);

    final tontine = (await repo.watchTontines(ama).first).single;
    expect((tontine.name, tontine.balance, tontine.payAccountName), ('Marché', 10000, 'MoMo'));
    expect(tontine.terms, draft().terms);
    final account = await accountOf(tontine.accountId);
    expect(account.kind, AccountKind.tontine);
    expect((await accountOf(momo.id)).balance, 100000, reason: 'les tours passés ne sont pas repris sur MoMo');
  });

  test('cotisations et main arrivent dans « À valider », en virements', () async {
    await repo.createTontine(ama, draft(), notes: notes);
    final recurrings = await repo.watchRecurrings(ama).first;

    final dues = duesUntil(recurrings, DateTime(2026, 11, 20));
    expect(dues.map((d) => (d.recurring.note, d.day, d.recurring.amount)), [
      ('Cotisation Marché', DateTime(2026, 11, 20), 5000),
      ('Main Marché', DateTime(2026, 11, 20), 50000),
    ]);
    expect(dues.every((d) => d.recurring.kind == OperationKind.transfer), isTrue);

    for (final due in dues) {
      await repo.addOperation(ama, due.recurring.draftFor(DateTime.utc(2026, 11, 20, 10)), due: due);
    }
    final tontine = (await repo.watchTontines(ama).first).single;
    expect(tontine.balance, 10000 + 5000 - 50000, reason: 'après la main, on doit au groupe');
    expect((await accountOf(momo.id)).balance, 100000 - 5000 + 50000);
    final (from, to) = MonthView.bounds(DateTime(2026, 11));
    final month = MonthView(
      month: DateTime(2026, 11),
      entries: await repo.watchOperations(ama, from: from, to: to).first,
    );
    expect((month.spent, month.received), (0, 0), reason: 'ni dépense ni revenu');
  });

  test('se modifie : nom, cotisation et rang suivent', () async {
    final id = await repo.createTontine(ama, draft(), notes: notes);
    await repo.updateTontine(id, draft(name: 'Tontine du marché', rank: 5, contribution: 10000), notes: notes);

    final tontine = (await repo.watchTontines(ama).first).single;
    expect((tontine.name, tontine.terms.rank, tontine.terms.contribution), ('Tontine du marché', 5, 10000));
    final recurrings = await repo.watchRecurrings(ama).first;
    expect(recurrings.map((r) => (r.note, r.amount)), [
      ('Cotisation Tontine du marché', 10000),
      ('Main Tontine du marché', 100000),
    ]);
    expect(recurrings.last.rule.start, DateTime(2026, 12, 4));
  });

  test('arrêtée sans opération, elle disparaît avec son compte', () async {
    final id = await repo.createTontine(ama, draft(), notes: notes);
    final accountId = (await repo.watchTontines(ama).first).single.accountId;
    await repo.deleteTontine(id);

    expect(await repo.watchTontines(ama).first, isEmpty);
    expect(await repo.watchRecurrings(ama).first, isEmpty);
    expect((await repo.watchAccounts(ama).first).map((a) => a.id), isNot(contains(accountId)));
  });

  test('arrêtée après des cotisations, son compte reste avec son solde', () async {
    final id = await repo.createTontine(ama, draft(), notes: notes);
    final recurrings = await repo.watchRecurrings(ama).first;
    final due = duesUntil(recurrings, DateTime(2026, 11, 20)).first;
    await repo.addOperation(ama, due.recurring.draftFor(DateTime.utc(2026, 11, 20, 10)), due: due);
    final accountId = (await repo.watchTontines(ama).first).single.accountId;

    await repo.deleteTontine(id);
    expect(await repo.watchRecurrings(ama).first, isEmpty);
    expect((await accountOf(accountId)).balance, 15000);
  });
}

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palier/data/database.dart';
import 'package:palier/features/expenses/domain/expense_kinds.dart';
import 'package:palier/features/sport/domain/sport.dart';

import 'generated/schema.dart';
import 'generated/schema_v1.dart' as v1;
import 'generated/schema_v2.dart' as v2;
import 'generated/schema_v4.dart' as v4;
import 'generated/schema_v5.dart' as v5;
import 'generated/schema_v6.dart' as v6;
import 'generated/schema_v7.dart' as v7;
import 'generated/schema_v8.dart' as v8;

/// Les instantanés de `drift_schemas/` figent chaque version du schéma : ces tests
/// partent d'une vraie base ancienne, pas de la base actuelle.
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;

  setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

  group('chaque version mène au schéma attendu', () {
    const versions = GeneratedHelper.versions;
    for (final (i, from) in versions.indexed) {
      for (final to in versions.skip(i + 1)) {
        test('de v$from à v$to', () async {
          final schema = await verifier.schemaAt(from);
          final db = PalierDatabase(schema.newConnection());
          await verifier.migrateAndValidate(db, to);
          await db.close();
        });
      }
    }
  });

  test('v1 → v2 garde les profils, qui peuvent ensuite avoir des comptes', () async {
    final created = DateTime.utc(2026, 11, 7, 9);
    final profile = v1.ProfilesData(
      id: 'profil-ama',
      // Valeurs brutes, telles qu'écrites en v1 : dates en texte, booléens en entiers.
      createdAt: created.toIso8601String(),
      updatedAt: created.toIso8601String(),
      name: 'Ama',
      accent: 'cyan',
      currency: 'XOF',
      isMinor: 0,
      expensesEnabled: 1,
      sportEnabled: 1,
      pinHash: 'empreinte',
      pinSalt: 'sel',
      pinIterations: 1000,
      biometricEnabled: 0,
      failedPinAttempts: 0,
    );

    await verifier.testWithDataIntegrity(
      oldVersion: 1,
      newVersion: 2,
      createOld: v1.DatabaseAtV1.new,
      createNew: v2.DatabaseAtV2.new,
      openTestedDatabase: PalierDatabase.new,
      createItems: (batch, oldDb) => batch.insert(oldDb.profiles, profile),
      validateItems: (newDb) async {
        final rows = await newDb.select(newDb.profiles).get();
        expect(rows.single.toJson(), profile.toJson());
      },
    );

    // La migration elle-même, sur la base de l'application : les nouvelles tables
    // acceptent un compte rattaché au profil existant.
    final schema = await verifier.schemaAt(1);
    final oldDb = v1.DatabaseAtV1(schema.newConnection());
    await oldDb.into(oldDb.profiles).insert(profile);
    await oldDb.close();

    final db = PalierDatabase(schema.newConnection());
    addTearDown(db.close);
    final migrated = await db.select(db.profiles).getSingle();
    expect(migrated.name, 'Ama');
    expect(migrated.createdAt, created);
    expect(migrated.pinHash, 'empreinte');

    await db
        .into(db.accounts)
        .insert(
          AccountsCompanion.insert(
            id: 'compte-especes',
            createdAt: created,
            updatedAt: created,
            profileId: 'profil-ama',
            name: 'Espèces',
            kind: AccountKind.cash,
          ),
        );
    expect(await db.select(db.accounts).get(), hasLength(1));
  });

  test('v2 → v3 garde les opérations, et une catégorie reçoit un seul plafond', () async {
    const at = '2026-11-09T09:00:00.000Z';
    final schema = await verifier.schemaAt(2);
    final oldDb = v2.DatabaseAtV2(schema.newConnection());
    for (final sql in [
      "INSERT INTO profiles (id, created_at, updated_at, name, accent) VALUES ('p', '$at', '$at', 'Ama', 'cyan')",
      'INSERT INTO accounts (id, created_at, updated_at, profile_id, name, kind) '
          "VALUES ('a', '$at', '$at', 'p', 'Espèces', 'cash')",
      'INSERT INTO categories (id, created_at, updated_at, profile_id, name, kind, icon) '
          "VALUES ('c', '$at', '$at', 'p', 'Courses', 'expense', 'basket')",
      'INSERT INTO operations (id, created_at, updated_at, profile_id, kind, amount, account_id, category_id, occurred_at) '
          "VALUES ('o', '$at', '$at', 'p', 'expense', 2500, 'a', 'c', '$at')",
    ]) {
      await oldDb.customStatement(sql);
    }
    await oldDb.close();

    final db = PalierDatabase(schema.newConnection());
    addTearDown(db.close);
    expect((await db.select(db.operations).getSingle()).amount, 2500);

    final now = DateTime.utc(2026, 11, 10);
    BudgetsCompanion budget(String id) =>
        BudgetsCompanion.insert(id: id, createdAt: now, updatedAt: now, profileId: 'p', categoryId: 'c', amount: 60000);
    await db.into(db.budgets).insert(budget('b1'));
    await expectLater(db.into(db.budgets).insert(budget('b2')), throwsA(isA<SqliteException>()));
  });

  test('v3 → v4 garde les opérations, qui peuvent ensuite régler une échéance', () async {
    const at = '2026-11-10T09:00:00.000Z';
    final schema = await verifier.schemaAt(3);
    final oldDb = PalierDatabase(schema.newConnection());
    for (final sql in [
      "INSERT INTO profiles (id, created_at, updated_at, name, accent) VALUES ('p', '$at', '$at', 'Ama', 'cyan')",
      'INSERT INTO accounts (id, created_at, updated_at, profile_id, name, kind) '
          "VALUES ('a', '$at', '$at', 'p', 'Espèces', 'cash')",
      'INSERT INTO categories (id, created_at, updated_at, profile_id, name, kind, icon) '
          "VALUES ('c', '$at', '$at', 'p', 'Loyer', 'expense', 'home')",
      'INSERT INTO operations (id, created_at, updated_at, profile_id, kind, amount, account_id, category_id, occurred_at) '
          "VALUES ('o', '$at', '$at', 'p', 'expense', 45000, 'a', 'c', '$at')",
    ]) {
      await oldDb.customStatement(sql);
    }
    await oldDb.close();

    final db = PalierDatabase(schema.newConnection());
    addTearDown(db.close);
    final kept = await db.select(db.operations).getSingle();
    expect((kept.amount, kept.recurrenceId, kept.dueOn), (45000, null, null));

    final now = DateTime.utc(2026, 11, 11);
    await db
        .into(db.recurrences)
        .insert(
          RecurrencesCompanion.insert(
            id: 'r',
            createdAt: now,
            updatedAt: now,
            profileId: 'p',
            kind: OperationKind.expense,
            amount: 45000,
            accountId: 'a',
            categoryId: const Value('c'),
            unit: RepeatUnit.month,
            startsOn: '2026-11-10',
            dueFrom: '2026-11-10',
          ),
        );
    await (db.update(db.operations)..where((o) => o.id.equals('o'))).write(
      const OperationsCompanion(recurrenceId: Value('r'), dueOn: Value('2026-11-10')),
    );
    expect((await db.select(db.operations).getSingle()).recurrenceId, 'r');

    RecurrenceSkipsCompanion skip(String id) => RecurrenceSkipsCompanion.insert(
      id: id,
      createdAt: now,
      updatedAt: now,
      profileId: 'p',
      recurrenceId: 'r',
      dueOn: '2026-12-10',
    );
    await db.into(db.recurrenceSkips).insert(skip('s1'));
    await expectLater(db.into(db.recurrenceSkips).insert(skip('s2')), throwsA(isA<SqliteException>()));
  });

  test('v4 → v5 garde les comptes sans objectif, qu’un compte d’épargne peut ensuite recevoir', () async {
    const at = '2026-11-11T09:00:00.000Z';
    final schema = await verifier.schemaAt(4);
    final oldDb = v4.DatabaseAtV4(schema.newConnection());
    for (final sql in [
      "INSERT INTO profiles (id, created_at, updated_at, name, accent) VALUES ('p', '$at', '$at', 'Ama', 'cyan')",
      'INSERT INTO accounts (id, created_at, updated_at, profile_id, name, kind, opening_balance) '
          "VALUES ('a', '$at', '$at', 'p', 'Banque', 'bank', 80000)",
    ]) {
      await oldDb.customStatement(sql);
    }
    await oldDb.close();

    final db = PalierDatabase(schema.newConnection());
    addTearDown(db.close);
    final kept = await db.select(db.accounts).getSingle();
    expect((kept.kind, kept.openingBalance, kept.goal), (AccountKind.bank, 80000, null));

    final now = DateTime.utc(2026, 11, 11);
    AccountsCompanion savings(String id, int goal) => AccountsCompanion.insert(
      id: id,
      createdAt: now,
      updatedAt: now,
      profileId: 'p',
      name: 'Tabaski',
      kind: AccountKind.savings,
      goal: Value(goal),
    );
    await db.into(db.accounts).insert(savings('e', 150000));
    expect((await (db.select(db.accounts)..where((a) => a.id.equals('e'))).getSingle()).goal, 150000);
    // Un objectif nul ou négatif n'a pas de sens : la base le refuse.
    await expectLater(db.into(db.accounts).insert(savings('e0', 0)), throwsA(isA<SqliteException>()));
  });

  test('v5 → v6 garde les comptes, et une tontine garde un rang dans le tour', () async {
    const at = '2026-11-11T09:00:00.000Z';
    final schema = await verifier.schemaAt(5);
    final oldDb = v5.DatabaseAtV5(schema.newConnection());
    for (final sql in [
      "INSERT INTO profiles (id, created_at, updated_at, name, accent) VALUES ('p', '$at', '$at', 'Ama', 'cyan')",
      'INSERT INTO accounts (id, created_at, updated_at, profile_id, name, kind, goal) '
          "VALUES ('e', '$at', '$at', 'p', 'Tabaski', 'savings', 150000)",
      'INSERT INTO accounts (id, created_at, updated_at, profile_id, name, kind) '
          "VALUES ('m', '$at', '$at', 'p', 'MoMo', 'mobileMoney')",
    ]) {
      await oldDb.customStatement(sql);
    }
    await oldDb.close();

    final db = PalierDatabase(schema.newConnection());
    addTearDown(db.close);
    expect((await (db.select(db.accounts)..where((a) => a.id.equals('e'))).getSingle()).goal, 150000);

    final now = DateTime.utc(2026, 11, 11);
    await db
        .into(db.accounts)
        .insert(
          AccountsCompanion.insert(
            id: 't',
            createdAt: now,
            updatedAt: now,
            profileId: 'p',
            name: 'Tontine du marché',
            kind: AccountKind.tontine,
          ),
        );
    RecurrencesCompanion recurrence(String id, String from, String to) => RecurrencesCompanion.insert(
      id: id,
      createdAt: now,
      updatedAt: now,
      profileId: 'p',
      kind: OperationKind.transfer,
      amount: 5000,
      accountId: from,
      toAccountId: Value(to),
      unit: RepeatUnit.week,
      startsOn: '2026-11-13',
      dueFrom: '2026-11-13',
    );
    await db.into(db.recurrences).insert(recurrence('c', 'm', 't'));
    await db.into(db.recurrences).insert(recurrence('h', 't', 'm'));
    TontinesCompanion tontine(String id, int rank) => TontinesCompanion.insert(
      id: id,
      createdAt: now,
      updatedAt: now,
      profileId: 'p',
      accountId: 't',
      contributionId: 'c',
      handId: 'h',
      members: 10,
      rank: rank,
    );
    // Un rang au-delà du nombre de membres n'existe pas.
    await expectLater(db.into(db.tontines).insert(tontine('x', 11)), throwsA(isA<SqliteException>()));
    await db.into(db.tontines).insert(tontine('ok', 3));
    expect((await db.select(db.tontines).getSingle()).rank, 3);
  });

  test('v6 → v7 garde les comptes, et un prêt a un montant positif', () async {
    const at = '2026-11-11T09:00:00.000Z';
    final schema = await verifier.schemaAt(6);
    final oldDb = v6.DatabaseAtV6(schema.newConnection());
    for (final sql in [
      "INSERT INTO profiles (id, created_at, updated_at, name, accent) VALUES ('p', '$at', '$at', 'Ama', 'cyan')",
      'INSERT INTO accounts (id, created_at, updated_at, profile_id, name, kind) '
          "VALUES ('m', '$at', '$at', 'p', 'MoMo', 'mobileMoney')",
    ]) {
      await oldDb.customStatement(sql);
    }
    await oldDb.close();

    final db = PalierDatabase(schema.newConnection());
    addTearDown(db.close);
    expect((await db.select(db.accounts).getSingle()).kind, AccountKind.mobileMoney);

    final now = DateTime.utc(2026, 11, 11);
    await db
        .into(db.accounts)
        .insert(
          AccountsCompanion.insert(
            id: 'l',
            createdAt: now,
            updatedAt: now,
            profileId: 'p',
            name: 'Koffi',
            kind: AccountKind.loan,
          ),
        );
    LoansCompanion loan(String id, int amount) => LoansCompanion.insert(
      id: id,
      createdAt: now,
      updatedAt: now,
      profileId: 'p',
      accountId: 'l',
      direction: LoanDirection.lent,
      amount: amount,
      payAccountId: 'm',
      startedOn: '2026-11-11',
    );
    await expectLater(db.into(db.loans).insert(loan('zero', 0)), throwsA(isA<SqliteException>()));
    await db.into(db.loans).insert(loan('ok', 30000));
    expect((await db.select(db.loans).getSingle()).direction, LoanDirection.lent);
  });

  test('v7 → v8 garde les profils, qui peuvent ensuite noter des séances valables', () async {
    const at = '2026-11-12T09:00:00.000Z';
    final schema = await verifier.schemaAt(7);
    final oldDb = v7.DatabaseAtV7(schema.newConnection());
    await oldDb.customStatement(
      "INSERT INTO profiles (id, created_at, updated_at, name, accent) VALUES ('p', '$at', '$at', 'Ama', 'cyan')",
    );
    await oldDb.close();

    final db = PalierDatabase(schema.newConnection());
    addTearDown(db.close);
    expect((await db.select(db.profiles).getSingle()).name, 'Ama');

    final now = DateTime.utc(2026, 11, 12);
    WorkoutsCompanion workout(String id, int seconds, {int? meters}) => WorkoutsCompanion.insert(
      id: id,
      createdAt: now,
      updatedAt: now,
      profileId: 'p',
      activity: WorkoutActivity.run,
      occurredAt: now,
      durationSeconds: seconds,
      distanceMeters: Value(meters),
    );
    await expectLater(db.into(db.workouts).insert(workout('zero', 0)), throwsA(isA<SqliteException>()));
    await expectLater(
      db.into(db.workouts).insert(workout('sans-distance', 600, meters: 0)),
      throwsA(isA<SqliteException>()),
    );
    await db.into(db.workouts).insert(workout('ok', 1800, meters: 5000));
    expect((await db.select(db.workouts).getSingle()).distanceMeters, 5000);

    SportSettingsTableCompanion settings(String id) => SportSettingsTableCompanion.insert(
      id: id,
      createdAt: now,
      updatedAt: now,
      profileId: 'p',
      activities: 'walk,strength',
    );
    await db.into(db.sportSettingsTable).insert(settings('r1'));
    // Une seule ligne de réglages par profil.
    await expectLater(db.into(db.sportSettingsTable).insert(settings('r2')), throwsA(isA<SqliteException>()));
  });

  test('v8 → v9 garde les séances, et un exercice est en répétitions ou en durée', () async {
    const at = '2026-11-12T09:00:00.000Z';
    final schema = await verifier.schemaAt(8);
    final oldDb = v8.DatabaseAtV8(schema.newConnection());
    for (final sql in [
      "INSERT INTO profiles (id, created_at, updated_at, name, accent) VALUES ('p', '$at', '$at', 'Ama', 'cyan')",
      'INSERT INTO workouts (id, created_at, updated_at, profile_id, activity, occurred_at, duration_seconds) '
          "VALUES ('w', '$at', '$at', 'p', 'run', '$at', 1800)",
    ]) {
      await oldDb.customStatement(sql);
    }
    await oldDb.close();

    final db = PalierDatabase(schema.newConnection());
    addTearDown(db.close);
    final workout = await db.select(db.workouts).getSingle();
    expect(workout.durationSeconds, 1800);
    expect(workout.circuitId, equals(null));

    final now = DateTime.utc(2026, 11, 12);
    await db
        .into(db.circuits)
        .insert(
          CircuitsCompanion.insert(id: 'c', createdAt: now, updatedAt: now, profileId: 'p', name: 'Maison', rounds: 3),
        );
    CircuitExercisesCompanion exercise(String id, {int? reps, int? seconds}) => CircuitExercisesCompanion.insert(
      id: id,
      createdAt: now,
      updatedAt: now,
      profileId: 'p',
      circuitId: 'c',
      position: 0,
      name: 'Pompes',
      reps: Value(reps),
      seconds: Value(seconds),
    );
    await expectLater(db.into(db.circuitExercises).insert(exercise('ni-l-un')), throwsA(isA<SqliteException>()));
    await expectLater(
      db.into(db.circuitExercises).insert(exercise('les-deux', reps: 10, seconds: 30)),
      throwsA(isA<SqliteException>()),
    );
    await db.into(db.circuitExercises).insert(exercise('ok', reps: 10));
    await expectLater(
      db
          .into(db.circuits)
          .insert(
            CircuitsCompanion.insert(id: 'z', createdAt: now, updatedAt: now, profileId: 'p', name: 'Zéro', rounds: 0),
          ),
      throwsA(isA<SqliteException>()),
    );
  });

  test('les clés étrangères sont appliquées', () async {
    final db = PalierDatabase(DatabaseConnection(NativeDatabase.memory()));
    addTearDown(db.close);
    final now = DateTime.utc(2026, 11, 9);

    await expectLater(
      db
          .into(db.accounts)
          .insert(
            AccountsCompanion.insert(
              id: 'orphelin',
              createdAt: now,
              updatedAt: now,
              profileId: 'aucun-profil',
              name: 'Espèces',
              kind: AccountKind.cash,
            ),
          ),
      throwsA(isA<SqliteException>()),
    );
  });
}

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palier/data/database.dart';
import 'package:palier/features/expenses/domain/expense_kinds.dart';

import 'generated/schema.dart';
import 'generated/schema_v1.dart' as v1;
import 'generated/schema_v2.dart' as v2;

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

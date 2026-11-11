import '../../../data/database.dart';
import '../../../data/utc_serializer.dart';
import '../../backup/data/backup_service.dart';

/// Comptes, catégories, opérations, plafonds et récurrences d'un profil dans son
/// export chiffré. Un fichier plus ancien s'importe tel quel, sans ce qu'il ne
/// connaissait pas encore.
///
/// Chaque ligne porte sa table (`_table`) ; les lignes supprimées partent aussi,
/// pour qu'une future synchronisation sache ce qui a disparu.
class ExpensesBackupSection implements BackupSection {
  ExpensesBackupSection(this._db);

  final PalierDatabase _db;

  static const _tableKey = '_table';
  static const _utc = UtcValueSerializer();

  @override
  String get key => 'expenses';

  @override
  Future<List<Map<String, Object?>>> export(String profileId) async {
    final accounts = await (_db.select(_db.accounts)..where((a) => a.profileId.equals(profileId))).get();
    final categories = await (_db.select(_db.categories)..where((c) => c.profileId.equals(profileId))).get();
    final operations = await (_db.select(_db.operations)..where((o) => o.profileId.equals(profileId))).get();
    final budgets = await (_db.select(_db.budgets)..where((b) => b.profileId.equals(profileId))).get();
    final recurrences = await (_db.select(_db.recurrences)..where((r) => r.profileId.equals(profileId))).get();
    final skips = await (_db.select(_db.recurrenceSkips)..where((s) => s.profileId.equals(profileId))).get();
    return [
      for (final row in accounts) {_tableKey: 'accounts', ...row.toJson()},
      for (final row in categories) {_tableKey: 'categories', ...row.toJson()},
      for (final row in recurrences) {_tableKey: 'recurrences', ...row.toJson()},
      for (final row in operations) {_tableKey: 'operations', ...row.toJson()},
      for (final row in skips) {_tableKey: 'recurrenceSkips', ...row.toJson()},
      for (final row in budgets) {_tableKey: 'budgets', ...row.toJson()},
    ];
  }

  /// Appelée dans la transaction de l'import : remplace tout le module du profil.
  @override
  Future<void> restore(String profileId, List<Map<String, Object?>> rows) async {
    List<Map<String, Object?>> of(String table) => [
      for (final row in rows)
        if (row[_tableKey] == table) {...row}..remove(_tableKey),
    ];

    // Ce qui pointe vers d'autres lignes part d'abord : échéances passées,
    // opérations, récurrences et plafonds, puis comptes et catégories.
    await (_db.delete(_db.recurrenceSkips)..where((s) => s.profileId.equals(profileId))).go();
    await (_db.delete(_db.budgets)..where((b) => b.profileId.equals(profileId))).go();
    await (_db.delete(_db.operations)..where((o) => o.profileId.equals(profileId))).go();
    await (_db.delete(_db.recurrences)..where((r) => r.profileId.equals(profileId))).go();
    await (_db.delete(_db.accounts)..where((a) => a.profileId.equals(profileId))).go();
    await (_db.delete(_db.categories)..where((c) => c.profileId.equals(profileId))).go();

    // Le profil du fichier fait foi : chaque ligne lui est rattachée.
    for (final json in of('accounts')) {
      final row = AccountRow.fromJson(json, serializer: _utc).copyWith(profileId: profileId);
      await _db.into(_db.accounts).insert(row.toCompanion(false));
    }
    for (final json in of('categories')) {
      final row = CategoryRow.fromJson(json, serializer: _utc).copyWith(profileId: profileId);
      await _db.into(_db.categories).insert(row.toCompanion(false));
    }
    for (final json in of('recurrences')) {
      final row = RecurrenceRow.fromJson(json, serializer: _utc).copyWith(profileId: profileId);
      await _db.into(_db.recurrences).insert(row.toCompanion(false));
    }
    for (final json in of('operations')) {
      final row = OperationRow.fromJson(json, serializer: _utc).copyWith(profileId: profileId);
      await _db.into(_db.operations).insert(row.toCompanion(false));
    }
    for (final json in of('budgets')) {
      final row = BudgetRow.fromJson(json, serializer: _utc).copyWith(profileId: profileId);
      await _db.into(_db.budgets).insert(row.toCompanion(false));
    }
    for (final json in of('recurrenceSkips')) {
      final row = RecurrenceSkipRow.fromJson(json, serializer: _utc).copyWith(profileId: profileId);
      await _db.into(_db.recurrenceSkips).insert(row.toCompanion(false));
    }
  }
}

import '../../../data/database.dart';
import '../../../data/utc_serializer.dart';
import '../../backup/data/backup_service.dart';

/// Réglages et séances de sport d'un profil dans son export chiffré. Comme les
/// dépenses : chaque ligne porte sa table, les lignes supprimées partent aussi.
class SportBackupSection implements BackupSection {
  SportBackupSection(this._db);

  final PalierDatabase _db;

  static const _tableKey = '_table';
  static const _utc = UtcValueSerializer();

  @override
  String get key => 'sport';

  @override
  Future<List<Map<String, Object?>>> export(String profileId) async {
    final settings = await (_db.select(_db.sportSettingsTable)..where((s) => s.profileId.equals(profileId))).get();
    final workouts = await (_db.select(_db.workouts)..where((w) => w.profileId.equals(profileId))).get();
    final circuits = await (_db.select(_db.circuits)..where((c) => c.profileId.equals(profileId))).get();
    final exercises = await (_db.select(_db.circuitExercises)..where((e) => e.profileId.equals(profileId))).get();
    final plan = await (_db.select(_db.planItems)..where((p) => p.profileId.equals(profileId))).get();
    return [
      for (final row in settings) {_tableKey: 'sportSettings', ...row.toJson()},
      for (final row in circuits) {_tableKey: 'circuits', ...row.toJson()},
      for (final row in exercises) {_tableKey: 'circuitExercises', ...row.toJson()},
      for (final row in plan) {_tableKey: 'planItems', ...row.toJson()},
      for (final row in workouts) {_tableKey: 'workouts', ...row.toJson()},
    ];
  }

  /// Appelée dans la transaction de l'import : remplace tout le sport du profil.
  @override
  Future<void> restore(String profileId, List<Map<String, Object?>> rows) async {
    List<Map<String, Object?>> of(String table) => [
      for (final row in rows)
        if (row[_tableKey] == table) {...row}..remove(_tableKey),
    ];

    // Ce qui pointe vers un circuit part d'abord : séances, programme, puis exercices.
    await (_db.delete(_db.workouts)..where((w) => w.profileId.equals(profileId))).go();
    await (_db.delete(_db.planItems)..where((p) => p.profileId.equals(profileId))).go();
    await (_db.delete(_db.circuitExercises)..where((e) => e.profileId.equals(profileId))).go();
    await (_db.delete(_db.circuits)..where((c) => c.profileId.equals(profileId))).go();
    await (_db.delete(_db.sportSettingsTable)..where((s) => s.profileId.equals(profileId))).go();

    // Le profil du fichier fait foi : chaque ligne lui est rattachée.
    for (final json in of('sportSettings')) {
      final row = SportSettingsRow.fromJson(json, serializer: _utc).copyWith(profileId: profileId);
      await _db.into(_db.sportSettingsTable).insert(row.toCompanion(false));
    }
    for (final json in of('circuits')) {
      final row = CircuitRow.fromJson(json, serializer: _utc).copyWith(profileId: profileId);
      await _db.into(_db.circuits).insert(row.toCompanion(false));
    }
    for (final json in of('circuitExercises')) {
      final row = CircuitExerciseRow.fromJson(json, serializer: _utc).copyWith(profileId: profileId);
      await _db.into(_db.circuitExercises).insert(row.toCompanion(false));
    }
    for (final json in of('planItems')) {
      final row = PlanItemRow.fromJson(json, serializer: _utc).copyWith(profileId: profileId);
      await _db.into(_db.planItems).insert(row.toCompanion(false));
    }
    for (final json in of('workouts')) {
      final row = WorkoutRow.fromJson(json, serializer: _utc).copyWith(profileId: profileId);
      await _db.into(_db.workouts).insert(row.toCompanion(false));
    }
  }
}

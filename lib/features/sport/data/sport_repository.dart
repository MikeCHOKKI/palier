import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../data/database.dart';
import '../domain/sport.dart';

/// Réglages et séances de sport d'un profil.
class SportRepository {
  SportRepository(this._db, {DateTime Function()? clock, Uuid? uuid})
    : _clock = clock ?? (() => DateTime.now().toUtc()),
      _uuid = uuid ?? const Uuid();

  final PalierDatabase _db;
  final DateTime Function() _clock;
  final Uuid _uuid;

  // ---------------------------------------------------------------- réglages

  /// Les réglages du profil, ou `null` tant qu'il ne les a jamais enregistrés.
  Stream<SportSettings?> watchSettings(String profileId) {
    final query = _db.select(_db.sportSettingsTable)
      ..where((s) => s.profileId.equals(profileId) & s.deletedAt.isNull());
    return query.watchSingleOrNull().map((row) => row == null ? null : _settingsOf(row));
  }

  /// Crée ou remplace les réglages du profil.
  Future<void> saveSettings(String profileId, SportSettings settings) {
    assert(settings.problem == null, 'réglages incomplets : ${settings.problem}');
    return _db.transaction(() async {
      final now = _clock();
      final activities = settings.orderedActivities.map((a) => a.name).join(',');
      final days = settings.orderedDays.join(',');
      final existing = await (_db.select(
        _db.sportSettingsTable,
      )..where((s) => s.profileId.equals(profileId))).getSingleOrNull();
      if (existing == null) {
        await _db
            .into(_db.sportSettingsTable)
            .insert(
              SportSettingsTableCompanion.insert(
                id: _uuid.v4(),
                createdAt: now,
                updatedAt: now,
                profileId: profileId,
                activities: activities,
                trainingDays: Value(days),
                weeklyGoalMinutes: Value(settings.weeklyGoalMinutes),
              ),
            );
        return;
      }
      await (_db.update(_db.sportSettingsTable)..where((s) => s.id.equals(existing.id))).write(
        SportSettingsTableCompanion(
          activities: Value(activities),
          trainingDays: Value(days),
          weeklyGoalMinutes: Value(settings.weeklyGoalMinutes),
          updatedAt: Value(now),
          deletedAt: const Value(null),
        ),
      );
    });
  }

  static SportSettings _settingsOf(SportSettingsRow row) => SportSettings(
    activities: {
      for (final name in row.activities.split(','))
        for (final activity in WorkoutActivity.values)
          if (activity.name == name) activity,
    },
    trainingDays: {
      for (final part in row.trainingDays.split(','))
        if (int.tryParse(part) case final int day when day >= DateTime.monday && day <= DateTime.sunday) day,
    },
    weeklyGoalMinutes: row.weeklyGoalMinutes,
  );

  // ---------------------------------------------------------------- séances

  /// Les séances du profil, des plus récentes aux plus anciennes ; à partir de
  /// [since] (UTC) seulement quand il est donné.
  Stream<List<Workout>> watchWorkouts(String profileId, {DateTime? since}) {
    final query = _db.select(_db.workouts)
      ..where((w) {
        final mine = w.profileId.equals(profileId) & w.deletedAt.isNull();
        return since == null ? mine : mine & w.occurredAt.isBiggerOrEqualValue(since);
      })
      ..orderBy([(w) => OrderingTerm.desc(w.occurredAt), (w) => OrderingTerm.desc(w.createdAt)]);
    return query.watch().map((rows) => [for (final row in rows) _workoutOf(row)]);
  }

  Future<Workout?> findWorkout(String id) async {
    final row = await (_db.select(
      _db.workouts,
    )..where((w) => w.id.equals(id) & w.deletedAt.isNull())).getSingleOrNull();
    return row == null ? null : _workoutOf(row);
  }

  Future<Workout> createWorkout(String profileId, WorkoutDraft draft) async {
    assert(draft.problem == null, 'séance incomplète : ${draft.problem}');
    final now = _clock();
    final id = _uuid.v4();
    final note = _clean(draft.note);
    await _db
        .into(_db.workouts)
        .insert(
          WorkoutsCompanion.insert(
            id: id,
            createdAt: now,
            updatedAt: now,
            profileId: profileId,
            activity: draft.activity,
            occurredAt: draft.occurredAt.toUtc(),
            durationSeconds: draft.durationSeconds,
            distanceMeters: Value(draft.distanceMeters),
            effort: Value(draft.effort),
            note: Value(note),
          ),
        );
    return Workout(
      id: id,
      activity: draft.activity,
      occurredAt: draft.occurredAt.toUtc(),
      durationSeconds: draft.durationSeconds,
      distanceMeters: draft.distanceMeters,
      effort: draft.effort,
      note: note,
    );
  }

  Future<void> updateWorkout(String id, WorkoutDraft draft) {
    assert(draft.problem == null, 'séance incomplète : ${draft.problem}');
    return (_db.update(_db.workouts)..where((w) => w.id.equals(id))).write(
      WorkoutsCompanion(
        activity: Value(draft.activity),
        occurredAt: Value(draft.occurredAt.toUtc()),
        durationSeconds: Value(draft.durationSeconds),
        distanceMeters: Value(draft.distanceMeters),
        effort: Value(draft.effort),
        note: Value(_clean(draft.note)),
        updatedAt: Value(_clock()),
      ),
    );
  }

  /// Suppression douce : « Annuler » la rattrape par [restoreWorkout].
  Future<void> deleteWorkout(String id) => _setDeleted(id, _clock());

  Future<void> restoreWorkout(String id) => _setDeleted(id, null);

  Future<void> _setDeleted(String id, DateTime? at) => (_db.update(
    _db.workouts,
  )..where((w) => w.id.equals(id))).write(WorkoutsCompanion(deletedAt: Value(at), updatedAt: Value(_clock())));

  static String? _clean(String? note) {
    final trimmed = note?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  static Workout _workoutOf(WorkoutRow row) => Workout(
    id: row.id,
    activity: row.activity,
    occurredAt: row.occurredAt,
    durationSeconds: row.durationSeconds,
    distanceMeters: row.distanceMeters,
    effort: row.effort,
    note: row.note,
  );
}

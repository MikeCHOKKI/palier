import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../data/database.dart';
import '../domain/circuits.dart';
import '../domain/program.dart';
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
            circuitId: Value(draft.circuitId),
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
      circuitId: draft.circuitId,
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

  // ---------------------------------------------------------------- circuits

  /// Les circuits du profil avec leurs exercices, dans l'ordre choisi.
  Stream<List<Circuit>> watchCircuits(String profileId) {
    // Relancée à chaque changement d'un circuit ou d'un exercice.
    final trigger = _db.customSelect(
      'SELECT COUNT(*) FROM circuits WHERE profile_id = ?',
      variables: [Variable.withString(profileId)],
      readsFrom: {_db.circuits, _db.circuitExercises},
    );
    return trigger.watch().asyncMap((_) => _loadCircuits(profileId));
  }

  Future<List<Circuit>> _loadCircuits(String profileId, {String? onlyId}) async {
    final rows =
        await (_db.select(_db.circuits)
              ..where((c) {
                final mine = c.profileId.equals(profileId) & c.deletedAt.isNull();
                return onlyId == null ? mine : mine & c.id.equals(onlyId);
              })
              ..orderBy([(c) => OrderingTerm.asc(c.position), (c) => OrderingTerm.asc(c.createdAt)]))
            .get();
    if (rows.isEmpty) return const [];
    final exercises =
        await (_db.select(_db.circuitExercises)
              ..where((e) => e.circuitId.isIn([for (final row in rows) row.id]) & e.deletedAt.isNull())
              ..orderBy([(e) => OrderingTerm.asc(e.position)]))
            .get();
    return [
      for (final row in rows)
        Circuit(
          id: row.id,
          name: row.name,
          rounds: row.rounds,
          roundRestSeconds: row.roundRestSeconds,
          exercises: [
            for (final e in exercises)
              if (e.circuitId == row.id)
                CircuitExercise(name: e.name, reps: e.reps, seconds: e.seconds, restSeconds: e.restSeconds),
          ],
        ),
    ];
  }

  Future<Circuit?> findCircuit(String id) async {
    final row = await (_db.select(
      _db.circuits,
    )..where((c) => c.id.equals(id) & c.deletedAt.isNull())).getSingleOrNull();
    if (row == null) return null;
    return (await _loadCircuits(row.profileId, onlyId: id)).singleOrNull;
  }

  Future<Circuit> createCircuit(String profileId, CircuitDraft draft) {
    assert(draft.problem == null, 'circuit incomplet : ${draft.problem}');
    return _db.transaction(() async {
      final now = _clock();
      final id = _uuid.v4();
      final last =
          await (_db.selectOnly(_db.circuits)
                ..addColumns([_db.circuits.position.max()])
                ..where(_db.circuits.profileId.equals(profileId)))
              .map((r) => r.read(_db.circuits.position.max()))
              .getSingle();
      await _db
          .into(_db.circuits)
          .insert(
            CircuitsCompanion.insert(
              id: id,
              createdAt: now,
              updatedAt: now,
              profileId: profileId,
              name: draft.name.trim(),
              rounds: draft.rounds,
              roundRestSeconds: Value(draft.roundRestSeconds),
              position: Value((last ?? -1) + 1),
            ),
          );
      await _insertExercises(profileId, id, draft.exercises, now);
      return (await findCircuit(id))!;
    });
  }

  /// Remplace le circuit et ses exercices ; les anciens exercices sont supprimés en douceur.
  Future<void> updateCircuit(String id, CircuitDraft draft) {
    assert(draft.problem == null, 'circuit incomplet : ${draft.problem}');
    return _db.transaction(() async {
      final now = _clock();
      final row = await (_db.select(_db.circuits)..where((c) => c.id.equals(id))).getSingle();
      await (_db.update(_db.circuits)..where((c) => c.id.equals(id))).write(
        CircuitsCompanion(
          name: Value(draft.name.trim()),
          rounds: Value(draft.rounds),
          roundRestSeconds: Value(draft.roundRestSeconds),
          updatedAt: Value(now),
        ),
      );
      await (_db.update(_db.circuitExercises)..where((e) => e.circuitId.equals(id) & e.deletedAt.isNull())).write(
        CircuitExercisesCompanion(deletedAt: Value(now), updatedAt: Value(now)),
      );
      await _insertExercises(row.profileId, id, draft.exercises, now);
    });
  }

  Future<void> _insertExercises(
    String profileId,
    String circuitId,
    List<CircuitExercise> exercises,
    DateTime now,
  ) async {
    for (final (position, e) in exercises.indexed) {
      await _db
          .into(_db.circuitExercises)
          .insert(
            CircuitExercisesCompanion.insert(
              id: _uuid.v4(),
              createdAt: now,
              updatedAt: now,
              profileId: profileId,
              circuitId: circuitId,
              position: position,
              name: e.name.trim(),
              reps: Value(e.reps),
              seconds: Value(e.seconds),
              restSeconds: Value(e.restSeconds),
            ),
          );
    }
  }

  /// Suppression douce : « Annuler » la rattrape par [restoreCircuit]. Les
  /// séances déjà faites gardent leur lien vers le circuit.
  Future<void> deleteCircuit(String id) => _setCircuitDeleted(id, _clock());

  Future<void> restoreCircuit(String id) => _setCircuitDeleted(id, null);

  Future<void> _setCircuitDeleted(String id, DateTime? at) => (_db.update(
    _db.circuits,
  )..where((c) => c.id.equals(id))).write(CircuitsCompanion(deletedAt: Value(at), updatedAt: Value(_clock())));

  // ---------------------------------------------------------------- programme

  /// Le programme du profil : les séances prévues, jour par jour, dans l'ordre d'ajout.
  Stream<List<PlanItem>> watchPlan(String profileId) {
    final query = _db.select(_db.planItems)
      ..where((p) => p.profileId.equals(profileId) & p.deletedAt.isNull())
      ..orderBy([(p) => OrderingTerm.asc(p.weekday), (p) => OrderingTerm.asc(p.position)]);
    return query.watch().map(
      (rows) => [
        for (final row in rows)
          PlanItem(
            id: row.id,
            weekday: row.weekday,
            activity: row.activity,
            circuitId: row.circuitId,
            targetMinutes: row.targetMinutes,
          ),
      ],
    );
  }

  Future<String> addPlanItem(String profileId, PlanItemDraft draft) {
    assert(draft.isValid, 'séance prévue incomplète');
    return _db.transaction(() async {
      final now = _clock();
      final id = _uuid.v4();
      final last =
          await (_db.selectOnly(_db.planItems)
                ..addColumns([_db.planItems.position.max()])
                ..where(_db.planItems.profileId.equals(profileId) & _db.planItems.weekday.equals(draft.weekday)))
              .map((r) => r.read(_db.planItems.position.max()))
              .getSingle();
      await _db
          .into(_db.planItems)
          .insert(
            PlanItemsCompanion.insert(
              id: id,
              createdAt: now,
              updatedAt: now,
              profileId: profileId,
              weekday: draft.weekday,
              activity: draft.activity,
              circuitId: Value(draft.circuitId),
              targetMinutes: Value(draft.targetMinutes),
              position: Value((last ?? -1) + 1),
            ),
          );
      return id;
    });
  }

  /// Suppression douce : « Annuler » la rattrape par [restorePlanItem].
  Future<void> removePlanItem(String id) => _setPlanDeleted(id, _clock());

  Future<void> restorePlanItem(String id) => _setPlanDeleted(id, null);

  Future<void> _setPlanDeleted(String id, DateTime? at) => (_db.update(
    _db.planItems,
  )..where((p) => p.id.equals(id))).write(PlanItemsCompanion(deletedAt: Value(at), updatedAt: Value(_clock())));

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
    circuitId: row.circuitId,
  );
}

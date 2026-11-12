import 'package:flutter_test/flutter_test.dart';
import 'package:palier/app/providers.dart';
import 'package:palier/data/database.dart';
import 'package:palier/features/backup/data/backup_service.dart';
import 'package:palier/features/backup/domain/backup_codec.dart';
import 'package:palier/features/profiles/data/profiles_repository.dart';
import 'package:palier/features/profiles/domain/profile.dart';
import 'package:palier/features/sport/data/sport_repository.dart';
import 'package:palier/features/sport/domain/circuits.dart';
import 'package:palier/features/sport/domain/sport.dart';

import '../../helpers/test_database.dart';

void main() {
  late PalierDatabase db;
  late SportRepository repo;
  late String ama;
  final now = DateTime.utc(2026, 11, 12, 9);

  setUp(() async {
    db = openTestDatabase();
    repo = SportRepository(db, clock: () => now);
    ama = (await ProfilesRepository(db).create(const ProfileDraft(name: 'Ama'))).id;
  });

  tearDown(() => db.close());

  WorkoutDraft run(DateTime at, {int minutes = 30, int? meters, String? note}) => WorkoutDraft(
    activity: WorkoutActivity.run,
    occurredAt: at,
    durationSeconds: minutes * 60,
    distanceMeters: meters,
    effort: WorkoutEffort.ok,
    note: note,
  );

  group('réglages', () {
    test('absents au départ, puis enregistrés et remplacés sur la même ligne', () async {
      expect(await repo.watchSettings(ama).first, isNull);

      const first = SportSettings(activities: {WorkoutActivity.walk}, trainingDays: {1, 3}, weeklyGoalMinutes: 120);
      await repo.saveSettings(ama, first);
      expect(await repo.watchSettings(ama).first, first);

      const second = SportSettings(activities: {WorkoutActivity.run, WorkoutActivity.strength}, trainingDays: {});
      await repo.saveSettings(ama, second);
      expect(await repo.watchSettings(ama).first, second);
      expect(await db.select(db.sportSettingsTable).get(), hasLength(1));
    });

    test('appartiennent à un seul profil', () async {
      final kofi = (await ProfilesRepository(db).create(const ProfileDraft(name: 'Kofi'))).id;
      await repo.saveSettings(ama, SportSettings.initial);
      expect(await repo.watchSettings(kofi).first, isNull);
    });
  });

  group('séances', () {
    test('se listent des plus récentes aux plus anciennes, depuis une date au besoin', () async {
      await repo.createWorkout(ama, run(DateTime.utc(2026, 11, 2), note: 'ancienne'));
      await repo.createWorkout(ama, run(DateTime.utc(2026, 11, 10), meters: 5000, note: '  lundi  '));
      await repo.createWorkout(ama, run(DateTime.utc(2026, 11, 11), note: ''));

      final all = await repo.watchWorkouts(ama).first;
      expect(all.map((w) => w.occurredAt.day), [11, 10, 2]);
      expect(all[1].note, 'lundi');
      expect(all[0].note, isNull);
      expect(all[1].distanceMeters, 5000);

      final recent = await repo.watchWorkouts(ama, since: DateTime.utc(2026, 11, 9)).first;
      expect(recent, hasLength(2));
    });

    test('se modifient, se suppriment et se rattrapent', () async {
      final workout = await repo.createWorkout(ama, run(DateTime.utc(2026, 11, 10)));
      await repo.updateWorkout(
        workout.id,
        WorkoutDraft(
          activity: WorkoutActivity.strength,
          occurredAt: DateTime.utc(2026, 11, 10),
          durationSeconds: 1200,
          effort: WorkoutEffort.hard,
        ),
      );
      final updated = await repo.findWorkout(workout.id);
      expect(updated!.activity, WorkoutActivity.strength);
      expect(updated.durationMinutes, 20);
      expect(updated.effort, WorkoutEffort.hard);

      await repo.deleteWorkout(workout.id);
      expect(await repo.watchWorkouts(ama).first, isEmpty);
      expect(await repo.findWorkout(workout.id), isNull);

      await repo.restoreWorkout(workout.id);
      expect(await repo.watchWorkouts(ama).first, hasLength(1));
    });
  });

  group('circuits', () {
    const draft = CircuitDraft(
      name: '  Maison  ',
      rounds: 3,
      roundRestSeconds: 90,
      exercises: [
        CircuitExercise(name: 'Pompes', reps: 12),
        CircuitExercise(name: 'Gainage', seconds: 40, restSeconds: 15),
      ],
    );

    test('se créent avec leurs exercices dans l’ordre, et se listent', () async {
      final created = await repo.createCircuit(ama, draft);
      await repo.createCircuit(ama, draft.copyWith(name: 'Bras'));
      expect(created.name, 'Maison');
      expect(created.exercises, draft.exercises);

      final all = await repo.watchCircuits(ama).first;
      expect(all.map((c) => c.name), ['Maison', 'Bras']);
      expect(all.first.roundRestSeconds, 90);
    });

    test('une modification remplace les exercices, sans garder les anciens', () async {
      final created = await repo.createCircuit(ama, draft);
      await repo.updateCircuit(
        created.id,
        draft.copyWith(rounds: 2, exercises: const [CircuitExercise(name: 'Squats', reps: 20, restSeconds: 0)]),
      );
      final updated = await repo.findCircuit(created.id);
      expect(updated!.rounds, 2);
      expect(updated.exercises, const [CircuitExercise(name: 'Squats', reps: 20, restSeconds: 0)]);
      // Les anciens exercices restent en base, supprimés, pour une future synchronisation.
      expect(await db.select(db.circuitExercises).get(), hasLength(3));
    });

    test('se suppriment, se rattrapent, et une séance garde son circuit', () async {
      final created = await repo.createCircuit(ama, draft);
      final workout = await repo.createWorkout(
        ama,
        WorkoutDraft(
          activity: WorkoutActivity.strength,
          occurredAt: DateTime.utc(2026, 11, 12),
          durationSeconds: 900,
          circuitId: created.id,
        ),
      );
      expect((await repo.findWorkout(workout.id))!.circuitId, created.id);

      await repo.deleteCircuit(created.id);
      expect(await repo.watchCircuits(ama).first, isEmpty);
      expect(await repo.findCircuit(created.id), isNull);
      await repo.restoreCircuit(created.id);
      expect((await repo.watchCircuits(ama).first).single.exercises, hasLength(2));
    });
  });

  test('le sport suit le profil dans son export chiffré, et l’import le remplace', () async {
    const password = 'lune-baobab-42';
    BackupService serviceFor(PalierDatabase db) =>
        BackupService(db, codec: const BackupCodec(iterations: 1000), sections: backupSections(db));

    const settings = SportSettings(activities: {WorkoutActivity.run}, trainingDays: {2, 4}, weeklyGoalMinutes: 90);
    await repo.saveSettings(ama, settings);
    final circuit = await repo.createCircuit(
      ama,
      const CircuitDraft(
        name: 'Maison',
        exercises: [CircuitExercise(name: 'Pompes', reps: 10)],
      ),
    );
    await repo.createWorkout(ama, run(DateTime.utc(2026, 11, 10, 6), meters: 5200, note: 'bord de mer'));
    final deleted = await repo.createWorkout(ama, run(DateTime.utc(2026, 11, 11)));
    await repo.deleteWorkout(deleted.id);
    final file = await serviceFor(db).exportProfile(ama, password);

    final newPhone = openTestDatabase();
    addTearDown(newPhone.close);
    final service = serviceFor(newPhone);
    await service.import(await service.open(file, password));
    final restored = SportRepository(newPhone);
    expect(await restored.watchSettings(ama).first, settings);
    final workouts = await restored.watchWorkouts(ama).first;
    expect(workouts.single.note, 'bord de mer');
    expect(workouts.single.occurredAt, DateTime.utc(2026, 11, 10, 6));
    expect(workouts.single.distanceMeters, 5200);
    final circuits = await restored.watchCircuits(ama).first;
    expect(circuits.single.id, circuit.id);
    expect(circuits.single.exercises.single.reps, 10);
    // La séance supprimée voyage aussi, toujours supprimée.
    expect(await newPhone.select(newPhone.workouts).get(), hasLength(2));

    // Sur le premier téléphone, une séance notée après l'export disparaît à l'import.
    await repo.createWorkout(ama, run(DateTime.utc(2026, 11, 12)));
    await serviceFor(db).import(await serviceFor(db).open(file, password));
    expect(await repo.watchWorkouts(ama).first, hasLength(1));
  });
}

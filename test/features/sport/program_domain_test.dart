import 'package:flutter_test/flutter_test.dart';
import 'package:palier/features/sport/domain/program.dart';
import 'package:palier/features/sport/domain/sport.dart';

void main() {
  /// Jeudi 12 novembre 2026, 18 h.
  final now = DateTime(2026, 11, 12, 18);

  Workout done(WorkoutActivity activity, {String? circuitId, int daysAgo = 0}) => Workout(
    id: '$activity$circuitId$daysAgo',
    activity: activity,
    occurredAt: DateTime(2026, 11, 12 - daysAgo, 7).toUtc(),
    durationSeconds: 1800,
    circuitId: circuitId,
  );

  PlanItem plan(String id, int weekday, WorkoutActivity activity, {String? circuitId}) =>
      PlanItem(id: id, weekday: weekday, activity: activity, circuitId: circuitId);

  test('ne garde que les séances prévues ce jour-là, dans l’ordre du programme', () {
    final today = todayPlan(
      [
        plan('lundi', DateTime.monday, WorkoutActivity.run),
        plan('marche', DateTime.thursday, WorkoutActivity.walk),
        plan('maison', DateTime.thursday, WorkoutActivity.strength, circuitId: 'c'),
      ],
      const [],
      now: now,
    );
    expect(today.map((t) => t.item.id), ['marche', 'maison']);
    expect(today.every((t) => !t.done), isTrue);
  });

  test('une séance notée aujourd’hui coche une seule prévision, le circuit d’abord', () {
    final today = todayPlan(
      [
        plan('renfo', DateTime.thursday, WorkoutActivity.strength),
        plan('maison', DateTime.thursday, WorkoutActivity.strength, circuitId: 'c'),
        plan('marche', DateTime.thursday, WorkoutActivity.walk),
      ],
      [
        done(WorkoutActivity.strength, circuitId: 'c'),
        // D'hier : ne coche rien aujourd'hui.
        done(WorkoutActivity.walk, daysAgo: 1),
      ],
      now: now,
    );
    expect({for (final t in today) t.item.id: t.done}, {'renfo': false, 'maison': true, 'marche': false});
  });

  test('du renforcement noté à la main coche une prévision d’activité, pas un circuit', () {
    final today = todayPlan(
      [
        plan('maison', DateTime.thursday, WorkoutActivity.strength, circuitId: 'c'),
        plan('renfo', DateTime.thursday, WorkoutActivity.strength),
      ],
      [done(WorkoutActivity.strength)],
      now: now,
    );
    expect({for (final t in today) t.item.id: t.done}, {'maison': false, 'renfo': true});
  });

  test('un circuit au programme est du renforcement, sans durée visée', () {
    const draft = PlanItemDraft.circuit(weekday: 2, circuitId: 'c');
    expect(draft.activity, WorkoutActivity.strength);
    expect(draft.isValid, isTrue);
    expect(const PlanItemDraft(weekday: 8, activity: WorkoutActivity.walk).isValid, isFalse);
    expect(const PlanItemDraft(weekday: 1, activity: WorkoutActivity.walk, targetMinutes: 0).isValid, isFalse);
    expect(const PlanItemDraft(weekday: 1, activity: WorkoutActivity.walk, targetMinutes: 30).isValid, isTrue);
  });

  test('les jours du programme comptent comme jours prévus de la semaine', () {
    final week = SportWeek.of(
      [done(WorkoutActivity.walk, daysAgo: 1)],
      const SportSettings(activities: {WorkoutActivity.walk}, trainingDays: {1}),
      now: now,
      planDays: {3, 5},
    );
    expect(week.plannedDays, {1, 3, 5});
    expect(week.keptDays, 1);
  });
}

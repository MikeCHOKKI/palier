import 'package:flutter_test/flutter_test.dart';
import 'package:palier/features/sport/domain/sport.dart';

void main() {
  Workout session(DateTime localAt, {int minutes = 30, int? meters, WorkoutActivity activity = WorkoutActivity.run}) =>
      Workout(
        id: '$localAt',
        activity: activity,
        occurredAt: localAt.toUtc(),
        durationSeconds: minutes * 60,
        distanceMeters: meters,
      );

  group('semaine', () {
    test('commence le lundi à minuit, même un dimanche soir', () {
      expect(weekStartOf(DateTime(2026, 11, 12, 18)), DateTime(2026, 11, 9));
      expect(weekStartOf(DateTime(2026, 11, 15, 23, 59)), DateTime(2026, 11, 9));
      expect(weekStartOf(DateTime(2026, 11, 16)), DateTime(2026, 11, 16));
      // Une semaine à cheval sur deux mois.
      expect(weekStartOf(DateTime(2026, 12, 2)), DateTime(2026, 11, 30));
    });

    test('additionne les seules séances de la semaine en cours', () {
      const settings = SportSettings(
        activities: {WorkoutActivity.run, WorkoutActivity.strength},
        trainingDays: {1, 3, 5},
        weeklyGoalMinutes: 90,
      );
      final week = SportWeek.of(
        [
          session(DateTime(2026, 11, 8, 20), minutes: 60), // dimanche d'avant
          session(DateTime(2026, 11, 9, 7), minutes: 30, meters: 5000), // lundi
          session(DateTime(2026, 11, 9, 19), minutes: 20, activity: WorkoutActivity.strength),
          session(DateTime(2026, 11, 12, 6), minutes: 45, meters: 6200), // jeudi
          session(DateTime(2026, 11, 16, 7)), // lundi suivant
        ],
        settings,
        now: DateTime(2026, 11, 12, 18),
      );

      expect(week.start, DateTime(2026, 11, 9));
      expect(week.minutes, 95);
      expect(week.sessions, 3);
      expect(week.distanceMeters, 11200);
      expect(week.doneDays, {1, 4});
      expect(week.keptDays, 1);
      expect(week.goalReached, isTrue);
    });

    test('sans objectif, la semaine n’est jamais « atteinte »', () {
      final week = SportWeek.of(
        [session(DateTime(2026, 11, 10), minutes: 300)],
        SportSettings.initial,
        now: DateTime(2026, 11, 12),
      );
      expect(week.goalMinutes, isNull);
      expect(week.goalReached, isFalse);
    });
  });

  group('séance', () {
    test('l’allure se calcule à partir de la durée et de la distance', () {
      final run = session(DateTime(2026, 11, 12), minutes: 30, meters: 5000);
      expect(run.paceSecondsPerKm, 360);
      expect(session(DateTime(2026, 11, 12)).paceSecondsPerKm, isNull);
    });

    test('le renforcement n’a pas de distance, même saisie', () {
      final draft = WorkoutDraft(
        activity: WorkoutActivity.strength,
        occurredAt: DateTime(2026, 11, 12),
        durationSeconds: 900,
        distanceMeters: 3000,
      );
      expect(draft.distanceMeters, isNull);
      expect(draft.problem, isNull);
    });

    test('une durée nulle ou une distance absurde est refusée', () {
      WorkoutDraft run(int seconds, {int? meters}) => WorkoutDraft(
        activity: WorkoutActivity.run,
        occurredAt: DateTime(2026, 11, 12),
        durationSeconds: seconds,
        distanceMeters: meters,
      );
      expect(run(0).problem, WorkoutProblem.badDuration);
      expect(run(25 * 3600).problem, WorkoutProblem.badDuration);
      expect(run(1800, meters: 0).problem, WorkoutProblem.badDistance);
      expect(run(1800, meters: 600000).problem, WorkoutProblem.badDistance);
      expect(run(1800, meters: 5000).problem, isNull);
    });
  });

  group('réglages', () {
    test('il faut au moins une activité, des jours valables et un objectif positif', () {
      expect(const SportSettings(activities: {}, trainingDays: {}).problem, SportSettingsProblem.noActivity);
      expect(
        const SportSettings(activities: {WorkoutActivity.walk}, trainingDays: {0}).problem,
        SportSettingsProblem.badDay,
      );
      expect(
        const SportSettings(activities: {WorkoutActivity.walk}, trainingDays: {}, weeklyGoalMinutes: 0).problem,
        SportSettingsProblem.badGoal,
      );
      expect(SportSettings.initial.problem, isNull);
    });
  });
}

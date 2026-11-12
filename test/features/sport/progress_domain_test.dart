import 'package:flutter_test/flutter_test.dart';
import 'package:palier/features/sport/domain/progress.dart';
import 'package:palier/features/sport/domain/sport.dart';

void main() {
  /// Jeudi 12 novembre 2026, 18 h. Sa semaine commence le lundi 9.
  final now = DateTime(2026, 11, 12, 18);

  var serial = 0;
  Workout session(WorkoutActivity activity, DateTime day, {int minutes = 30, int? meters, int seconds = 0}) => Workout(
    id: 's${serial++}',
    activity: activity,
    occurredAt: DateTime(day.year, day.month, day.day, 7).toUtc(),
    durationSeconds: minutes * 60 + seconds,
    distanceMeters: meters,
  );

  group('weeklyTotals', () {
    test('donne douze semaines, de la plus ancienne à la semaine en cours, vides comprises', () {
      final weeks = weeklyTotals(const [], now: now);
      expect(weeks, hasLength(12));
      expect(weeks.first.start, DateTime(2026, 8, 24));
      expect(weeks.last.start, DateTime(2026, 11, 9));
      expect(weeks.every((w) => w.sessions == 0 && w.minutes == 0), isTrue);
    });

    test('additionne minutes, distance, séances et jours actifs de chaque semaine', () {
      final weeks = weeklyTotals([
        session(WorkoutActivity.walk, DateTime(2026, 11, 9), minutes: 40, meters: 3500),
        // Deux séances le même jour : un seul jour actif.
        session(WorkoutActivity.run, DateTime(2026, 11, 11), minutes: 25, meters: 4000),
        session(WorkoutActivity.strength, DateTime(2026, 11, 11), minutes: 20),
        // La semaine d'avant.
        session(WorkoutActivity.walk, DateTime(2026, 11, 8), minutes: 30, seconds: 40),
      ], now: now);
      final current = weeks.last;
      expect(current.minutes, 85);
      expect(current.distanceMeters, 7500);
      expect(current.sessions, 3);
      expect(current.activeDays, 2);
      expect(current.valueOf(ProgressMetric.activeDays), 2);
      // 30 min 40 s s'arrondissent à 31.
      expect(weeks[10].minutes, 31);
    });

    test('ignore les séances d’avant la période et ne garde que l’activité demandée', () {
      final weeks = weeklyTotals(
        [
          session(WorkoutActivity.run, DateTime(2026, 8, 23)),
          session(WorkoutActivity.run, DateTime(2026, 8, 24), minutes: 20),
          session(WorkoutActivity.walk, DateTime(2026, 8, 25), minutes: 50),
        ],
        now: now,
        activity: WorkoutActivity.run,
      );
      expect(weeks.first.minutes, 20);
      expect(weeks.fold(0, (sum, w) => sum + w.sessions), 1);
    });
  });

  group('SportRecords', () {
    test('garde par activité la plus longue séance, la plus longue distance et la meilleure allure', () {
      final longWalk = session(WorkoutActivity.walk, DateTime(2026, 10, 1), minutes: 75, meters: 6000);
      final farWalk = session(WorkoutActivity.walk, DateTime(2026, 10, 8), minutes: 70, meters: 7000);
      final quickWalk = session(WorkoutActivity.walk, DateTime(2026, 10, 15), minutes: 20, meters: 2500);
      final strength = session(WorkoutActivity.strength, DateTime(2026, 10, 2), minutes: 35);
      final records = SportRecords.of([
        quickWalk,
        farWalk,
        longWalk,
        strength,
        session(WorkoutActivity.strength, DateTime(2026, 10, 9), minutes: 20),
      ], now: now);

      String describe(SportRecord r) => '${r.activity.name}:${r.kind.name}:${r.workout.id}';
      expect(records.records.map(describe), [
        'walk:longestDuration:${longWalk.id}',
        'walk:longestDistance:${farWalk.id}',
        'walk:bestPace:${quickWalk.id}',
        'strength:longestDuration:${strength.id}',
      ]);
    });

    test('ne compte pas l’allure en dessous d’un kilomètre, ni sans distance', () {
      final records = SportRecords.of([
        session(WorkoutActivity.run, DateTime(2026, 10, 1), minutes: 2, meters: 600),
        session(WorkoutActivity.run, DateTime(2026, 10, 2), minutes: 30),
      ], now: now);
      expect(records.records.map((r) => r.kind), [SportRecordKind.longestDuration, SportRecordKind.longestDistance]);
    });

    test('à égalité, le record reste à la première séance qui l’a établi', () {
      final first = session(WorkoutActivity.strength, DateTime(2026, 10, 1));
      final records = SportRecords.of([session(WorkoutActivity.strength, DateTime(2026, 10, 20)), first], now: now);
      expect(records.records.single.workout.id, first.id);
    });

    test('compte les semaines actives d’affilée, la plus longue série et celle en cours', () {
      final records = SportRecords.of([
        // Trois semaines d'affilée en septembre.
        session(WorkoutActivity.walk, DateTime(2026, 9, 7)),
        session(WorkoutActivity.walk, DateTime(2026, 9, 16)),
        session(WorkoutActivity.walk, DateTime(2026, 9, 19)),
        session(WorkoutActivity.walk, DateTime(2026, 9, 21)),
        // Puis les deux dernières semaines finies ; rien encore cette semaine.
        session(WorkoutActivity.run, DateTime(2026, 10, 26)),
        session(WorkoutActivity.run, DateTime(2026, 11, 8)),
      ], now: now);
      expect(records.longestStreakWeeks, 3);
      expect(records.currentStreakWeeks, 2);
    });

    test('une semaine finie sans séance remet la série en cours à zéro', () {
      final records = SportRecords.of([session(WorkoutActivity.walk, DateTime(2026, 10, 28))], now: now);
      expect(records.longestStreakWeeks, 1);
      expect(records.currentStreakWeeks, 0);
    });

    test('sans séance, ni record ni série', () {
      final records = SportRecords.of(const [], now: now);
      expect(records.records, isEmpty);
      expect(records.longestStreakWeeks, 0);
      expect(records.currentStreakWeeks, 0);
    });
  });
}

import 'sport.dart';

/// Ce qu'on suit semaine après semaine.
enum ProgressMetric {
  minutes,
  distance,

  /// Jours avec au moins une séance : la régularité, sans compter deux fois un même jour.
  activeDays,
}

/// Les séances d'une semaine, additionnées.
class WeekTotals {
  const WeekTotals({
    required this.start,
    this.minutes = 0,
    this.distanceMeters = 0,
    this.sessions = 0,
    this.activeDays = 0,
  });

  /// Le lundi de la semaine (minuit, heure locale).
  final DateTime start;
  final int minutes;
  final int distanceMeters;
  final int sessions;
  final int activeDays;

  int valueOf(ProgressMetric metric) => switch (metric) {
    ProgressMetric.minutes => minutes,
    ProgressMetric.distance => distanceMeters,
    ProgressMetric.activeDays => activeDays,
  };
}

/// Les [weeks] dernières semaines, de la plus ancienne à celle de [now], semaines
/// vides comprises : un trou dans le graphique dit aussi quelque chose.
///
/// [activity] limite le calcul à une activité ; `null` les prend toutes.
List<WeekTotals> weeklyTotals(
  List<Workout> workouts, {
  required DateTime now,
  int weeks = 12,
  WorkoutActivity? activity,
}) {
  final current = weekStartOf(now);
  // Construites jour par jour plutôt qu'en ajoutant 7 × 24 h : un changement
  // d'heure ne décale pas les lundis.
  final starts = [for (var i = weeks - 1; i >= 0; i--) DateTime(current.year, current.month, current.day - 7 * i)];
  final seconds = <DateTime, int>{};
  final meters = <DateTime, int>{};
  final sessions = <DateTime, int>{};
  final days = <DateTime, Set<int>>{};
  for (final workout in workouts) {
    if (activity != null && workout.activity != activity) continue;
    final at = workout.occurredAt.toLocal();
    final week = weekStartOf(at);
    if (week.isBefore(starts.first) || week.isAfter(current)) continue;
    seconds[week] = (seconds[week] ?? 0) + workout.durationSeconds;
    meters[week] = (meters[week] ?? 0) + (workout.distanceMeters ?? 0);
    sessions[week] = (sessions[week] ?? 0) + 1;
    (days[week] ??= {}).add(at.weekday);
  }
  return [
    for (final start in starts)
      WeekTotals(
        start: start,
        minutes: ((seconds[start] ?? 0) / 60).round(),
        distanceMeters: meters[start] ?? 0,
        sessions: sessions[start] ?? 0,
        activeDays: days[start]?.length ?? 0,
      ),
  ];
}

enum SportRecordKind { longestDuration, longestDistance, bestPace }

/// Un record personnel : la séance qui le détient.
class SportRecord {
  const SportRecord(this.kind, this.activity, this.workout);

  final SportRecordKind kind;
  final WorkoutActivity activity;
  final Workout workout;
}

/// Les records d'un profil, et ses semaines actives d'affilée.
class SportRecords {
  const SportRecords({required this.records, required this.longestStreakWeeks, required this.currentStreakWeeks});

  /// Une allure se compare à partir d'un kilomètre : sur quelques centaines de
  /// mètres, elle ferait un record qui ne dit rien.
  static const minPaceDistanceMeters = 1000;

  /// Par activité, dans l'ordre de [WorkoutActivity] : la plus longue séance,
  /// puis, pour la marche et la course, la plus longue distance et la meilleure allure.
  final List<SportRecord> records;

  /// Le plus grand nombre de semaines d'affilée avec au moins une séance.
  final int longestStreakWeeks;

  /// Les semaines d'affilée jusqu'à aujourd'hui. Une semaine en cours encore
  /// sans séance ne casse pas la série : elle n'est pas finie.
  final int currentStreakWeeks;

  static SportRecords of(List<Workout> workouts, {required DateTime now}) {
    // Du plus ancien au plus récent : à égalité, le record reste à la première
    // séance qui l'a établi.
    final ordered = [...workouts]..sort((a, b) => a.occurredAt.compareTo(b.occurredAt));
    final records = <SportRecord>[];
    for (final activity in WorkoutActivity.values) {
      final own = ordered.where((w) => w.activity == activity).toList();
      if (own.isEmpty) continue;
      Workout? best(int? Function(Workout) measure, {bool lowest = false}) {
        Workout? holder;
        int? record;
        for (final workout in own) {
          final value = measure(workout);
          if (value == null) continue;
          if (record == null || (lowest ? value < record : value > record)) {
            holder = workout;
            record = value;
          }
        }
        return holder;
      }

      records.add(SportRecord(SportRecordKind.longestDuration, activity, best((w) => w.durationSeconds)!));
      if (!activity.hasDistance) continue;
      if (best((w) => w.distanceMeters) case final longest?) {
        records.add(SportRecord(SportRecordKind.longestDistance, activity, longest));
      }
      final pace = best(
        (w) => (w.distanceMeters ?? 0) >= minPaceDistanceMeters ? w.paceSecondsPerKm : null,
        lowest: true,
      );
      if (pace != null) records.add(SportRecord(SportRecordKind.bestPace, activity, pace));
    }

    final weeks = {for (final workout in workouts) weekStartOf(workout.occurredAt.toLocal())};
    DateTime previous(DateTime monday) => DateTime(monday.year, monday.month, monday.day - 7);

    var longest = 0;
    for (final week in weeks) {
      // Ne compter qu'à partir du début d'une série.
      if (weeks.contains(previous(week))) continue;
      var length = 0;
      for (var w = week; weeks.contains(w); w = DateTime(w.year, w.month, w.day + 7)) {
        length++;
      }
      if (length > longest) longest = length;
    }

    var current = 0;
    var week = weekStartOf(now);
    if (!weeks.contains(week)) week = previous(week);
    for (; weeks.contains(week); week = previous(week)) {
      current++;
    }

    return SportRecords(records: records, longestStreakWeeks: longest, currentStreakWeeks: current);
  }
}

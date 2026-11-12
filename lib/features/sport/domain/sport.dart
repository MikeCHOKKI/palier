/// Le sport d'un profil : ses activités, ses séances et sa semaine.
///
/// Palier ne conseille rien : ni charge, ni allure, ni progression. La personne
/// choisit ses activités, ses jours et, si elle le veut, son objectif de la
/// semaine ; Palier note et additionne. Aucune calorie, aucun poids.
library;

/// Les activités suivies au lot 3.
enum WorkoutActivity {
  walk,
  run,
  strength;

  /// Marche et course se mesurent aussi en distance.
  bool get hasDistance => this != strength;
}

/// Le ressenti d'une séance, noté par la personne.
enum WorkoutEffort { easy, ok, hard }

/// Ce que la personne a réglé pour son sport.
class SportSettings {
  const SportSettings({required this.activities, required this.trainingDays, this.weeklyGoalMinutes});

  /// Réglages d'un profil qui n'a encore rien choisi : tout est proposé.
  static const initial = SportSettings(activities: {...WorkoutActivity.values}, trainingDays: {});

  /// Les activités proposées dans la saisie, dans l'ordre de [WorkoutActivity].
  final Set<WorkoutActivity> activities;

  /// Jours d'entraînement voulus, de 1 (lundi) à 7 (dimanche), comme [DateTime.weekday].
  final Set<int> trainingDays;

  /// Objectif de la semaine en minutes, choisi par la personne ; `null` sans objectif.
  final int? weeklyGoalMinutes;

  static const maxWeeklyGoalMinutes = 7 * 24 * 60;

  /// Ce qui empêche d'enregistrer ces réglages, ou `null`.
  SportSettingsProblem? get problem {
    if (activities.isEmpty) return SportSettingsProblem.noActivity;
    if (trainingDays.any((day) => day < DateTime.monday || day > DateTime.sunday)) {
      return SportSettingsProblem.badDay;
    }
    final goal = weeklyGoalMinutes;
    if (goal != null && (goal <= 0 || goal > maxWeeklyGoalMinutes)) return SportSettingsProblem.badGoal;
    return null;
  }

  /// Les activités dans un ordre stable, pour l'affichage et le stockage.
  List<WorkoutActivity> get orderedActivities => [
    for (final activity in WorkoutActivity.values)
      if (activities.contains(activity)) activity,
  ];

  List<int> get orderedDays => [...trainingDays]..sort();

  @override
  bool operator ==(Object other) =>
      other is SportSettings &&
      other.weeklyGoalMinutes == weeklyGoalMinutes &&
      other.activities.length == activities.length &&
      other.activities.containsAll(activities) &&
      other.trainingDays.length == trainingDays.length &&
      other.trainingDays.containsAll(trainingDays);

  @override
  int get hashCode =>
      Object.hash(Object.hashAllUnordered(activities), Object.hashAllUnordered(trainingDays), weeklyGoalMinutes);
}

enum SportSettingsProblem { noActivity, badDay, badGoal }

/// Une séance notée.
class Workout {
  const Workout({
    required this.id,
    required this.activity,
    required this.occurredAt,
    required this.durationSeconds,
    this.distanceMeters,
    this.effort,
    this.note,
    this.circuitId,
  });

  final String id;
  final WorkoutActivity activity;

  /// Moment de la séance (UTC).
  final DateTime occurredAt;
  final int durationSeconds;

  /// Distance en mètres, pour la marche et la course ; `null` si non notée.
  final int? distanceMeters;
  final WorkoutEffort? effort;
  final String? note;

  /// Le circuit suivi pour une séance guidée ; `null` pour une séance notée à la main.
  final String? circuitId;

  int get durationMinutes => (durationSeconds / 60).round();

  /// Secondes par kilomètre, quand la distance est connue.
  int? get paceSecondsPerKm {
    final meters = distanceMeters;
    if (meters == null || meters <= 0) return null;
    return (durationSeconds * 1000 / meters).round();
  }
}

/// Une séance à enregistrer.
class WorkoutDraft {
  const WorkoutDraft({
    required this.activity,
    required this.occurredAt,
    required this.durationSeconds,
    int? distanceMeters,
    this.effort,
    this.note,
    this.circuitId,
  }) : distanceMeters = activity == WorkoutActivity.strength ? null : distanceMeters;

  final WorkoutActivity activity;
  final DateTime occurredAt;
  final int durationSeconds;
  final int? distanceMeters;
  final WorkoutEffort? effort;
  final String? note;
  final String? circuitId;

  static const maxNoteLength = 120;

  /// Une séance dure moins d'une journée.
  static const maxDurationSeconds = 24 * 60 * 60;

  /// Au-delà, c'est une faute de frappe (un marathon fait 42 km).
  static const maxDistanceMeters = 500 * 1000;

  WorkoutProblem? get problem {
    if (durationSeconds <= 0 || durationSeconds > maxDurationSeconds) return WorkoutProblem.badDuration;
    final meters = distanceMeters;
    if (meters != null && (meters <= 0 || meters > maxDistanceMeters)) return WorkoutProblem.badDistance;
    return null;
  }
}

enum WorkoutProblem { badDuration, badDistance }

/// Le lundi (minuit, heure locale) de la semaine de [day].
DateTime weekStartOf(DateTime day) {
  final local = DateTime(day.year, day.month, day.day);
  return DateTime(local.year, local.month, local.day - (local.weekday - DateTime.monday));
}

/// La semaine en cours face aux réglages : minutes, séances, jours faits.
class SportWeek {
  SportWeek._({
    required this.start,
    required this.minutes,
    required this.sessions,
    required this.distanceMeters,
    required this.doneDays,
    required this.plannedDays,
    required this.goalMinutes,
  });

  /// Additionne les séances de la semaine de [now] (heure locale du téléphone).
  ///
  /// Les jours prévus sont ceux des réglages, plus ceux du programme ([planDays]).
  factory SportWeek.of(
    List<Workout> workouts,
    SportSettings settings, {
    required DateTime now,
    Set<int> planDays = const {},
  }) {
    final start = weekStartOf(now);
    final end = DateTime(start.year, start.month, start.day + 7);
    var seconds = 0;
    var sessions = 0;
    var meters = 0;
    final done = <int>{};
    for (final workout in workouts) {
      final at = workout.occurredAt.toLocal();
      if (at.isBefore(start) || !at.isBefore(end)) continue;
      seconds += workout.durationSeconds;
      sessions++;
      meters += workout.distanceMeters ?? 0;
      done.add(at.weekday);
    }
    return SportWeek._(
      start: start,
      minutes: (seconds / 60).round(),
      sessions: sessions,
      distanceMeters: meters,
      doneDays: done,
      plannedDays: {...settings.trainingDays, ...planDays},
      goalMinutes: settings.weeklyGoalMinutes,
    );
  }

  /// Le lundi de la semaine.
  final DateTime start;
  final int minutes;
  final int sessions;
  final int distanceMeters;

  /// Jours (1 = lundi) où au moins une séance est notée.
  final Set<int> doneDays;
  final Set<int> plannedDays;
  final int? goalMinutes;

  bool get goalReached => goalMinutes != null && minutes >= goalMinutes!;

  /// Jours prévus déjà tenus.
  int get keptDays => plannedDays.intersection(doneDays).length;
}

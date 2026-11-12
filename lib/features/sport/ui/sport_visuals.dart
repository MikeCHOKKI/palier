import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../../l10n/app_localizations.dart';
import '../domain/sport.dart';

IconData activityIcon(WorkoutActivity activity) => switch (activity) {
  WorkoutActivity.walk => Icons.directions_walk_rounded,
  WorkoutActivity.run => Icons.directions_run_rounded,
  WorkoutActivity.strength => Icons.fitness_center_rounded,
};

String activityName(AppLocalizations l10n, WorkoutActivity activity) => switch (activity) {
  WorkoutActivity.walk => l10n.sportActivityWalk,
  WorkoutActivity.run => l10n.sportActivityRun,
  WorkoutActivity.strength => l10n.sportActivityStrength,
};

String effortName(AppLocalizations l10n, WorkoutEffort effort) => switch (effort) {
  WorkoutEffort.easy => l10n.sportEffortEasy,
  WorkoutEffort.ok => l10n.sportEffortOk,
  WorkoutEffort.hard => l10n.sportEffortHard,
};

/// « 45 min », ou « 1 h 05 » à partir d'une heure.
String formatMinutes(AppLocalizations l10n, int minutes) {
  if (minutes < 60) return l10n.sportMinutes(minutes);
  return l10n.sportHours(minutes ~/ 60, (minutes % 60).toString().padLeft(2, '0'));
}

/// « 5,2 km », au plus deux décimales.
String formatDistance(AppLocalizations l10n, int meters) =>
    l10n.sportKilometers(NumberFormat('#,##0.##', 'fr').format(meters / 1000));

/// « 5:46 /km ».
String formatPace(AppLocalizations l10n, int secondsPerKm) =>
    l10n.sportPace('${secondsPerKm ~/ 60}:${(secondsPerKm % 60).toString().padLeft(2, '0')}');

/// Lit une distance en kilomètres (« 5,2 » ou « 5.2 ») ; `null` si ce n'en est pas une.
int? parseKilometers(String text) {
  final value = double.tryParse(text.trim().replaceAll(' ', '').replaceAll(',', '.'));
  if (value == null || value.isNaN || value.isInfinite) return null;
  return (value * 1000).round();
}

/// La première lettre d'un jour (« L » pour lundi), de 1 (lundi) à 7.
String weekdayInitial(int weekday) {
  // Le 5 janvier 2026 est un lundi.
  final day = DateTime(2026, 1, 4 + weekday);
  return DateFormat('EEEEE', 'fr').format(day).toUpperCase();
}

/// Le nom entier d'un jour, pour les lecteurs d'écran.
String weekdayName(int weekday) => DateFormat('EEEE', 'fr').format(DateTime(2026, 1, 4 + weekday));

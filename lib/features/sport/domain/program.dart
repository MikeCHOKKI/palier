import 'sport.dart';

/// Une séance prévue au programme : un jour de la semaine, et une activité (avec
/// une durée visée, facultative) ou un circuit de renforcement.
class PlanItem {
  const PlanItem({required this.id, required this.weekday, required this.activity, this.circuitId, this.targetMinutes});

  final String id;

  /// De 1 (lundi) à 7 (dimanche), comme [DateTime.weekday].
  final int weekday;
  final WorkoutActivity activity;

  /// Le circuit prévu ; l'activité est alors le renforcement.
  final String? circuitId;

  /// Durée visée, choisie par la personne ; `null` sans durée.
  final int? targetMinutes;
}

/// Une séance à ajouter au programme.
class PlanItemDraft {
  const PlanItemDraft({required this.weekday, required this.activity, this.circuitId, int? targetMinutes})
    : targetMinutes = circuitId == null ? targetMinutes : null;

  /// Un circuit au programme : du renforcement, sans durée visée (le circuit la fixe).
  const PlanItemDraft.circuit({required this.weekday, required String this.circuitId})
    : activity = WorkoutActivity.strength,
      targetMinutes = null;

  final int weekday;
  final WorkoutActivity activity;
  final String? circuitId;
  final int? targetMinutes;

  static const maxTargetMinutes = 24 * 60;

  bool get isValid {
    if (weekday < DateTime.monday || weekday > DateTime.sunday) return false;
    if (circuitId != null && activity != WorkoutActivity.strength) return false;
    final minutes = targetMinutes;
    return minutes == null || (minutes > 0 && minutes <= maxTargetMinutes);
  }
}

/// Une séance prévue aujourd'hui, et si elle est déjà faite.
class TodayItem {
  const TodayItem(this.item, {required this.done});

  final PlanItem item;
  final bool done;
}

/// Les séances prévues le jour de [now], dans l'ordre du programme, chacune
/// cochée par une séance notée ce jour-là. Une séance notée ne coche qu'une
/// seule prévision : d'abord celles d'un circuit (par le même circuit), puis
/// celles d'une activité (par la même activité, circuit ou non).
List<TodayItem> todayPlan(List<PlanItem> plan, List<Workout> workouts, {required DateTime now}) {
  final items = [
    for (final item in plan)
      if (item.weekday == now.weekday) item,
  ];
  final available = [
    for (final workout in workouts)
      if (_sameDay(workout.occurredAt.toLocal(), now)) workout,
  ];
  final done = <String>{};

  bool take(bool Function(Workout) matches) {
    final index = available.indexWhere(matches);
    if (index < 0) return false;
    available.removeAt(index);
    return true;
  }

  for (final item in items.where((i) => i.circuitId != null)) {
    if (take((w) => w.circuitId == item.circuitId)) done.add(item.id);
  }
  for (final item in items.where((i) => i.circuitId == null)) {
    if (take((w) => w.activity == item.activity)) done.add(item.id);
  }
  return [for (final item in items) TodayItem(item, done: done.contains(item.id))];
}

bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../expenses/ui/expenses_providers.dart' show activeProfileIdProvider;
import '../domain/circuits.dart';
import '../domain/program.dart';
import '../domain/sport.dart';

/// Les réglages de sport du profil ouvert, ou `null` tant qu'il ne les a pas enregistrés.
final sportSettingsProvider = StreamProvider<SportSettings?>((ref) {
  final profileId = ref.watch(activeProfileIdProvider);
  if (profileId == null) return Stream.value(null);
  return ref.watch(sportRepositoryProvider).watchSettings(profileId);
});

/// Les séances du profil ouvert, des plus récentes aux plus anciennes.
final workoutsProvider = StreamProvider<List<Workout>>((ref) {
  final profileId = ref.watch(activeProfileIdProvider);
  if (profileId == null) return Stream.value(const []);
  return ref.watch(sportRepositoryProvider).watchWorkouts(profileId);
});

/// La semaine en cours ; les réglages de départ tant que rien n'est réglé.
final sportWeekProvider = Provider<AsyncValue<SportWeek>>((ref) {
  final settings = ref.watch(sportSettingsProvider);
  final workouts = ref.watch(workoutsProvider);
  final planDays = {for (final item in ref.watch(planProvider).value ?? const <PlanItem>[]) item.weekday};
  final now = ref.watch(clockProvider)();
  return switch ((settings, workouts)) {
    (AsyncValue(error: final Object e, :final stackTrace), _) ||
    (_, AsyncValue(error: final Object e, :final stackTrace)) => AsyncValue.error(e, stackTrace ?? StackTrace.empty),
    (AsyncValue(hasValue: true, value: final SportSettings? s), AsyncValue(value: final List<Workout> list)) =>
      AsyncValue.data(SportWeek.of(list, s ?? SportSettings.initial, now: now, planDays: planDays)),
    _ => const AsyncValue.loading(),
  };
});

/// Les circuits du profil ouvert, avec leurs exercices.
final circuitsProvider = StreamProvider<List<Circuit>>((ref) {
  final profileId = ref.watch(activeProfileIdProvider);
  if (profileId == null) return Stream.value(const []);
  return ref.watch(sportRepositoryProvider).watchCircuits(profileId);
});

/// Le programme de la semaine du profil ouvert.
final planProvider = StreamProvider<List<PlanItem>>((ref) {
  final profileId = ref.watch(activeProfileIdProvider);
  if (profileId == null) return Stream.value(const []);
  return ref.watch(sportRepositoryProvider).watchPlan(profileId);
});

/// Ce qui est prévu aujourd'hui, coché par les séances notées.
final todayPlanProvider = Provider<List<TodayItem>>((ref) {
  final plan = ref.watch(planProvider).value ?? const <PlanItem>[];
  final workouts = ref.watch(workoutsProvider).value ?? const <Workout>[];
  return todayPlan(plan, workouts, now: ref.watch(clockProvider)());
});

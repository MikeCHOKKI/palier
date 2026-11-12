import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
// Ses push/pop sur BuildContext masqueraient ceux de go_router.
import 'package:lucid_core_flutter/lucid_core_flutter.dart' hide LucidNavigationExtensions;
import 'package:material_ui/material_ui.dart';

import '../../../app/providers.dart';
import '../../../app/routes.dart';
import '../../../app/theme/palier_theme.dart';
import '../../../app/theme/palier_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../expenses/ui/expense_widgets.dart' show dayLabel;
import '../domain/circuits.dart';
import '../domain/sport.dart';
import 'sport_providers.dart';
import 'sport_visuals.dart';
import 'today_plan.dart';

/// Les séances affichées sous la semaine ; les plus anciennes viendront avec le suivi des progrès.
const _recentCount = 20;

/// L'onglet Sport : la semaine face à ses réglages, puis les dernières séances.
class SportScreen extends ConsumerWidget {
  const SportScreen({super.key});

  /// Le bouton « Noter une séance », porté par le Scaffold des onglets comme celui des dépenses.
  static Widget addButton(BuildContext context) => FloatingActionButton.extended(
    onPressed: () => context.push(Routes.sportNew),
    icon: const Icon(Icons.add_rounded),
    label: Text(AppLocalizations.of(context).sportAdd),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final settings = ref.watch(sportSettingsProvider);
    final workouts = ref.watch(workoutsProvider);
    final week = ref.watch(sportWeekProvider);

    return Scaffold(
      body: SafeArea(
        child: switch ((settings, workouts, week)) {
          (AsyncValue(error: final Object _), _, _) ||
          (_, AsyncValue(error: final Object _), _) => LucidErrorState(message: l10n.errorGeneric),
          (
            AsyncValue(hasValue: true, value: final SportSettings? s),
            AsyncValue(value: final List<Workout> list),
            AsyncValue(value: final SportWeek w),
          ) =>
            _Content(settings: s, workouts: list, week: w),
          _ => const Center(child: CircularProgressIndicator()),
        },
      ),
    );
  }
}

class _Content extends ConsumerWidget {
  const _Content({required this.settings, required this.workouts, required this.week});

  /// `null` tant que la personne n'a pas réglé son sport.
  final SportSettings? settings;
  final List<Workout> workouts;
  final SportWeek week;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final now = ref.watch(clockProvider)();
    final recent = workouts.take(_recentCount).toList();
    final circuits = ref.watch(circuitsProvider).value ?? const <Circuit>[];

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(PalierSpace.page, PalierSpace.lg, PalierSpace.page, 0),
          sliver: SliverList.list(
            children: [
              Row(
                children: [
                  Expanded(child: Text(l10n.sportTitle, style: text.headlineMedium)),
                  IconButton(
                    tooltip: l10n.sportProgramMenu,
                    icon: const Icon(Icons.calendar_month_outlined),
                    onPressed: () => context.push(Routes.sportProgram),
                  ),
                  IconButton(
                    tooltip: l10n.sportSettingsMenu,
                    icon: const Icon(Icons.tune_rounded),
                    onPressed: () => context.push(Routes.sportSettings),
                  ),
                ],
              ),
              const SizedBox(height: PalierSpace.lg),
              if (settings == null) ...[const _SetupCard(), const SizedBox(height: PalierSpace.lg)],
              if (ref.watch(todayPlanProvider).isNotEmpty) ...[
                const TodayPlanCard(),
                const SizedBox(height: PalierSpace.lg),
              ],
              _WeekBlock(week: week, today: now.weekday),
              if (ref.watch(planProvider).value?.isEmpty ?? false)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    style: TextButton.styleFrom(padding: EdgeInsets.zero),
                    onPressed: () => context.push(Routes.sportProgram),
                    icon: const Icon(Icons.calendar_month_outlined),
                    label: Text(l10n.todayEmptyPlan),
                  ),
                ),
              if (circuits.isNotEmpty ||
                  (settings ?? SportSettings.initial).activities.contains(WorkoutActivity.strength)) ...[
                const SizedBox(height: PalierSpace.xl),
                _CircuitsBlock(circuits: circuits),
              ],
              const SizedBox(height: PalierSpace.xl),
              Text(l10n.sportRecentTitle, style: text.titleMedium),
              const SizedBox(height: PalierSpace.sm),
            ],
          ),
        ),
        if (recent.isEmpty)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(PalierSpace.page, PalierSpace.md, PalierSpace.page, 0),
            sliver: SliverToBoxAdapter(
              child: LucidEmptyState(
                icon: Icons.directions_walk_rounded,
                title: l10n.sportEmptyTitle,
                message: l10n.sportEmptyBody,
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: PalierSpace.page),
            sliver: SliverList.separated(
              itemCount: recent.length,
              separatorBuilder: (_, _) => const Divider(height: 1, color: PalierColors.line),
              itemBuilder: (_, i) => WorkoutTile(
                workout: recent[i],
                now: now,
                onTap: () => context.push(Routes.sportWorkout(recent[i].id)),
              ),
            ),
          ),
        // De la place pour le bouton « Noter une séance ».
        const SliverToBoxAdapter(child: SizedBox(height: 96)),
      ],
    );
  }
}

/// Les circuits de renforcement : les lancer d'un geste, ou en composer un.
class _CircuitsBlock extends StatelessWidget {
  const _CircuitsBlock({required this.circuits});

  final List<Circuit> circuits;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final accent = Theme.of(context).colorScheme.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.sportCircuitsTitle, style: text.titleMedium),
        const SizedBox(height: PalierSpace.sm),
        if (circuits.isEmpty)
          Text(
            l10n.sportCircuitsEmpty,
            style: manrope(size: 14, weight: FontWeight.w500, color: PalierColors.textMid),
          ),
        for (final circuit in circuits)
          Padding(
            padding: const EdgeInsets.only(bottom: PalierSpace.sm),
            child: Material(
              color: PalierColors.surface,
              borderRadius: BorderRadius.circular(PalierRadius.md),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => context.push(Routes.sportCircuit(circuit.id)),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(PalierSpace.md, PalierSpace.sm, PalierSpace.sm, PalierSpace.sm),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(circuit.name, style: manrope(size: 15, weight: FontWeight.w600)),
                            Text(
                              [
                                l10n.circuitRounds(circuit.rounds),
                                l10n.circuitExerciseCount(circuit.exercises.length),
                              ].join(' · '),
                              style: manrope(size: 13, weight: FontWeight.w500, color: PalierColors.textLow),
                            ),
                          ],
                        ),
                      ),
                      IconButton.filled(
                        tooltip: l10n.circuitStart(circuit.name),
                        style: IconButton.styleFrom(backgroundColor: accent, foregroundColor: PalierColors.night),
                        onPressed: () => context.push(Routes.sportCircuitPlay(circuit.id)),
                        icon: const Icon(Icons.play_arrow_rounded),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        TextButton.icon(
          style: TextButton.styleFrom(padding: EdgeInsets.zero),
          onPressed: () => context.push(Routes.sportCircuitNew),
          icon: const Icon(Icons.add_rounded),
          label: Text(l10n.circuitAdd),
        ),
      ],
    );
  }
}

/// Avant les premiers réglages : une invitation, sans bloquer la saisie.
class _SetupCard extends StatelessWidget {
  const _SetupCard();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final accent = Theme.of(context).colorScheme.primary;
    return DecoratedBox(
      decoration: BoxDecoration(color: PalierColors.indigo, borderRadius: BorderRadius.circular(PalierRadius.md)),
      child: Padding(
        padding: const EdgeInsets.all(PalierSpace.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.flag_outlined, color: accent),
            const SizedBox(width: PalierSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.sportSetupTitle, style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: PalierSpace.xs),
                  Text(
                    l10n.sportSetupBody,
                    style: manrope(size: 14, weight: FontWeight.w500, color: PalierColors.textMid),
                  ),
                  const SizedBox(height: PalierSpace.sm),
                  TextButton(
                    style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 40)),
                    onPressed: () => context.push(Routes.sportSettings),
                    child: Text(l10n.sportSetupAction),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Les minutes de la semaine face à l'objectif, puis les sept jours.
class _WeekBlock extends StatelessWidget {
  const _WeekBlock({required this.week, required this.today});

  final SportWeek week;
  final int today;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final accent = Theme.of(context).colorScheme.primary;
    final goal = week.goalMinutes;

    final facts = [
      l10n.sportWeekSessions(week.sessions),
      if (week.distanceMeters > 0) formatDistance(l10n, week.distanceMeters),
      if (week.plannedDays.isNotEmpty) l10n.sportWeekDaysKept(week.keptDays, week.plannedDays.length),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.sportWeekLabel, style: text.labelMedium),
        const SizedBox(height: PalierSpace.xs),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              formatMinutes(l10n, week.minutes),
              style: text.displaySmall!.copyWith(
                color: week.goalReached ? accent : PalierColors.textHigh,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            if (goal != null) ...[
              const SizedBox(width: PalierSpace.sm),
              Text(
                l10n.sportWeekGoal(formatMinutes(l10n, goal)),
                style: manrope(size: 16, weight: FontWeight.w600, color: PalierColors.textMid),
              ),
            ],
          ],
        ),
        if (goal != null) ...[
          const SizedBox(height: PalierSpace.sm),
          LucidMeter(
            value: week.minutes,
            max: goal,
            color: accent,
            // Dépasser son objectif reste une bonne nouvelle : la jauge garde sa couleur.
            warningColor: accent,
            overColor: accent,
            trackColor: PalierColors.indigo,
            height: 8,
            semanticLabel: l10n.sportWeekLabel,
            semanticValue: '${formatMinutes(l10n, week.minutes)} ${l10n.sportWeekGoal(formatMinutes(l10n, goal))}',
          ),
          if (week.goalReached) ...[
            const SizedBox(height: PalierSpace.sm),
            Row(
              children: [
                Icon(Icons.check_circle_rounded, size: 18, color: accent),
                const SizedBox(width: PalierSpace.xs + 2),
                Text(
                  l10n.sportWeekGoalReached,
                  style: manrope(size: 14, weight: FontWeight.w600, color: accent),
                ),
              ],
            ),
          ],
        ],
        const SizedBox(height: PalierSpace.sm),
        Text(
          facts.join(' · '),
          style: manrope(size: 14, weight: FontWeight.w500, color: PalierColors.textMid),
        ),
        const SizedBox(height: PalierSpace.md),
        _WeekDays(week: week, today: today),
      ],
    );
  }
}

/// Lundi à dimanche : plein pour un jour avec séance, cerclé pour un jour prévu.
class _WeekDays extends StatelessWidget {
  const _WeekDays({required this.week, required this.today});

  final SportWeek week;
  final int today;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final accent = Theme.of(context).colorScheme.primary;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (var day = DateTime.monday; day <= DateTime.sunday; day++)
          Builder(
            builder: (context) {
              final done = week.doneDays.contains(day);
              final planned = week.plannedDays.contains(day);
              final name = weekdayName(day);
              return Semantics(
                container: true,
                label: done
                    ? l10n.sportDayDone(name)
                    : planned
                    ? l10n.sportDayPlanned(name)
                    : l10n.sportDayFree(name),
                excludeSemantics: true,
                child: Column(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: done ? accent : Colors.transparent,
                        border: Border.all(
                          color: done || planned ? accent : PalierColors.line,
                          width: planned && !done ? 2 : 1,
                        ),
                      ),
                      child: done
                          ? const Icon(Icons.check_rounded, size: 20, color: PalierColors.night)
                          : Text(
                              weekdayInitial(day),
                              style: manrope(
                                size: 13,
                                weight: FontWeight.w700,
                                color: planned ? PalierColors.textHigh : PalierColors.textLow,
                              ),
                            ),
                    ),
                    const SizedBox(height: PalierSpace.xs),
                    // Un point sous aujourd'hui.
                    Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: day == today ? PalierColors.textHigh : Colors.transparent,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}

/// Une séance : activité et durée, puis le jour, la distance, l'allure et le ressenti.
class WorkoutTile extends StatelessWidget {
  const WorkoutTile({super.key, required this.workout, required this.now, required this.onTap});

  final Workout workout;
  final DateTime now;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final accent = Theme.of(context).colorScheme.primary;
    final day = workout.occurredAt.toLocal();
    final meters = workout.distanceMeters;
    final pace = workout.paceSecondsPerKm;
    final details = [
      dayLabel(l10n, DateTime(day.year, day.month, day.day), DateFormat.MMMMEEEEd('fr').format, now: now),
      if (meters != null) formatDistance(l10n, meters),
      if (pace != null) formatPace(l10n, pace),
      if (workout.effort case final effort?) effortName(l10n, effort),
    ];

    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: PalierSpace.sm + 2),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(shape: BoxShape.circle, color: accent.withValues(alpha: 0.14)),
                child: Icon(activityIcon(workout.activity), size: 22, color: accent),
              ),
              const SizedBox(width: PalierSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      activityName(l10n, workout.activity),
                      style: manrope(size: 15, weight: FontWeight.w600, color: PalierColors.textHigh),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      details.join(' · '),
                      style: manrope(size: 13, weight: FontWeight.w500, color: PalierColors.textLow),
                    ),
                    if (workout.note case final note?)
                      Text(
                        note,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: manrope(size: 13, weight: FontWeight.w500, color: PalierColors.textMid),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: PalierSpace.sm),
              Text(
                formatMinutes(l10n, workout.durationMinutes),
                style: manrope(
                  size: 15,
                  weight: FontWeight.w700,
                  color: PalierColors.textHigh,
                ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucid_core_flutter/lucid_core_flutter.dart' show LucidEmptyState, LucidErrorState;
import 'package:material_ui/material_ui.dart';

import '../../../app/providers.dart';
import '../../../app/routes.dart';
import '../../../app/theme/palier_theme.dart';
import '../../../app/theme/palier_tokens.dart';
import '../../../core/ui/choice_widgets.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/progress.dart';
import '../domain/sport.dart';
import 'sport_providers.dart';
import 'sport_screen.dart' show WorkoutTile;
import 'sport_visuals.dart';

/// Les progrès : douze semaines en graphique, les records, puis toutes les séances.
///
/// Des chiffres, jamais de conseil : Palier montre ce qui a été fait, la
/// personne en tire ce qu'elle veut.
class ProgressScreen extends ConsumerStatefulWidget {
  const ProgressScreen({super.key});

  @override
  ConsumerState<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends ConsumerState<ProgressScreen> {
  /// `null` : toutes les activités.
  WorkoutActivity? _activity;
  ProgressMetric _metric = ProgressMetric.minutes;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final workouts = ref.watch(workoutsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.progressTitle)),
      body: SafeArea(
        top: false,
        child: switch (workouts) {
          AsyncValue(error: final Object _) => LucidErrorState(message: l10n.errorGeneric),
          AsyncValue(hasValue: true, value: final List<Workout> list) when list.isEmpty => Padding(
            padding: const EdgeInsets.all(PalierSpace.page),
            child: LucidEmptyState(
              icon: Icons.bar_chart_rounded,
              title: l10n.progressEmptyTitle,
              message: l10n.progressEmptyBody,
            ),
          ),
          AsyncValue(hasValue: true, value: final List<Workout> list) => _content(context, list),
          _ => const Center(child: CircularProgressIndicator()),
        },
      ),
    );
  }

  Widget _content(BuildContext context, List<Workout> all) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final now = ref.watch(clockProvider)();

    // Les filtres ne proposent que les activités déjà pratiquées.
    final practiced = [
      for (final activity in WorkoutActivity.values)
        if (all.any((w) => w.activity == activity)) activity,
    ];
    final activity = practiced.contains(_activity) ? _activity : null;
    final distanceAvailable = activity?.hasDistance ?? all.any((w) => w.distanceMeters != null);
    final metric = !distanceAvailable && _metric == ProgressMetric.distance ? ProgressMetric.minutes : _metric;

    final workouts = activity == null ? all : all.where((w) => w.activity == activity).toList();
    final weeks = weeklyTotals(workouts, now: now);
    final records = SportRecords.of(workouts, now: now);
    final goal = activity == null ? ref.watch(sportSettingsProvider).value?.weeklyGoalMinutes : null;
    final plannedDays = ref.watch(sportWeekProvider).value?.plannedDays.length ?? 0;
    final line = switch (metric) {
      ProgressMetric.minutes when goal != null => (goal, l10n.progressGoalLine),
      ProgressMetric.activeDays when activity == null && plannedDays > 0 => (plannedDays, l10n.progressPlannedLine),
      _ => null,
    };

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(PalierSpace.page, PalierSpace.sm, PalierSpace.page, 0),
          sliver: SliverList.list(
            children: [
              if (practiced.length > 1) ...[
                PillRow(
                  children: [
                    ChoicePill(
                      label: l10n.progressAll,
                      selected: activity == null,
                      onTap: () => setState(() => _activity = null),
                    ),
                    for (final a in practiced)
                      ChoicePill(
                        label: activityName(l10n, a),
                        icon: activityIcon(a),
                        selected: activity == a,
                        onTap: () => setState(() => _activity = a),
                      ),
                  ],
                ),
                const SizedBox(height: PalierSpace.md),
              ],
              _MetricSwitch(
                metric: metric,
                distanceAvailable: distanceAvailable,
                onChanged: (m) => setState(() => _metric = m),
              ),
              const SizedBox(height: PalierSpace.lg),
              _Summary(weeks: weeks, metric: metric),
              const SizedBox(height: PalierSpace.md),
              _WeeksChart(weeks: weeks, metric: metric, line: line),
              const SizedBox(height: PalierSpace.xl),
              Text(l10n.progressRecordsTitle, style: text.titleMedium),
              const SizedBox(height: PalierSpace.xs),
              _Streak(records: records),
              for (final record in records.records)
                _RecordTile(
                  record: record,
                  showActivity: activity == null,
                  onTap: () => context.push(Routes.sportWorkout(record.workout.id)),
                ),
              const SizedBox(height: PalierSpace.xl),
              Text(l10n.progressHistoryTitle, style: text.titleMedium),
              const SizedBox(height: PalierSpace.sm),
            ],
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(PalierSpace.page, 0, PalierSpace.page, PalierSpace.xl),
          sliver: SliverList.separated(
            itemCount: workouts.length,
            separatorBuilder: (_, _) => const Divider(height: 1, color: PalierColors.line),
            itemBuilder: (_, i) => WorkoutTile(
              workout: workouts[i],
              now: now,
              onTap: () => context.push(Routes.sportWorkout(workouts[i].id)),
            ),
          ),
        ),
      ],
    );
  }
}

String _metricName(AppLocalizations l10n, ProgressMetric metric) => switch (metric) {
  ProgressMetric.minutes => l10n.progressMetricMinutes,
  ProgressMetric.distance => l10n.progressMetricDistance,
  ProgressMetric.activeDays => l10n.progressMetricDays,
};

/// Une valeur de la semaine, en toutes lettres : « 1 h 20 », « 5,2 km », « 3 jours actifs ».
String _formatValue(AppLocalizations l10n, ProgressMetric metric, int value) => switch (metric) {
  ProgressMetric.minutes => formatMinutes(l10n, value),
  ProgressMetric.distance => formatDistance(l10n, value),
  ProgressMetric.activeDays => l10n.progressDaysTotal(value),
};

class _MetricSwitch extends StatelessWidget {
  const _MetricSwitch({required this.metric, required this.distanceAvailable, required this.onChanged});

  final ProgressMetric metric;
  final bool distanceAvailable;
  final ValueChanged<ProgressMetric> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SegmentedButton<ProgressMetric>(
      showSelectedIcon: false,
      segments: [
        for (final m in ProgressMetric.values)
          if (m != ProgressMetric.distance || distanceAvailable)
            ButtonSegment(value: m, label: Text(_metricName(l10n, m))),
      ],
      selected: {metric},
      onSelectionChanged: (selection) => onChanged(selection.single),
    );
  }
}

/// Le total des douze semaines, et la moyenne par semaine.
class _Summary extends StatelessWidget {
  const _Summary({required this.weeks, required this.metric});

  final List<WeekTotals> weeks;
  final ProgressMetric metric;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final total = weeks.fold(0, (sum, w) => sum + w.valueOf(metric));
    final average = total / weeks.length;
    final averageText = switch (metric) {
      ProgressMetric.minutes => l10n.progressAverage(formatMinutes(l10n, average.round())),
      ProgressMetric.distance => l10n.progressAverage(formatDistance(l10n, average.round())),
      ProgressMetric.activeDays => l10n.progressDaysAverage(NumberFormat('0.#', 'fr').format(average)),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.progressPeriod, style: text.labelMedium),
        const SizedBox(height: PalierSpace.xs),
        Text(
          _formatValue(l10n, metric, total),
          style: text.displaySmall!.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
        ),
        const SizedBox(height: PalierSpace.xs),
        Text(
          averageText,
          style: manrope(size: 14, weight: FontWeight.w500, color: PalierColors.textMid),
        ),
      ],
    );
  }
}

/// Douze barres, une par semaine ; la semaine en cours en plein. Une ligne
/// pointillée rappelle l'objectif ou les jours prévus, quand il y en a.
class _WeeksChart extends StatelessWidget {
  const _WeeksChart({required this.weeks, required this.metric, required this.line});

  final List<WeekTotals> weeks;
  final ProgressMetric metric;

  /// La valeur de la ligne et son nom, ou `null`.
  final (int, String)? line;

  /// Le pas des graduations : le plus petit qui garde au plus quatre traits.
  static int _step(ProgressMetric metric, int max) {
    final candidates = switch (metric) {
      ProgressMetric.minutes => const [15, 30, 60, 120, 180, 300, 600, 1200, 3000],
      ProgressMetric.distance => const [500, 1000, 2000, 5000, 10000, 20000, 50000, 100000, 200000],
      ProgressMetric.activeDays => const [1, 2],
    };
    return candidates.firstWhere((step) => max / step <= 4, orElse: () => candidates.last);
  }

  String _axisLabel(AppLocalizations l10n, int value) => switch (metric) {
    ProgressMetric.minutes when value >= 60 && value % 60 == 0 => l10n.progressAxisHours(value ~/ 60),
    ProgressMetric.minutes => formatMinutes(l10n, value),
    ProgressMetric.distance => formatDistance(l10n, value),
    ProgressMetric.activeDays => '$value',
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final accent = Theme.of(context).colorScheme.primary;
    final shortDay = DateFormat('d MMM', 'fr');
    final longDay = DateFormat('d MMMM', 'fr');
    final values = [for (final week in weeks) week.valueOf(metric)];
    final highest = math.max(values.reduce(math.max), line?.$1 ?? 0);
    final step = _step(metric, math.max(highest, 1));
    // Une semaine compte sept jours : la régularité s'arrête là.
    final maxY = metric == ProgressMetric.activeDays ? 7 : step * math.max(1, (highest / step).ceil());
    final axisStyle = manrope(size: 11, weight: FontWeight.w600, color: PalierColors.textLow);

    final description = [
      for (final (i, week) in weeks.indexed)
        '${l10n.progressWeekOf(longDay.format(week.start))} : ${_formatValue(l10n, metric, values[i])}',
    ].join(' ; ');

    return Semantics(
      container: true,
      label: l10n.progressChartLabel(_metricName(l10n, metric)),
      value: description,
      excludeSemantics: true,
      child: SizedBox(
        height: 200,
        child: BarChart(
          duration: const Duration(milliseconds: 250),
          BarChartData(
            maxY: maxY.toDouble(),
            alignment: BarChartAlignment.spaceAround,
            borderData: FlBorderData(show: false),
            gridData: FlGridData(
              drawVerticalLine: false,
              horizontalInterval: step.toDouble(),
              getDrawingHorizontalLine: (_) => const FlLine(color: PalierColors.line, strokeWidth: 1),
            ),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(),
              rightTitles: const AxisTitles(),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 52,
                  interval: step.toDouble(),
                  getTitlesWidget: (value, meta) => value == meta.max && maxY % step != 0
                      ? const SizedBox.shrink()
                      : SideTitleWidget(
                          meta: meta,
                          child: Text(_axisLabel(l10n, value.round()), style: axisStyle),
                        ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 28,
                  getTitlesWidget: (value, meta) {
                    final i = value.round();
                    // Une étiquette toutes les trois semaines, en finissant par la semaine en cours.
                    if ((weeks.length - 1 - i) % 3 != 0) return const SizedBox.shrink();
                    return SideTitleWidget(
                      meta: meta,
                      child: Text(shortDay.format(weeks[i].start), style: axisStyle),
                    );
                  },
                ),
              ),
            ),
            extraLinesData: ExtraLinesData(
              horizontalLines: [
                if (line case (final value, final name))
                  HorizontalLine(
                    y: value.toDouble(),
                    color: PalierColors.textMid,
                    strokeWidth: 1.5,
                    dashArray: const [6, 4],
                    label: HorizontalLineLabel(
                      show: true,
                      alignment: Alignment.topRight,
                      padding: const EdgeInsets.only(bottom: 2),
                      style: manrope(size: 11, weight: FontWeight.w700, color: PalierColors.textMid),
                      labelResolver: (_) => name,
                    ),
                  ),
              ],
            ),
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipColor: (_) => PalierColors.indigo,
                fitInsideHorizontally: true,
                fitInsideVertically: true,
                getTooltipItem: (group, _, _, _) => BarTooltipItem(
                  '${l10n.progressWeekOf(shortDay.format(weeks[group.x].start))}\n',
                  manrope(size: 12, weight: FontWeight.w500, color: PalierColors.textMid),
                  children: [
                    TextSpan(
                      text: _formatValue(l10n, metric, values[group.x]),
                      style: manrope(size: 14, weight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ),
            barGroups: [
              for (final (i, value) in values.indexed)
                BarChartGroupData(
                  x: i,
                  barRods: [
                    BarChartRodData(
                      toY: value.toDouble(),
                      width: 14,
                      color: i == values.length - 1 ? accent : accent.withValues(alpha: 0.5),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Les semaines actives d'affilée : la série en cours, et la plus longue.
class _Streak extends StatelessWidget {
  const _Streak({required this.records});

  final SportRecords records;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final accent = Theme.of(context).colorScheme.primary;
    final current = records.currentStreakWeeks;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: PalierSpace.sm),
      child: Row(
        children: [
          Icon(Icons.local_fire_department_rounded, size: 22, color: current > 0 ? accent : PalierColors.textLow),
          const SizedBox(width: PalierSpace.sm + 4),
          Expanded(
            child: Text.rich(
              TextSpan(
                text: l10n.progressStreakCurrent(current),
                style: manrope(size: 15, weight: FontWeight.w600),
                children: [
                  if (records.longestStreakWeeks > current)
                    TextSpan(
                      text: ' · ${l10n.progressStreakBest(records.longestStreakWeeks)}',
                      style: manrope(size: 14, weight: FontWeight.w500, color: PalierColors.textMid),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Un record : ce qu'il mesure, la séance qui le détient (et quand), sa valeur.
class _RecordTile extends StatelessWidget {
  const _RecordTile({required this.record, required this.showActivity, required this.onTap});

  final SportRecord record;
  final bool showActivity;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final accent = Theme.of(context).colorScheme.primary;
    final workout = record.workout;
    final title = switch (record.kind) {
      SportRecordKind.longestDuration => l10n.progressRecordDuration,
      SportRecordKind.longestDistance => l10n.progressRecordDistance,
      SportRecordKind.bestPace => l10n.progressRecordPace,
    };
    final value = switch (record.kind) {
      SportRecordKind.longestDuration => formatMinutes(l10n, workout.durationMinutes),
      SportRecordKind.longestDistance => formatDistance(l10n, workout.distanceMeters!),
      SportRecordKind.bestPace => formatPace(l10n, workout.paceSecondsPerKm!),
    };
    final details = [
      if (showActivity) activityName(l10n, record.activity),
      DateFormat.yMMMMd('fr').format(workout.occurredAt.toLocal()),
    ].join(' · ');

    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: PalierSpace.sm),
          child: Row(
            children: [
              Icon(activityIcon(record.activity), size: 22, color: accent),
              const SizedBox(width: PalierSpace.sm + 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: manrope(size: 15, weight: FontWeight.w600)),
                    Text(
                      details,
                      style: manrope(size: 13, weight: FontWeight.w500, color: PalierColors.textLow),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: PalierSpace.sm),
              Text(
                value,
                style: manrope(
                  size: 15,
                  weight: FontWeight.w700,
                ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

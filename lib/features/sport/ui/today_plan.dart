import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/routes.dart';
import '../../../app/theme/palier_theme.dart';
import '../../../app/theme/palier_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/circuits.dart';
import '../domain/program.dart';
import 'sport_providers.dart';
import 'sport_visuals.dart';
import 'workout_screen.dart' show WorkoutPrefill;

/// Le nom d'une séance prévue : celui de son circuit, sinon de son activité.
/// Un circuit supprimé depuis redevient du « Renforcement ».
String planItemName(AppLocalizations l10n, PlanItem item, List<Circuit> circuits) {
  for (final circuit in circuits) {
    if (circuit.id == item.circuitId) return circuit.name;
  }
  return activityName(l10n, item.activity);
}

/// « Marche · 30 min », ou le seul nom.
String planItemLabel(AppLocalizations l10n, PlanItem item, List<Circuit> circuits) {
  final name = planItemName(l10n, item, circuits);
  final minutes = item.targetMinutes;
  return minutes == null ? name : '$name · ${formatMinutes(l10n, minutes)}';
}

/// Ce qui est prévu aujourd'hui, coché au fil des séances notées, avec de quoi
/// lancer un circuit ou noter une activité. Rien quand aujourd'hui est libre.
class TodayPlanCard extends ConsumerWidget {
  const TodayPlanCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final today = ref.watch(todayPlanProvider);
    if (today.isEmpty) return const SizedBox.shrink();
    final circuits = ref.watch(circuitsProvider).value ?? const <Circuit>[];
    final accent = Theme.of(context).colorScheme.primary;
    final allDone = today.every((t) => t.done);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: PalierColors.surface,
        borderRadius: BorderRadius.circular(PalierRadius.md),
        border: Border.all(color: allDone ? accent.withValues(alpha: 0.5) : PalierColors.line),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(PalierSpace.md, PalierSpace.md, PalierSpace.sm, PalierSpace.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.todayTitle, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: PalierSpace.xs),
            for (final entry in today) _TodayRow(entry: entry, circuits: circuits),
            if (allDone)
              Padding(
                padding: const EdgeInsets.only(top: PalierSpace.xs, bottom: PalierSpace.xs),
                child: Text(
                  l10n.todayAllDone,
                  style: manrope(size: 14, weight: FontWeight.w600, color: accent),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TodayRow extends StatelessWidget {
  const _TodayRow({required this.entry, required this.circuits});

  final TodayItem entry;
  final List<Circuit> circuits;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final accent = Theme.of(context).colorScheme.primary;
    final item = entry.item;
    final name = planItemName(l10n, item, circuits);
    final circuitExists = circuits.any((c) => c.id == item.circuitId);

    final Widget action;
    if (entry.done) {
      action = Padding(
        padding: const EdgeInsets.symmetric(horizontal: PalierSpace.sm),
        child: Text(
          l10n.todayDone,
          style: manrope(size: 14, weight: FontWeight.w700, color: accent),
        ),
      );
    } else if (circuitExists) {
      action = IconButton.filled(
        tooltip: l10n.todayStartCircuit(name),
        style: IconButton.styleFrom(backgroundColor: accent, foregroundColor: PalierColors.night),
        onPressed: () => context.push(Routes.sportCircuitPlay(item.circuitId!)),
        icon: const Icon(Icons.play_arrow_rounded),
      );
    } else {
      action = IconButton.outlined(
        tooltip: l10n.todayNote(name),
        onPressed: () => context.push(
          Routes.sportNew,
          extra: WorkoutPrefill(activity: item.activity, minutes: item.targetMinutes),
        ),
        icon: const Icon(Icons.add_rounded),
      );
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: kPalierMinTarget + 4),
      child: Row(
        children: [
          Icon(
            entry.done ? Icons.check_circle_rounded : activityIcon(item.activity),
            size: 22,
            color: entry.done ? accent : PalierColors.textMid,
          ),
          const SizedBox(width: PalierSpace.md),
          Expanded(
            child: Text(
              planItemLabel(l10n, item, circuits),
              style: manrope(
                size: 15,
                weight: FontWeight.w600,
                color: entry.done ? PalierColors.textMid : PalierColors.textHigh,
              ),
            ),
          ),
          action,
        ],
      ),
    );
  }
}

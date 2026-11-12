import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucid_core_flutter/lucid_core_flutter.dart' show LucidButton, LucidTextField;
import 'package:material_ui/material_ui.dart';

import '../../../app/palier_snack.dart';
import '../../../app/providers.dart';
import '../../../app/theme/palier_theme.dart';
import '../../../app/theme/palier_tokens.dart';
import '../../../core/ui/choice_widgets.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/circuits.dart';
import '../domain/program.dart';
import '../domain/sport.dart';
import 'sport_providers.dart';
import 'sport_visuals.dart';
import 'today_plan.dart';

/// Le programme de la semaine : pour chaque jour, les séances prévues, que
/// l'on ajoute ou retire. Rien n'est proposé d'office.
class ProgramScreen extends ConsumerWidget {
  const ProgramScreen({super.key});

  Future<void> _add(BuildContext context, WidgetRef ref, int weekday) async {
    final draft = await showModalBottomSheet<PlanItemDraft>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _PlanItemSheet(weekday: weekday),
    );
    if (draft == null) return;
    await ref.read(sportRepositoryProvider).addPlanItem(ref.read(activeProfileProvider)!.id, draft);
  }

  Future<void> _remove(BuildContext context, WidgetRef ref, PlanItem item) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final repo = ref.read(sportRepositoryProvider);
    await repo.removePlanItem(item.id);
    PalierSnack.deleted(
      messenger,
      l10n.programRemoved,
      undoLabel: l10n.operationUndo,
      onUndo: () => repo.restorePlanItem(item.id),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final plan = ref.watch(planProvider);
    final circuits = ref.watch(circuitsProvider).value ?? const <Circuit>[];
    final today = ref.watch(clockProvider)().weekday;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.programTitle)),
      body: SafeArea(
        top: false,
        child: !plan.hasValue
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(PalierSpace.page, PalierSpace.sm, PalierSpace.page, PalierSpace.xl),
                children: [
                  Text(
                    l10n.programIntro,
                    style: manrope(size: 14, weight: FontWeight.w500, color: PalierColors.textMid),
                  ),
                  const SizedBox(height: PalierSpace.md),
                  for (var day = DateTime.monday; day <= DateTime.sunday; day++)
                    _DaySection(
                      weekday: day,
                      isToday: day == today,
                      items: [
                        for (final item in plan.requireValue)
                          if (item.weekday == day) item,
                      ],
                      circuits: circuits,
                      onAdd: () => _add(context, ref, day),
                      onRemove: (item) => _remove(context, ref, item),
                    ),
                ],
              ),
      ),
    );
  }
}

class _DaySection extends StatelessWidget {
  const _DaySection({
    required this.weekday,
    required this.isToday,
    required this.items,
    required this.circuits,
    required this.onAdd,
    required this.onRemove,
  });

  final int weekday;
  final bool isToday;
  final List<PlanItem> items;
  final List<Circuit> circuits;
  final VoidCallback onAdd;
  final ValueChanged<PlanItem> onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final accent = Theme.of(context).colorScheme.primary;
    final name = weekdayName(weekday);
    final title = name[0].toUpperCase() + name.substring(1);

    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: PalierColors.line)),
      ),
      padding: const EdgeInsets.symmetric(vertical: PalierSpace.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(title, style: manrope(size: 16, weight: FontWeight.w700)),
              if (isToday) ...[
                const SizedBox(width: PalierSpace.sm),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: PalierSpace.sm, vertical: 2),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(PalierRadius.sm),
                  ),
                  child: Text(
                    l10n.programToday,
                    style: manrope(size: 12, weight: FontWeight.w700, color: accent),
                  ),
                ),
              ],
              const Spacer(),
              IconButton(tooltip: l10n.programAddTo(name), onPressed: onAdd, icon: const Icon(Icons.add_rounded)),
            ],
          ),
          if (items.isEmpty)
            Text(
              l10n.programRest,
              style: manrope(size: 14, weight: FontWeight.w500, color: PalierColors.textLow),
            ),
          for (final item in items)
            Row(
              children: [
                Icon(activityIcon(item.activity), size: 20, color: accent),
                const SizedBox(width: PalierSpace.sm + 4),
                Expanded(
                  child: Text(planItemLabel(l10n, item, circuits), style: manrope(size: 15, weight: FontWeight.w600)),
                ),
                IconButton(
                  tooltip: l10n.programRemove(planItemName(l10n, item, circuits)),
                  onPressed: () => onRemove(item),
                  icon: const Icon(Icons.close_rounded, color: PalierColors.textMid),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Ajouter une séance à un jour : une activité (et sa durée visée) ou un circuit.
class _PlanItemSheet extends ConsumerStatefulWidget {
  const _PlanItemSheet({required this.weekday});

  final int weekday;

  @override
  ConsumerState<_PlanItemSheet> createState() => _PlanItemSheetState();
}

class _PlanItemSheetState extends ConsumerState<_PlanItemSheet> {
  final _formKey = GlobalKey<FormState>();
  final _minutes = TextEditingController();
  WorkoutActivity? _activity;
  String? _circuitId;
  bool _noChoice = false;

  @override
  void dispose() {
    _minutes.dispose();
    super.dispose();
  }

  void _save() {
    if (_activity == null && _circuitId == null) {
      setState(() => _noChoice = true);
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    final minutes = _minutes.text.trim();
    Navigator.of(context).pop(
      _circuitId != null
          ? PlanItemDraft.circuit(weekday: widget.weekday, circuitId: _circuitId!)
          : PlanItemDraft(
              weekday: widget.weekday,
              activity: _activity!,
              targetMinutes: minutes.isEmpty ? null : int.parse(minutes),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final settings = ref.watch(sportSettingsProvider).value ?? SportSettings.initial;
    final circuits = ref.watch(circuitsProvider).value ?? const <Circuit>[];

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(PalierSpace.page, 0, PalierSpace.page, PalierSpace.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.programSheetTitle(weekdayName(widget.weekday)), style: Theme.of(context).textTheme.titleLarge),
              FieldLabel(l10n.programActivityLabel),
              Wrap(
                spacing: PalierSpace.sm,
                runSpacing: PalierSpace.sm,
                children: [
                  for (final activity in settings.orderedActivities)
                    ChoicePill(
                      label: activityName(l10n, activity),
                      icon: activityIcon(activity),
                      selected: _activity == activity && _circuitId == null,
                      onTap: () => setState(() {
                        _activity = activity;
                        _circuitId = null;
                        _noChoice = false;
                      }),
                    ),
                ],
              ),
              if (circuits.isNotEmpty) ...[
                FieldLabel(l10n.programCircuitLabel),
                Wrap(
                  spacing: PalierSpace.sm,
                  runSpacing: PalierSpace.sm,
                  children: [
                    for (final circuit in circuits)
                      ChoicePill(
                        label: circuit.name,
                        icon: Icons.timer_outlined,
                        selected: _circuitId == circuit.id,
                        onTap: () => setState(() {
                          _circuitId = circuit.id;
                          _activity = null;
                          _noChoice = false;
                        }),
                      ),
                  ],
                ),
              ],
              if (_circuitId == null) ...[
                const SizedBox(height: PalierSpace.lg),
                LucidTextField(
                  key: const ValueKey('duree-visee'),
                  controller: _minutes,
                  label: l10n.programMinutesLabel,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    if (text.isEmpty) return null;
                    final minutes = int.tryParse(text);
                    return minutes == null || minutes <= 0 || minutes > PlanItemDraft.maxTargetMinutes
                        ? l10n.programMinutesInvalid
                        : null;
                  },
                ),
              ],
              if (_noChoice)
                Padding(
                  padding: const EdgeInsets.only(top: PalierSpace.sm),
                  child: Text(
                    l10n.programPickOne,
                    style: manrope(size: 13, weight: FontWeight.w600, color: PalierColors.danger),
                  ),
                ),
              const SizedBox(height: PalierSpace.lg),
              LucidButton(label: l10n.programSave, expand: true, onPressed: _save),
            ],
          ),
        ),
      ),
    );
  }
}

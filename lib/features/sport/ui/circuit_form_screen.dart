import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucid_core_flutter/lucid_core_flutter.dart' show LucidButton, LucidTextField;
import 'package:material_ui/material_ui.dart';

import '../../../app/palier_snack.dart';
import '../../../app/providers.dart';
import '../../../app/theme/palier_theme.dart';
import '../../../app/theme/palier_tokens.dart';
import '../../../core/ui/choice_widgets.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/circuits.dart';

/// Ce qu'un exercice demande, en une ligne : « 12 répétitions · repos 30 s ».
String exerciseSummary(AppLocalizations l10n, CircuitExercise exercise) => [
  if (exercise.reps case final reps?) l10n.exerciseReps(reps) else l10n.exerciseSeconds(exercise.seconds!),
  if (exercise.restSeconds > 0) l10n.exerciseRest(exercise.restSeconds) else l10n.exerciseNoRest,
].join(' · ');

/// Composer un circuit ou le modifier : nom, tours, repos entre tours, et ses
/// exercices dans l'ordre, que l'on fait glisser pour les réordonner.
class CircuitFormScreen extends ConsumerStatefulWidget {
  const CircuitFormScreen({super.key, this.circuitId});

  /// `null` pour un nouveau circuit.
  final String? circuitId;

  @override
  ConsumerState<CircuitFormScreen> createState() => _CircuitFormScreenState();
}

class _CircuitFormScreenState extends ConsumerState<CircuitFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _roundRest = TextEditingController(text: '60');
  int _rounds = 3;
  List<CircuitExercise> _exercises = [];
  bool _noExercise = false;
  bool _saving = false;
  bool _loading = false;
  bool _missing = false;

  bool get _editing => widget.circuitId != null;

  @override
  void initState() {
    super.initState();
    if (_editing) {
      _loading = true;
      _load(widget.circuitId!);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _roundRest.dispose();
    super.dispose();
  }

  Future<void> _load(String id) async {
    final circuit = await ref.read(sportRepositoryProvider).findCircuit(id);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (circuit == null) {
        _missing = true;
        return;
      }
      _name.text = circuit.name;
      _rounds = circuit.rounds;
      _roundRest.text = '${circuit.roundRestSeconds}';
      _exercises = [...circuit.exercises];
    });
  }

  Future<void> _editExercise([int? index]) async {
    final result = await showModalBottomSheet<CircuitExercise>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => ExerciseSheet(initial: index == null ? null : _exercises[index]),
    );
    if (result == null || !mounted) return;
    setState(() {
      _noExercise = false;
      if (index == null) {
        _exercises.add(result);
      } else {
        _exercises[index] = result;
      }
    });
  }

  Future<void> _save() async {
    final valid = _formKey.currentState!.validate();
    setState(() => _noExercise = _exercises.isEmpty);
    if (!valid || _exercises.isEmpty) return;
    final draft = CircuitDraft(
      name: _name.text,
      rounds: _rounds,
      roundRestSeconds: int.parse(_roundRest.text.trim()),
      exercises: _exercises,
    );
    if (draft.problem != null) return;
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final repo = ref.read(sportRepositoryProvider);
    setState(() => _saving = true);
    try {
      if (_editing) {
        await repo.updateCircuit(widget.circuitId!, draft);
      } else {
        await repo.createCircuit(ref.read(activeProfileProvider)!.id, draft);
      }
      if (!mounted) return;
      context.pop();
      PalierSnack.done(messenger, l10n.circuitSaved);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final repo = ref.read(sportRepositoryProvider);
    final id = widget.circuitId!;
    await repo.deleteCircuit(id);
    if (!mounted) return;
    context.pop();
    PalierSnack.deleted(
      messenger,
      l10n.circuitDeleted,
      undoLabel: l10n.operationUndo,
      onUndo: () => repo.restoreCircuit(id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
          onPressed: () => context.pop(),
        ),
        title: Text(_editing ? l10n.circuitEditTitle : l10n.circuitNewTitle),
      ),
      body: SafeArea(
        top: false,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _missing
            ? Center(child: Text(l10n.circuitNotFound, style: text.bodyLarge))
            : Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    PalierSpace.page,
                    PalierSpace.md,
                    PalierSpace.page,
                    PalierSpace.xl,
                  ),
                  children: [
                    LucidTextField(
                      key: const ValueKey('nom-circuit'),
                      controller: _name,
                      label: l10n.circuitNameLabel,
                      hint: l10n.circuitNameHint,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.next,
                      inputFormatters: [LengthLimitingTextInputFormatter(CircuitDraft.maxNameLength)],
                      validator: (value) => (value?.trim() ?? '').isEmpty ? l10n.circuitNameRequired : null,
                    ),
                    FieldLabel(l10n.circuitRoundsLabel),
                    _RoundsStepper(value: _rounds, onChanged: (value) => setState(() => _rounds = value)),
                    const SizedBox(height: PalierSpace.lg),
                    LucidTextField(
                      key: const ValueKey('repos-tours'),
                      controller: _roundRest,
                      label: l10n.circuitRoundRestLabel,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(3)],
                      validator: (value) => _restError(value, l10n),
                    ),
                    FieldLabel(l10n.circuitExercisesLabel),
                    if (_exercises.isNotEmpty)
                      ReorderableListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        buildDefaultDragHandles: false,
                        itemCount: _exercises.length,
                        onReorderItem: (from, to) => setState(() => _exercises.insert(to, _exercises.removeAt(from))),
                        itemBuilder: (context, i) => _ExerciseRow(
                          key: ObjectKey(_exercises[i]),
                          index: i,
                          exercise: _exercises[i],
                          onTap: () => _editExercise(i),
                          onRemove: () => setState(() => _exercises.removeAt(i)),
                        ),
                      ),
                    if (_noExercise)
                      Padding(
                        padding: const EdgeInsets.only(bottom: PalierSpace.sm),
                        child: Text(
                          l10n.circuitNoExercise,
                          style: manrope(size: 13, weight: FontWeight.w600, color: PalierColors.danger),
                        ),
                      ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: _exercises.length >= CircuitDraft.maxExercises ? null : () => _editExercise(),
                        icon: const Icon(Icons.add_rounded),
                        label: Text(l10n.circuitAddExercise),
                      ),
                    ),
                    const SizedBox(height: PalierSpace.xl),
                    LucidButton(label: l10n.circuitSave, expand: true, isLoading: _saving, onPressed: _save),
                    if (_editing) ...[
                      const SizedBox(height: PalierSpace.sm),
                      TextButton.icon(
                        style: TextButton.styleFrom(foregroundColor: PalierColors.danger),
                        onPressed: _delete,
                        icon: const Icon(Icons.delete_outline_rounded),
                        label: Text(l10n.circuitDelete),
                      ),
                    ],
                  ],
                ),
              ),
      ),
    );
  }
}

String? _restError(String? value, AppLocalizations l10n) {
  final seconds = int.tryParse(value?.trim() ?? '');
  return seconds == null || seconds < 0 || seconds > CircuitExercise.maxRestSeconds ? l10n.circuitRestInvalid : null;
}

/// « − 3 + » : le nombre de tours, de 1 à 20.
class _RoundsStepper extends StatelessWidget {
  const _RoundsStepper({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        IconButton.outlined(
          tooltip: l10n.circuitRoundsLess,
          onPressed: value > 1 ? () => onChanged(value - 1) : null,
          icon: const Icon(Icons.remove_rounded),
        ),
        SizedBox(
          width: 64,
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall,
            semanticsLabel: l10n.circuitRounds(value),
          ),
        ),
        IconButton.outlined(
          tooltip: l10n.circuitRoundsMore,
          onPressed: value < CircuitDraft.maxRounds ? () => onChanged(value + 1) : null,
          icon: const Icon(Icons.add_rounded),
        ),
      ],
    );
  }
}

/// Un exercice dans la liste : poignée pour le déplacer, nom et ce qu'il demande, retrait.
class _ExerciseRow extends StatelessWidget {
  const _ExerciseRow({
    super.key,
    required this.index,
    required this.exercise,
    required this.onTap,
    required this.onRemove,
  });

  final int index;
  final CircuitExercise exercise;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(PalierRadius.sm),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: PalierSpace.xs),
          child: Row(
            children: [
              ReorderableDragStartListener(
                index: index,
                child: const SizedBox.square(
                  dimension: kPalierMinTarget,
                  child: Icon(Icons.drag_indicator_rounded, color: PalierColors.textLow),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(exercise.name, style: manrope(size: 15, weight: FontWeight.w600)),
                    Text(
                      exerciseSummary(l10n, exercise),
                      style: manrope(size: 13, weight: FontWeight.w500, color: PalierColors.textLow),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: l10n.exerciseRemove(exercise.name),
                onPressed: onRemove,
                icon: const Icon(Icons.close_rounded, color: PalierColors.textMid),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// La fiche d'un exercice, en feuille du bas : nom, répétitions ou durée, repos après.
class ExerciseSheet extends StatefulWidget {
  const ExerciseSheet({super.key, this.initial});

  final CircuitExercise? initial;

  @override
  State<ExerciseSheet> createState() => _ExerciseSheetState();
}

class _ExerciseSheetState extends State<ExerciseSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.initial?.name ?? '');
  late final _value = TextEditingController(
    text: switch (widget.initial) {
      CircuitExercise(:final reps?) => '$reps',
      CircuitExercise(:final seconds?) => '$seconds',
      _ => '',
    },
  );
  late final _rest = TextEditingController(text: '${widget.initial?.restSeconds ?? 30}');
  late bool _timed = widget.initial?.isTimed ?? false;

  @override
  void dispose() {
    _name.dispose();
    _value.dispose();
    _rest.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final value = int.parse(_value.text.trim());
    final rest = int.parse(_rest.text.trim());
    final name = _name.text.trim();
    Navigator.of(context).pop(
      _timed
          ? CircuitExercise(name: name, seconds: value, restSeconds: rest)
          : CircuitExercise(name: name, reps: value, restSeconds: rest),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
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
              Text(
                widget.initial == null ? l10n.exerciseNewTitle : l10n.exerciseEditTitle,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: PalierSpace.md),
              LucidTextField(
                key: const ValueKey('nom-exercice'),
                controller: _name,
                label: l10n.exerciseNameLabel,
                hint: l10n.exerciseNameHint,
                autofocus: widget.initial == null,
                textCapitalization: TextCapitalization.sentences,
                inputFormatters: [LengthLimitingTextInputFormatter(CircuitExercise.maxNameLength)],
                validator: (value) => (value?.trim() ?? '').isEmpty ? l10n.exerciseNameRequired : null,
              ),
              const SizedBox(height: PalierSpace.md),
              PillRow(
                children: [
                  ChoicePill(
                    label: l10n.exerciseModeReps,
                    icon: Icons.repeat_rounded,
                    selected: !_timed,
                    onTap: () => setState(() => _timed = false),
                  ),
                  ChoicePill(
                    label: l10n.exerciseModeTime,
                    icon: Icons.timer_outlined,
                    selected: _timed,
                    onTap: () => setState(() => _timed = true),
                  ),
                ],
              ),
              const SizedBox(height: PalierSpace.md),
              LucidTextField(
                key: const ValueKey('valeur-exercice'),
                controller: _value,
                label: _timed ? l10n.exerciseSecondsLabel : l10n.exerciseRepsLabel,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
                validator: (value) {
                  final number = int.tryParse(value?.trim() ?? '');
                  final max = _timed ? CircuitExercise.maxSeconds : CircuitExercise.maxReps;
                  return number == null || number <= 0 || number > max ? l10n.exerciseValueInvalid : null;
                },
              ),
              const SizedBox(height: PalierSpace.md),
              LucidTextField(
                key: const ValueKey('repos-exercice'),
                controller: _rest,
                label: l10n.exerciseRestLabel,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(3)],
                validator: (value) => _restError(value, l10n),
              ),
              const SizedBox(height: PalierSpace.lg),
              LucidButton(label: l10n.exerciseSave, expand: true, onPressed: _save),
            ],
          ),
        ),
      ),
    );
  }
}

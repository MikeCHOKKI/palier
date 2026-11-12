import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucid_core_flutter/lucid_core_flutter.dart' show LucidButton, LucidTextField;
import 'package:material_ui/material_ui.dart';

import '../../../app/palier_snack.dart';
import '../../../app/providers.dart';
import '../../../app/theme/palier_tokens.dart';
import '../../../core/ui/choice_widgets.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/sport.dart';
import 'sport_providers.dart';
import 'sport_visuals.dart';

/// Noter une séance, ou la modifier : activité, durée, distance pour la marche
/// et la course, ressenti, jour et note.
class WorkoutScreen extends ConsumerStatefulWidget {
  const WorkoutScreen({super.key, this.workoutId, this.prefill});

  /// `null` pour une nouvelle séance.
  final String? workoutId;

  /// Une séance du programme à noter : l'activité et la durée visée, déjà remplies.
  final WorkoutPrefill? prefill;

  @override
  ConsumerState<WorkoutScreen> createState() => _WorkoutScreenState();
}

/// Ce que le programme prévoit pour une séance à noter.
class WorkoutPrefill {
  const WorkoutPrefill({required this.activity, this.minutes});

  final WorkoutActivity activity;
  final int? minutes;
}

class _WorkoutScreenState extends ConsumerState<WorkoutScreen> {
  final _formKey = GlobalKey<FormState>();
  final _minutes = TextEditingController();
  final _distance = TextEditingController();
  final _note = TextEditingController();
  WorkoutActivity? _activity;
  WorkoutEffort? _effort;
  late DateTime _day;
  bool _saving = false;
  bool _loading = false;
  bool _missing = false;

  /// La séance modifiée, gardée telle qu'elle était pour l'heure du jour.
  Workout? _original;

  bool get _editing => widget.workoutId != null;

  DateTime _now() => ref.read(clockProvider)();

  @override
  void initState() {
    super.initState();
    final now = _now();
    _day = DateTime(now.year, now.month, now.day);
    // Comme les autres saisies : un message encore affiché couvrirait le bouton.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ScaffoldMessenger.maybeOf(context)?.removeCurrentSnackBar();
    });
    if (_editing) {
      _loading = true;
      _load(widget.workoutId!);
    } else if (widget.prefill case final prefill?) {
      _activity = prefill.activity;
      if (prefill.minutes case final minutes?) _minutes.text = '$minutes';
    }
  }

  @override
  void dispose() {
    _minutes.dispose();
    _distance.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _load(String id) async {
    final workout = await ref.read(sportRepositoryProvider).findWorkout(id);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (workout == null) {
        _missing = true;
        return;
      }
      _original = workout;
      _activity = workout.activity;
      _effort = workout.effort;
      final at = workout.occurredAt.toLocal();
      _day = DateTime(at.year, at.month, at.day);
      _minutes.text = '${workout.durationMinutes}';
      if (workout.distanceMeters case final meters?) {
        _distance.text = NumberFormat('0.##', 'fr').format(meters / 1000);
      }
      _note.text = workout.note ?? '';
    });
  }

  /// Le moment enregistré : le jour choisi, à l'heure de la saisie (ou de la séance modifiée).
  DateTime _occurredAt() {
    final original = _original?.occurredAt.toLocal();
    if (original != null && DateUtils.isSameDay(original, _day)) return original;
    final now = _now();
    return DateTime(_day.year, _day.month, _day.day, now.hour, now.minute);
  }

  Future<void> _pickDay() async {
    final now = _now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _day.isAfter(now) ? now : _day,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
    );
    if (picked != null && mounted) setState(() => _day = picked);
  }

  Future<void> _save(WorkoutActivity activity) async {
    if (!_formKey.currentState!.validate()) return;
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final distanceText = _distance.text.trim();
    final draft = WorkoutDraft(
      activity: activity,
      occurredAt: _occurredAt(),
      durationSeconds: int.parse(_minutes.text.trim()) * 60,
      distanceMeters: distanceText.isEmpty ? null : parseKilometers(distanceText),
      effort: _effort,
      note: _note.text,
    );
    if (draft.problem != null) return;
    final profileId = ref.read(activeProfileProvider)!.id;
    final repo = ref.read(sportRepositoryProvider);
    setState(() => _saving = true);
    try {
      if (_editing) {
        await repo.updateWorkout(widget.workoutId!, draft);
      } else {
        await repo.createWorkout(profileId, draft);
      }
      if (!mounted) return;
      context.pop();
      PalierSnack.done(messenger, _editing ? l10n.workoutUpdated : l10n.workoutSaved);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Supprimer se rattrape : « Annuler » remet la séance.
  Future<void> _delete() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final repo = ref.read(sportRepositoryProvider);
    final id = widget.workoutId!;
    await repo.deleteWorkout(id);
    if (!mounted) return;
    context.pop();
    PalierSnack.deleted(
      messenger,
      l10n.workoutDeleted,
      undoLabel: l10n.operationUndo,
      onUndo: () => repo.restoreWorkout(id),
    );
  }

  String? _validateMinutes(String? value, AppLocalizations l10n) {
    final minutes = int.tryParse(value?.trim() ?? '');
    if (minutes == null || minutes <= 0 || minutes * 60 > WorkoutDraft.maxDurationSeconds) {
      return l10n.workoutDurationInvalid;
    }
    return null;
  }

  String? _validateDistance(String? value, AppLocalizations l10n) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    final meters = parseKilometers(text);
    if (meters == null || meters <= 0 || meters > WorkoutDraft.maxDistanceMeters) return l10n.workoutDistanceInvalid;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final settings = ref.watch(sportSettingsProvider).value ?? SportSettings.initial;
    final choices = {...settings.orderedActivities, ?_activity}.toList()..sort((a, b) => a.index.compareTo(b.index));
    final activity = _activity ?? choices.first;
    final now = _now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final otherDay = _day != today && _day != yesterday;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
          onPressed: () => context.pop(),
        ),
        title: Text(_editing ? l10n.workoutEditTitle : l10n.workoutNewTitle),
      ),
      body: SafeArea(
        top: false,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _missing
            ? Center(child: Text(l10n.workoutNotFound, style: Theme.of(context).textTheme.bodyLarge))
            : Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    PalierSpace.page,
                    PalierSpace.sm,
                    PalierSpace.page,
                    PalierSpace.xl,
                  ),
                  children: [
                    FieldLabel(l10n.workoutActivityLabel),
                    Wrap(
                      spacing: PalierSpace.sm,
                      runSpacing: PalierSpace.sm,
                      children: [
                        for (final choice in choices)
                          ChoicePill(
                            label: activityName(l10n, choice),
                            icon: activityIcon(choice),
                            selected: choice == activity,
                            onTap: () => setState(() => _activity = choice),
                          ),
                      ],
                    ),
                    const SizedBox(height: PalierSpace.lg),
                    LucidTextField(
                      key: const ValueKey('duree'),
                      controller: _minutes,
                      label: l10n.workoutDurationLabel,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
                      validator: (value) => _validateMinutes(value, l10n),
                    ),
                    if (activity.hasDistance) ...[
                      const SizedBox(height: PalierSpace.md),
                      LucidTextField(
                        key: const ValueKey('distance'),
                        controller: _distance,
                        label: l10n.workoutDistanceLabel,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        textInputAction: TextInputAction.next,
                        helperText: l10n.workoutDistanceHelp,
                        validator: (value) => _validateDistance(value, l10n),
                      ),
                    ],
                    FieldLabel(l10n.workoutEffortLabel),
                    PillRow(
                      children: [
                        for (final effort in WorkoutEffort.values)
                          ChoicePill(
                            label: effortName(l10n, effort),
                            selected: effort == _effort,
                            // Toucher le ressenti choisi le retire : il reste facultatif.
                            onTap: () => setState(() => _effort = effort == _effort ? null : effort),
                          ),
                      ],
                    ),
                    FieldLabel(l10n.workoutDateLabel),
                    PillRow(
                      children: [
                        ChoicePill(
                          label: l10n.expensesToday,
                          selected: _day == today,
                          onTap: () => setState(() => _day = today),
                        ),
                        ChoicePill(
                          label: l10n.expensesYesterday,
                          selected: _day == yesterday,
                          onTap: () => setState(() => _day = yesterday),
                        ),
                        ChoicePill(
                          label: otherDay ? DateFormat.MMMEd('fr').format(_day) : l10n.operationOtherDate,
                          icon: Icons.calendar_today_outlined,
                          selected: otherDay,
                          onTap: _pickDay,
                        ),
                      ],
                    ),
                    const SizedBox(height: PalierSpace.lg),
                    TextField(
                      controller: _note,
                      maxLength: WorkoutDraft.maxNoteLength,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        labelText: l10n.workoutNoteLabel,
                        hintText: l10n.workoutNoteHint,
                        counterText: '',
                      ),
                    ),
                    const SizedBox(height: PalierSpace.xl),
                    LucidButton(
                      label: l10n.workoutSave,
                      expand: true,
                      isLoading: _saving,
                      onPressed: () => _save(activity),
                    ),
                    if (_editing) ...[
                      const SizedBox(height: PalierSpace.sm),
                      TextButton.icon(
                        style: TextButton.styleFrom(foregroundColor: PalierColors.danger),
                        onPressed: _delete,
                        icon: const Icon(Icons.delete_outline_rounded),
                        label: Text(l10n.workoutDelete),
                      ),
                    ],
                  ],
                ),
              ),
      ),
    );
  }
}

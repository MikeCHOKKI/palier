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
import '../domain/sport.dart';
import 'sport_providers.dart';
import 'sport_visuals.dart';

/// Les réglages de sport du profil : activités, jours et objectif de la semaine.
/// Rien n'est imposé ni conseillé : la personne choisit.
class SportSettingsScreen extends ConsumerStatefulWidget {
  const SportSettingsScreen({super.key});

  @override
  ConsumerState<SportSettingsScreen> createState() => _SportSettingsScreenState();
}

class _SportSettingsScreenState extends ConsumerState<SportSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _goal = TextEditingController();
  Set<WorkoutActivity> _activities = {};
  Set<int> _days = {};
  bool _filled = false;
  bool _saving = false;
  bool _noActivity = false;

  @override
  void dispose() {
    _goal.dispose();
    super.dispose();
  }

  /// Reprend les réglages enregistrés une fois, dès qu'ils sont connus.
  void _fill(SportSettings? saved) {
    if (_filled) return;
    _filled = true;
    final settings = saved ?? SportSettings.initial;
    _activities = {...settings.activities};
    _days = {...settings.trainingDays};
    if (settings.weeklyGoalMinutes case final goal?) _goal.text = '$goal';
  }

  Future<void> _save() async {
    final valid = _formKey.currentState!.validate();
    setState(() => _noActivity = _activities.isEmpty);
    if (!valid || _activities.isEmpty) return;
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final goalText = _goal.text.trim();
    final settings = SportSettings(
      activities: _activities,
      trainingDays: _days,
      weeklyGoalMinutes: goalText.isEmpty ? null : int.parse(goalText),
    );
    if (settings.problem != null) return;
    final profileId = ref.read(activeProfileProvider)!.id;
    setState(() => _saving = true);
    try {
      await ref.read(sportRepositoryProvider).saveSettings(profileId, settings);
      if (!mounted) return;
      context.pop();
      PalierSnack.done(messenger, l10n.sportSettingsSaved);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _toggleActivity(WorkoutActivity activity) => setState(() {
    _activities.contains(activity) ? _activities.remove(activity) : _activities.add(activity);
    if (_activities.isNotEmpty) _noActivity = false;
  });

  void _toggleDay(int day) => setState(() => _days.contains(day) ? _days.remove(day) : _days.add(day));

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final settings = ref.watch(sportSettingsProvider);
    if (settings.hasValue) _fill(settings.value);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.sportSettingsTitle)),
      body: SafeArea(
        top: false,
        child: !settings.hasValue
            ? const Center(child: CircularProgressIndicator())
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
                    FieldLabel(l10n.sportSettingsActivities),
                    Wrap(
                      spacing: PalierSpace.sm,
                      runSpacing: PalierSpace.sm,
                      children: [
                        for (final activity in WorkoutActivity.values)
                          ChoicePill(
                            label: activityName(l10n, activity),
                            icon: activityIcon(activity),
                            selected: _activities.contains(activity),
                            onTap: () => _toggleActivity(activity),
                          ),
                      ],
                    ),
                    if (_noActivity)
                      Padding(
                        padding: const EdgeInsets.only(top: PalierSpace.sm),
                        child: Text(
                          l10n.sportSettingsNoActivity,
                          style: manrope(size: 13, weight: FontWeight.w600, color: PalierColors.danger),
                        ),
                      ),
                    FieldLabel(l10n.sportSettingsDays),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        for (var day = DateTime.monday; day <= DateTime.sunday; day++)
                          _DayToggle(day: day, selected: _days.contains(day), onTap: () => _toggleDay(day)),
                      ],
                    ),
                    const SizedBox(height: PalierSpace.sm),
                    Text(
                      l10n.sportSettingsDaysHelp,
                      style: manrope(size: 13, weight: FontWeight.w500, color: PalierColors.textLow),
                    ),
                    const SizedBox(height: PalierSpace.lg),
                    LucidTextField(
                      key: const ValueKey('objectif'),
                      controller: _goal,
                      label: l10n.sportSettingsGoalLabel,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      helperText: l10n.sportSettingsGoalHelp,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(5)],
                      validator: (value) {
                        final text = value?.trim() ?? '';
                        if (text.isEmpty) return null;
                        final minutes = int.tryParse(text);
                        return minutes == null || minutes <= 0 || minutes > SportSettings.maxWeeklyGoalMinutes
                            ? l10n.sportSettingsGoalInvalid
                            : null;
                      },
                    ),
                    const SizedBox(height: PalierSpace.xl),
                    LucidButton(label: l10n.sportSettingsSave, expand: true, isLoading: _saving, onPressed: _save),
                  ],
                ),
              ),
      ),
    );
  }
}

/// Un jour de la semaine à cocher : son initiale dans un rond.
class _DayToggle extends StatelessWidget {
  const _DayToggle({required this.day, required this.selected, required this.onTap});

  final int day;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Semantics(
      container: true,
      label: weekdayName(day),
      selected: selected,
      button: true,
      excludeSemantics: true,
      child: Material(
        color: selected ? accent.withValues(alpha: 0.16) : Colors.transparent,
        shape: CircleBorder(
          side: BorderSide(color: selected ? accent : PalierColors.line, width: selected ? 2 : 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox.square(
            dimension: kPalierMinTarget - 4,
            child: Center(
              child: Text(
                weekdayInitial(day),
                style: manrope(
                  size: 15,
                  weight: FontWeight.w700,
                  color: selected ? PalierColors.textHigh : PalierColors.textMid,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

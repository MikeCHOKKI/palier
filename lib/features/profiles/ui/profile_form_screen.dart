import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucid_core_flutter/lucid_core_flutter.dart';

import '../../../app/providers.dart';
import '../../../app/routes.dart';
import '../../../app/theme/palier_accent.dart';
import '../../../app/theme/palier_theme.dart';
import '../../../app/theme/palier_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../expenses/ui/expenses_providers.dart';
import '../domain/profile.dart';

/// D'où l'on vient, et donc où l'on va après l'enregistrement.
enum ProfileFormMode {
  /// Tout premier profil : il s'ouvre aussitôt.
  first,

  /// Ajouté depuis l'écran « Qui es-tu ? » : retour à cet écran.
  fromPicker,

  /// Ajouté depuis les réglages d'un autre membre : retour aux réglages.
  fromSettings,

  /// Modification du profil ouvert.
  edit,
}

class ProfileFormScreen extends ConsumerStatefulWidget {
  const ProfileFormScreen({super.key, required this.mode});

  final ProfileFormMode mode;

  @override
  ConsumerState<ProfileFormScreen> createState() => _ProfileFormScreenState();
}

class _ProfileFormScreenState extends ConsumerState<ProfileFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  ProfileDraft _draft = const ProfileDraft(name: '');
  bool _saving = false;

  bool get _editing => widget.mode == ProfileFormMode.edit;

  @override
  void initState() {
    super.initState();
    final profile = _editing ? ref.read(activeProfileProvider) : null;
    if (profile != null) {
      _draft = ProfileDraft.of(profile);
      _name.text = profile.name;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final l10n = AppLocalizations.of(context);
    final repo = ref.read(profilesRepositoryProvider);
    final draft = _draft.copyWith(name: _name.text);
    setState(() => _saving = true);

    try {
      switch (widget.mode) {
        case ProfileFormMode.first:
          final created = await repo.create(draft);
          ref.read(sessionProvider.notifier).open(created.id);
        case ProfileFormMode.fromPicker:
          await repo.create(draft);
          if (mounted) context.go(Routes.picker);
        case ProfileFormMode.fromSettings:
          await repo.create(draft);
          if (mounted) context.go(Routes.settings);
        case ProfileFormMode.edit:
          await repo.update(ref.read(activeProfileProvider)!.id, draft);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.profileSaved)));
            context.go(Routes.settings);
          }
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final l10n = AppLocalizations.of(context);
    final profile = ref.read(activeProfileProvider)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.profileDeleteTitle(profile.name)),
        content: Text(l10n.profileDeleteBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancel)),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: PalierColors.danger),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    ref.read(sessionProvider.notifier).signOut();
    await ref.read(profilesRepositoryProvider).delete(profile.id);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final title = _editing ? l10n.profileEditTitle : l10n.profileNewTitle;
    // Les montants sont enregistrés dans la devise du profil : la changer après
    // coup ferait lire 12 500 F CFA comme 125,00 €.
    final profileId = _editing ? ref.watch(activeProfileIdProvider) : null;
    final currencyLocked = profileId != null && (ref.watch(hasOperationsProvider(profileId)).value ?? true);

    // Le formulaire prend la couleur choisie : on voit tout de suite le rendu.
    return Theme(
      data: palierTheme(_draft.accent),
      child: Scaffold(
        appBar: AppBar(title: Text(title)),
        body: SafeArea(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(PalierSpace.page, PalierSpace.sm, PalierSpace.page, PalierSpace.xl),
              children: [
                LucidTextField(
                  controller: _name,
                  label: l10n.profileNameLabel,
                  textCapitalization: TextCapitalization.words,
                  autofocus: !_editing,
                  textInputAction: TextInputAction.done,
                  inputFormatters: [LengthLimitingTextInputFormatter(ProfileDraft.maxNameLength)],
                  validator: (value) {
                    final name = value?.trim() ?? '';
                    if (name.isEmpty) return l10n.profileNameRequired;
                    if (name.length > ProfileDraft.maxNameLength) {
                      return l10n.profileNameTooLong(ProfileDraft.maxNameLength);
                    }
                    return null;
                  },
                ),
                _SectionTitle(l10n.profileAccentLabel),
                _AccentPicker(
                  selected: _draft.accent,
                  onChanged: (a) => setState(() => _draft = _draft.copyWith(accent: a)),
                ),
                _SectionTitle(l10n.profileCurrencyLabel),
                SegmentedButton<PalierCurrency>(
                  showSelectedIcon: false,
                  segments: [
                    for (final currency in PalierCurrency.values)
                      ButtonSegment(value: currency, label: Text(currency.symbol)),
                  ],
                  selected: {_draft.currency},
                  onSelectionChanged: currencyLocked
                      ? null
                      : (s) => setState(() => _draft = _draft.copyWith(currency: s.single)),
                ),
                if (currencyLocked)
                  Padding(
                    padding: const EdgeInsets.only(top: PalierSpace.sm),
                    child: Text(l10n.profileCurrencyLocked, style: Theme.of(context).textTheme.bodySmall),
                  ),
                _SectionTitle(l10n.profileModulesLabel),
                LucidCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      SwitchListTile(
                        secondary: const Icon(Icons.account_balance_wallet_outlined),
                        title: Text(l10n.moduleExpenses),
                        subtitle: Text(l10n.moduleExpensesHint),
                        value: _draft.expensesEnabled,
                        onChanged: (v) => setState(() => _draft = _draft.copyWith(expensesEnabled: v)),
                      ),
                      const Divider(indent: 56),
                      SwitchListTile(
                        secondary: const Icon(Icons.directions_run_rounded),
                        title: Text(l10n.moduleSport),
                        subtitle: Text(l10n.moduleSportHint),
                        value: _draft.sportEnabled,
                        onChanged: (v) => setState(() => _draft = _draft.copyWith(sportEnabled: v)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: PalierSpace.md),
                LucidCard(
                  padding: EdgeInsets.zero,
                  child: SwitchListTile(
                    secondary: const Icon(Icons.child_care_rounded),
                    title: Text(l10n.profileMinorLabel),
                    subtitle: Text(l10n.profileMinorHint),
                    isThreeLine: true,
                    value: _draft.isMinor,
                    onChanged: (v) => setState(() => _draft = _draft.copyWith(isMinor: v)),
                  ),
                ),
                const SizedBox(height: PalierSpace.xl),
                LucidButton(
                  label: _editing ? l10n.profileSave : l10n.profileCreate,
                  expand: true,
                  isLoading: _saving,
                  onPressed: _saving ? null : _save,
                ),
                if (_editing) ...[
                  const SizedBox(height: PalierSpace.lg),
                  Center(
                    child: TextButton.icon(
                      style: TextButton.styleFrom(foregroundColor: PalierColors.danger),
                      onPressed: _delete,
                      icon: const Icon(Icons.delete_outline_rounded),
                      label: Text(l10n.profileDelete),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: PalierSpace.lg, bottom: PalierSpace.sm + 2),
      child: Text(label, style: Theme.of(context).textTheme.titleSmall),
    );
  }
}

/// Les couleurs d'accent, en pastilles.
class _AccentPicker extends StatelessWidget {
  const _AccentPicker({required this.selected, required this.onChanged});

  final PalierAccent selected;
  final ValueChanged<PalierAccent> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Wrap(
      spacing: PalierSpace.sm + 4,
      runSpacing: PalierSpace.sm + 4,
      children: [
        for (final accent in PalierAccent.values)
          Semantics(
            label: l10n.accentName(accent.name),
            selected: accent == selected,
            button: true,
            excludeSemantics: true,
            child: InkResponse(
              onTap: () => onChanged(accent),
              radius: 30,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                width: 48,
                height: 48,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: accent == selected ? accent.color : Colors.transparent, width: 2),
                ),
                child: DecoratedBox(
                  decoration: BoxDecoration(color: accent.color, shape: BoxShape.circle),
                  child: accent == selected
                      ? const Icon(Icons.check_rounded, size: 20, color: PalierAccent.onAccent)
                      : null,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

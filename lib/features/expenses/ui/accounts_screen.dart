import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
// Ses push/pop sur BuildContext masqueraient ceux de go_router.
import 'package:lucid_core_flutter/lucid_core_flutter.dart' hide LucidNavigationExtensions;

import '../../../app/palier_snack.dart';
import '../../../app/providers.dart';
import '../../../app/routes.dart';
import '../../../app/theme/palier_theme.dart';
import '../../../app/theme/palier_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../profiles/domain/profile.dart';
import '../data/expenses_repository.dart';
import '../domain/expense_kinds.dart';
import '../domain/expenses.dart';
import '../domain/money.dart';
import 'expense_visuals.dart';
import 'expense_widgets.dart';
import 'expenses_providers.dart';

/// Les comptes du profil et leur solde.
class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final currency = ref.watch(activeProfileProvider)?.currency;
    final accounts = ref.watch(accountsProvider).value;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.accountsTitle)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(Routes.expensesAccountNew),
        icon: const Icon(Icons.add_rounded),
        label: Text(l10n.accountsAdd),
      ),
      body: accounts == null || currency == null
          ? const Center(child: CircularProgressIndicator())
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(PalierSpace.page, PalierSpace.sm, PalierSpace.page, 96),
              itemCount: accounts.length,
              separatorBuilder: (_, _) => const Divider(indent: 56),
              itemBuilder: (context, i) {
                final account = accounts[i];
                return ListTile(
                  key: ValueKey(account.id),
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(accountIcon(account.kind)),
                  title: Text(account.name),
                  subtitle: account.goal == null
                      ? Text(l10n.accountKindName(account.kind))
                      : SavingsGoal(account: account, currency: currency),
                  trailing: LucidPrivateText(
                    formatBalance(account.balance, currency),
                    mask: maskedMoney(currency),
                    style: manrope(
                      size: 15,
                      weight: FontWeight.w700,
                      color: balanceColor(context, account.balance),
                    ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
                  ),
                  onTap: () => context.push(Routes.expensesAccount(account.id)),
                );
              },
            ),
    );
  }
}

/// Créer ou modifier un compte : nom, type et solde de départ.
class AccountFormScreen extends ConsumerStatefulWidget {
  const AccountFormScreen({super.key, this.accountId, this.returnsSelection = false});

  /// `null` pour un nouveau compte.
  final String? accountId;

  /// Ouvert depuis la saisie d'une opération : l'écran rend l'identifiant du
  /// compte créé, que la saisie sélectionne. Pas de message alors : il
  /// couvrirait le bouton d'enregistrement, et la sélection suffit à confirmer.
  final bool returnsSelection;

  /// Valeur de `extra` pour ouvrir le formulaire en mode [returnsSelection].
  static const pickExtra = 'choisir';

  @override
  ConsumerState<AccountFormScreen> createState() => _AccountFormScreenState();
}

class _AccountFormScreenState extends ConsumerState<AccountFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _opening = TextEditingController();
  final _goal = TextEditingController();
  AccountKind _kind = AccountKind.mobileMoney;
  bool _saving = false;
  bool _filled = false;

  bool get _editing => widget.accountId != null;

  @override
  void dispose() {
    _name.dispose();
    _opening.dispose();
    _goal.dispose();
    super.dispose();
  }

  /// Remplit le formulaire une fois, dès que le compte à modifier est connu.
  void _fill(Account account) {
    if (_filled) return;
    _filled = true;
    final currency = ref.read(activeProfileProvider)!.currency;
    _name.text = account.name;
    _kind = account.kind;
    _opening.text = account.openingBalance == 0 ? '' : formatMoney(account.openingBalance, currency, withSymbol: false);
    final goal = account.goal;
    _goal.text = goal == null ? '' : formatMoney(goal, currency, withSymbol: false);
  }

  Future<void> _save(Account? existing) async {
    if (!_formKey.currentState!.validate()) return;
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final profile = ref.read(activeProfileProvider)!;
    final draft = AccountDraft(
      name: _name.text,
      kind: _kind,
      openingBalance: parseMoney(_opening.text, profile.currency)!,
      // Champ vide : la conversion donne 0, soit « pas d'objectif ».
      goal: switch (parseMoney(_goal.text, profile.currency)) {
        final amount? when amount > 0 => amount,
        _ => null,
      },
    );
    final repo = ref.read(expensesRepositoryProvider);

    setState(() => _saving = true);
    try {
      final String id;
      if (existing == null) {
        id = (await repo.createAccount(profile.id, draft)).id;
      } else {
        id = existing.id;
        await repo.updateAccount(id, draft);
      }
      if (!mounted) return;
      context.pop(id);
      if (!widget.returnsSelection) PalierSnack.done(messenger, l10n.accountSaved);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete(Account account) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.accountDeleteTitle(account.name)),
        content: Text(l10n.accountDeleteBody),
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
    if (confirmed != true || !mounted) return;
    try {
      await ref.read(expensesRepositoryProvider).deleteAccount(account.id);
      if (!mounted) return;
      context.pop();
      PalierSnack.deleted(messenger, l10n.accountDeleted);
    } on AccountInUseException {
      PalierSnack.problem(messenger, l10n.accountInUse);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final currency = ref.watch(activeProfileProvider)?.currency;
    final accounts = ref.watch(accountsProvider).value;
    Account? existing;
    if (_editing && accounts != null) {
      for (final account in accounts) {
        if (account.id == widget.accountId) existing = account;
      }
      if (existing != null) _fill(existing);
    }
    final ready = currency != null && (!_editing || existing != null);

    return Scaffold(
      appBar: AppBar(title: Text(_editing ? l10n.accountEditTitle : l10n.accountNewTitle)),
      body: !ready
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    PalierSpace.page,
                    PalierSpace.sm,
                    PalierSpace.page,
                    PalierSpace.xl,
                  ),
                  children: [
                    LucidTextField(
                      controller: _name,
                      label: l10n.accountNameLabel,
                      hint: l10n.accountNameHint,
                      textCapitalization: TextCapitalization.sentences,
                      autofocus: !_editing,
                      textInputAction: TextInputAction.next,
                      inputFormatters: [LengthLimitingTextInputFormatter(AccountDraft.maxNameLength)],
                      validator: (value) => (value?.trim() ?? '').isEmpty ? l10n.accountNameRequired : null,
                    ),
                    FieldLabel(l10n.accountKindLabel),
                    // Sur deux lignes plutôt qu'en rangée qui défile : les quatre
                    // types restent visibles, « Épargne » compris.
                    Wrap(
                      spacing: PalierSpace.sm,
                      runSpacing: PalierSpace.sm,
                      children: [
                        for (final kind in AccountKind.values)
                          ChoicePill(
                            label: l10n.accountKindName(kind),
                            icon: accountIcon(kind),
                            selected: _kind == kind,
                            onTap: () => setState(() => _kind = kind),
                          ),
                      ],
                    ),
                    const SizedBox(height: PalierSpace.lg),
                    LucidTextField(
                      controller: _opening,
                      label: '${l10n.accountOpeningLabel} (${currency.symbol})',
                      keyboardType: TextInputType.numberWithOptions(decimal: currency.decimals > 0),
                      textInputAction: TextInputAction.done,
                      helperText: l10n.accountOpeningHelp,
                      validator: (value) =>
                          parseMoney(value ?? '', currency) == null ? l10n.accountOpeningInvalid : null,
                    ),
                    if (_kind == AccountKind.savings) ...[
                      const SizedBox(height: PalierSpace.md),
                      LucidTextField(
                        key: const ValueKey('objectif'),
                        controller: _goal,
                        label: '${l10n.accountGoalLabel} (${currency.symbol})',
                        keyboardType: TextInputType.numberWithOptions(decimal: currency.decimals > 0),
                        textInputAction: TextInputAction.done,
                        helperText: l10n.accountGoalHelp,
                        validator: (value) {
                          final text = value?.trim() ?? '';
                          if (text.isEmpty) return null;
                          final amount = parseMoney(text, currency);
                          return amount == null || amount <= 0 ? l10n.accountGoalInvalid : null;
                        },
                      ),
                    ],
                    const SizedBox(height: PalierSpace.xl),
                    LucidButton(
                      label: l10n.accountSave,
                      expand: true,
                      isLoading: _saving,
                      onPressed: () => _save(existing),
                    ),
                    if (existing != null) ...[
                      const SizedBox(height: PalierSpace.sm),
                      TextButton.icon(
                        style: TextButton.styleFrom(foregroundColor: PalierColors.danger),
                        onPressed: () => _delete(existing!),
                        icon: const Icon(Icons.delete_outline_rounded),
                        label: Text(l10n.accountDelete),
                      ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }
}

/// Sous le nom d'un compte d'épargne : où en est son objectif, en pourcentage
/// et en jauge. Vert, puisque s'approcher du but est une bonne nouvelle : pas
/// d'ambre ni de rouge comme pour un plafond, et le dépasser reste du vert.
class SavingsGoal extends StatelessWidget {
  const SavingsGoal({super.key, required this.account, required this.currency});

  final Account account;
  final PalierCurrency currency;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final goal = account.goal!;
    final saved = account.balance < 0 ? 0 : account.balance;
    final reached = saved >= goal;
    final percent = (account.goalProgress! * 100).floor();
    final style = manrope(
      size: 13,
      weight: FontWeight.w500,
      color: reached ? PalierColors.success : PalierColors.textLow,
    );
    final kind = l10n.accountKindName(account.kind);

    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LucidPrivateText(
            '$kind · ${reached ? l10n.accountGoalReached(formatMoney(goal, currency)) : l10n.accountGoalProgress(percent, formatMoney(goal, currency))}',
            mask:
                '$kind · ${reached ? l10n.accountGoalReached(maskedMoney(currency)) : l10n.accountGoalProgress(percent, maskedMoney(currency))}',
            style: style,
          ),
          const SizedBox(height: PalierSpace.xs + 2),
          LucidMeter(
            value: saved,
            max: goal,
            color: PalierColors.success,
            warningColor: PalierColors.success,
            overColor: PalierColors.success,
            trackColor: PalierColors.indigo,
            height: 4,
            semanticLabel: l10n.accountGoalLabel,
            semanticValue: l10n.accountGoalProgress(percent, formatMoney(goal, currency)),
          ),
        ],
      ),
    );
  }
}

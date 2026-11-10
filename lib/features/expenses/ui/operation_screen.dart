import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/providers.dart';
import '../../../app/routes.dart';
import '../../../app/theme/palier_accent.dart';
import '../../../app/theme/palier_theme.dart';
import '../../../app/theme/palier_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/expense_kinds.dart';
import '../domain/expenses.dart';
import '../domain/money.dart';
import 'accounts_screen.dart';
import 'amount_pad.dart';
import 'expense_visuals.dart';
import 'expense_widgets.dart';
import 'expenses_providers.dart';

/// Noter une opération en trois gestes (montant, catégorie, compte), ou la modifier.
///
/// Le pavé et le bouton restent en bas, sous le pouce ; le reste défile au-dessus.
class OperationScreen extends ConsumerStatefulWidget {
  const OperationScreen({super.key, this.operationId});

  /// `null` pour une nouvelle opération.
  final String? operationId;

  @override
  ConsumerState<OperationScreen> createState() => _OperationScreenState();
}

class _OperationScreenState extends ConsumerState<OperationScreen> {
  final _note = TextEditingController();
  OperationKind _kind = OperationKind.expense;
  late AmountEntry _amount;
  String? _accountId;
  String? _toAccountId;
  String? _categoryId;
  late DateTime _occurredAt;
  OperationProblem? _problem;
  bool _saving = false;

  /// Vrai tant qu'une opération à modifier n'est pas chargée.
  bool _loading = false;
  bool _missing = false;

  bool get _editing => widget.operationId != null;

  @override
  void initState() {
    super.initState();
    final currency = ref.read(activeProfileProvider)!.currency;
    _amount = AmountEntry.empty(currency);
    _occurredAt = DateTime.now();
    if (_editing) {
      _loading = true;
      _load(widget.operationId!);
    }
  }

  Future<void> _load(String id) async {
    final entry = await ref.read(expensesRepositoryProvider).findOperation(id);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (entry == null) {
        _missing = true;
        return;
      }
      _kind = entry.kind;
      _amount = AmountEntry.fromMinor(entry.amount, _amount.currency);
      _accountId = entry.accountId;
      _toAccountId = entry.toAccountId;
      _categoryId = entry.categoryId;
      _occurredAt = entry.occurredAt.toLocal();
      _note.text = entry.note ?? '';
    });
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  OperationDraft get _draft => OperationDraft(
    kind: _kind,
    amount: _amount.minor,
    accountId: _accountId,
    toAccountId: _toAccountId,
    categoryId: _categoryId,
    note: _note.text,
    occurredAt: _occurredAt,
  );

  void _update(VoidCallback change) => setState(() {
    change();
    _problem = null;
  });

  void _setKind(OperationKind kind) => _update(() {
    _kind = kind;
    // Une catégorie de dépense n'a pas de sens pour un revenu.
    _categoryId = null;
  });

  /// Choix par défaut, une fois les comptes connus : le premier compte, et pour
  /// un virement, le premier autre compte.
  void _fillDefaults(List<Account> accounts) {
    if (accounts.isEmpty) return;
    final ids = accounts.map((a) => a.id).toSet();
    if (_accountId == null || !ids.contains(_accountId)) _accountId = accounts.first.id;
    if (_toAccountId != null && !ids.contains(_toAccountId)) _toAccountId = null;
    if (_kind == OperationKind.transfer && _toAccountId == null) {
      for (final account in accounts) {
        if (account.id != _accountId) {
          _toAccountId = account.id;
          break;
        }
      }
    }
  }

  Future<void> _save() async {
    final draft = _draft;
    final problem = draft.problem;
    if (problem != null) {
      setState(() => _problem = problem);
      return;
    }
    final profileId = ref.read(activeProfileIdProvider);
    if (profileId == null) return;

    setState(() => _saving = true);
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final repo = ref.read(expensesRepositoryProvider);
    try {
      if (_editing) {
        await repo.updateOperation(widget.operationId!, draft);
      } else {
        await repo.addOperation(profileId, draft);
      }
      if (!mounted) return;
      context.pop();
      messenger.showSnackBar(SnackBar(content: Text(l10n.operationSaved(_kind.name))));
    } on Object {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(SnackBar(content: Text(l10n.errorGeneric)));
    }
  }

  Future<void> _delete() async {
    final id = widget.operationId!;
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final repo = ref.read(expensesRepositoryProvider);
    await repo.deleteOperation(id);
    if (!mounted) return;
    context.pop();
    // Pas de boîte de confirmation : la suppression s'annule d'un geste.
    messenger.showSnackBar(
      SnackBar(
        content: Text(l10n.operationDeleted),
        action: SnackBarAction(label: l10n.operationUndo, onPressed: () => repo.restoreOperation(id)),
        // Avec un bouton, Flutter garde le message à l'écran jusqu'à ce qu'on le
        // touche ; six secondes suffisent pour se raviser.
        persist: false,
        duration: const Duration(seconds: 6),
      ),
    );
  }

  /// Crée le compte qui manque à un virement, et le choisit comme destination.
  Future<void> _addTargetAccount() async {
    final id = await context.push<String>(Routes.expensesAccountNew, extra: AccountFormScreen.pickExtra);
    if (id != null && mounted) _update(() => _toAccountId = id);
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _occurredAt.isAfter(now) ? now : _occurredAt,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
    );
    if (picked == null || !mounted) return;
    // On garde l'heure de la saisie : l'ordre dans la journée reste naturel.
    _update(() => _occurredAt = DateTime(picked.year, picked.month, picked.day, now.hour, now.minute));
  }

  void _setDay(DateTime day) {
    final now = DateTime.now();
    _update(() => _occurredAt = DateTime(day.year, day.month, day.day, now.hour, now.minute));
  }

  String _problemText(AppLocalizations l10n, OperationProblem problem) => switch (problem) {
    OperationProblem.noAmount => l10n.operationProblemAmount,
    OperationProblem.noAccount => l10n.operationProblemAccount,
    OperationProblem.noCategory => l10n.operationProblemCategory,
    OperationProblem.noTargetAccount => l10n.operationProblemTarget,
    OperationProblem.sameAccount => l10n.operationProblemSameAccount,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final accounts = ref.watch(accountsProvider).value;
    final categories = _kind.categoryKind == null
        ? const <Category>[]
        : ref.watch(categoriesProvider(_kind.categoryKind)).value ?? const <Category>[];
    if (accounts != null) _fillDefaults(accounts);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
          onPressed: () => context.pop(),
        ),
        title: Text(_editing ? l10n.operationEditTitle : l10n.operationNewTitle),
        actions: [
          if (_editing && !_loading && !_missing)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded),
              tooltip: l10n.operationDelete,
              onPressed: _delete,
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: _loading || accounts == null
            ? const Center(child: CircularProgressIndicator())
            : _missing
            ? Center(child: Text(l10n.operationNotFound, style: Theme.of(context).textTheme.bodyLarge))
            : Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(
                        PalierSpace.page,
                        PalierSpace.sm,
                        PalierSpace.page,
                        PalierSpace.md,
                      ),
                      children: [
                        SegmentedButton<OperationKind>(
                          showSelectedIcon: false,
                          segments: [
                            for (final kind in OperationKind.values)
                              ButtonSegment(
                                value: kind,
                                // « Entre comptes » passe sur deux lignes : centrées, comme les autres choix.
                                label: Text(l10n.operationKindName(kind), textAlign: TextAlign.center),
                              ),
                          ],
                          selected: {_kind},
                          onSelectionChanged: (s) => _setKind(s.single),
                        ),
                        _AmountDisplay(amount: _amount, kind: _kind),
                        ..._details(l10n, accounts, categories),
                      ],
                    ),
                  ),
                  _BottomPanel(
                    amount: _amount,
                    onAmountChanged: (value) => _update(() => _amount = value),
                    problem: _problem == null ? null : _problemText(l10n, _problem!),
                    saveLabel: l10n.operationSave(_kind.name),
                    saving: _saving,
                    onSave: _save,
                  ),
                ],
              ),
      ),
    );
  }

  List<Widget> _details(AppLocalizations l10n, List<Account> accounts, List<Category> categories) {
    final dateFormat = DateFormat.MMMEd('fr');
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final day = DateTime(_occurredAt.year, _occurredAt.month, _occurredAt.day);
    final otherDay = day != today && day != yesterday;

    Widget accountPills(String? selected, ValueChanged<String> onSelect) => PillRow(
      children: [
        for (final account in accounts)
          ChoicePill(
            label: account.name,
            icon: accountIcon(account.kind),
            selected: account.id == selected,
            onTap: () => onSelect(account.id),
          ),
      ],
    );

    return [
      if (_kind == OperationKind.transfer) ...[
        if (accounts.length < 2)
          _TransferNeedsTwoAccounts(onAdd: _addTargetAccount)
        else ...[
          FieldLabel(l10n.operationFromLabel),
          accountPills(_accountId, (id) => _update(() => _accountId = id)),
          FieldLabel(l10n.operationToLabel),
          accountPills(_toAccountId, (id) => _update(() => _toAccountId = id)),
        ],
      ] else ...[
        FieldLabel(l10n.operationCategoryLabel),
        _CategoryStrip(
          categories: categories,
          selectedId: _categoryId,
          onSelect: (id) => _update(() => _categoryId = id),
          onManage: () => context.push(Routes.expensesCategories),
          manageLabel: l10n.expensesManageCategories,
        ),
        FieldLabel(l10n.operationAccountLabel),
        accountPills(_accountId, (id) => _update(() => _accountId = id)),
      ],
      FieldLabel(l10n.operationDateLabel),
      PillRow(
        children: [
          ChoicePill(label: l10n.expensesToday, selected: day == today, onTap: () => _setDay(today)),
          ChoicePill(label: l10n.expensesYesterday, selected: day == yesterday, onTap: () => _setDay(yesterday)),
          ChoicePill(
            label: otherDay ? dateFormat.format(day) : l10n.operationOtherDate,
            icon: Icons.calendar_today_outlined,
            selected: otherDay,
            onTap: _pickDate,
          ),
        ],
      ),
      const SizedBox(height: PalierSpace.lg),
      TextField(
        controller: _note,
        maxLength: OperationDraft.maxNoteLength,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(
          labelText: l10n.operationNoteLabel,
          hintText: l10n.operationNoteHint,
          counterText: '',
        ),
      ),
    ];
  }
}

/// Le montant en grand, au centre : c'est lui que l'on vérifie d'un coup d'œil.
class _AmountDisplay extends StatelessWidget {
  const _AmountDisplay({required this.amount, required this.kind});

  final AmountEntry amount;
  final OperationKind kind;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final color = amount.isZero
        ? PalierColors.textLow
        : (kind == OperationKind.income ? PalierColors.success : PalierColors.textHigh);
    return Semantics(
      liveRegion: true,
      label: l10n.amountLabel(formatMoney(amount.minor, amount.currency)),
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: PalierSpace.md),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  amount.display,
                  style: TextStyle(
                    fontFamily: PalierFonts.display,
                    fontSize: 44,
                    fontWeight: FontWeight.w600,
                    height: 1.1,
                    color: color,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(width: PalierSpace.sm),
                Text(
                  amount.currency.symbol,
                  style: manrope(size: 18, weight: FontWeight.w600, color: PalierColors.textMid),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Les catégories en une bande qui défile : une pastille ronde et son nom.
class _CategoryStrip extends StatelessWidget {
  const _CategoryStrip({
    required this.categories,
    required this.selectedId,
    required this.onSelect,
    required this.onManage,
    required this.manageLabel,
  });

  final List<Category> categories;
  final String? selectedId;
  final ValueChanged<String> onSelect;
  final VoidCallback onManage;
  final String manageLabel;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 92,
      child: ListView(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        children: [
          for (final category in categories)
            _CategoryChoice(
              label: category.name,
              icon: categoryIcon(category.icon),
              selected: category.id == selectedId,
              onTap: () => onSelect(category.id),
            ),
          _CategoryChoice(label: manageLabel, icon: Icons.tune_rounded, selected: false, quiet: true, onTap: onManage),
        ],
      ),
    );
  }
}

class _CategoryChoice extends StatelessWidget {
  const _CategoryChoice({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.quiet = false,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final bool quiet;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Semantics(
      selected: selected,
      button: true,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(PalierRadius.sm),
        child: SizedBox(
          width: 76,
          child: Column(
            children: [
              const SizedBox(height: PalierSpace.xs),
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                curve: Curves.easeOutCubic,
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? accent : (quiet ? Colors.transparent : PalierColors.surface),
                  border: Border.all(color: selected ? accent : PalierColors.line),
                ),
                child: Icon(icon, size: 22, color: selected ? PalierAccent.onAccent : PalierColors.textMid),
              ),
              const SizedBox(height: PalierSpace.xs + 2),
              Text(
                label,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: manrope(
                  size: 12,
                  height: 1.2,
                  weight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? PalierColors.textHigh : PalierColors.textMid,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TransferNeedsTwoAccounts extends StatelessWidget {
  const _TransferNeedsTwoAccounts({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: PalierSpace.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.operationTransferNeedsTwo, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: PalierSpace.sm),
          OutlinedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded),
            label: Text(l10n.operationAddAccount),
          ),
        ],
      ),
    );
  }
}

/// Pavé, message éventuel et bouton d'enregistrement, posés sur le fond le plus profond.
class _BottomPanel extends StatelessWidget {
  const _BottomPanel({
    required this.amount,
    required this.onAmountChanged,
    required this.problem,
    required this.saveLabel,
    required this.saving,
    required this.onSave,
  });

  final AmountEntry amount;
  final ValueChanged<AmountEntry> onAmountChanged;
  final String? problem;
  final String saveLabel;
  final bool saving;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: PalierColors.deep,
        border: Border(top: BorderSide(color: PalierColors.line)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(PalierSpace.page, PalierSpace.sm + 4, PalierSpace.page, PalierSpace.sm + 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AmountPad(value: amount, onChanged: onAmountChanged),
            if (problem != null)
              Padding(
                padding: const EdgeInsets.only(bottom: PalierSpace.sm),
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    problem!,
                    style: manrope(size: 14, weight: FontWeight.w600, color: PalierColors.danger),
                  ),
                ),
              ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: saving ? null : onSave,
                child: saving
                    ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(saveLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

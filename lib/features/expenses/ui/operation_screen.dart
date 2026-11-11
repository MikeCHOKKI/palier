import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/palier_snack.dart';
import '../../../app/providers.dart';
import '../../../app/routes.dart';
import '../../../app/theme/palier_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/budgets.dart';
import '../domain/expense_kinds.dart';
import '../domain/expenses.dart';
import '../domain/money.dart';
import 'accounts_screen.dart';
import 'amount_pad.dart';
import 'expense_visuals.dart';
import 'expense_widgets.dart';
import 'expenses_providers.dart';
import 'operation_fields.dart';

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

  DateTime _now() => ref.read(clockProvider)();

  @override
  void initState() {
    super.initState();
    final currency = ref.read(activeProfileProvider)!.currency;
    _amount = AmountEntry.empty(currency);
    _occurredAt = _now();
    // Un message encore affiché (« Dépense enregistrée. ») se poserait sur le
    // bouton d'enregistrement de cet écran : on ouvre la saisie sans lui.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ScaffoldMessenger.maybeOf(context)?.removeCurrentSnackBar();
    });
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
      final budget = await _budgetOf(profileId, draft);
      final (from, to) = MonthView.bounds(draft.occurredAt);
      final before = budget == null ? 0 : await repo.spentIn(profileId, budget.categoryId, from: from, to: to);
      if (_editing) {
        await repo.updateOperation(widget.operationId!, draft);
      } else {
        await repo.addOperation(profileId, draft);
      }
      final after = budget == null ? 0 : await repo.spentIn(profileId, budget.categoryId, from: from, to: to);
      if (!mounted) return;
      context.pop();
      final alert = budget == null ? null : budgetAlert(before: before, after: after, limit: budget.amount);
      switch (alert) {
        case null:
          PalierSnack.done(messenger, l10n.operationSaved(_kind.name));
        case BudgetAlert.nearing:
          PalierSnack.warn(
            messenger,
            l10n.budgetAlertNearing(budget!.categoryName, (after * 100 / budget.amount).floor()),
          );
        case BudgetAlert.reached:
          PalierSnack.warn(
            messenger,
            after > budget!.amount
                ? l10n.budgetAlertOver(budget.categoryName)
                : l10n.budgetAlertReached(budget.categoryName),
          );
      }
    } on Object {
      if (!mounted) return;
      setState(() => _saving = false);
      PalierSnack.problem(messenger, l10n.errorGeneric);
    }
  }

  /// Le plafond de la catégorie d'une dépense, s'il y en a un.
  Future<Budget?> _budgetOf(String profileId, OperationDraft draft) async {
    if (draft.kind != OperationKind.expense) return null;
    final budgets = await ref.read(expensesRepositoryProvider).watchBudgets(profileId).first;
    for (final budget in budgets) {
      if (budget.categoryId == draft.categoryId) return budget;
    }
    return null;
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
    PalierSnack.deleted(
      messenger,
      l10n.operationDeleted,
      undoLabel: l10n.operationUndo,
      onUndo: () => repo.restoreOperation(id),
    );
  }

  /// Crée le compte qui manque à un virement, et le choisit comme destination.
  Future<void> _addTargetAccount() async {
    final id = await context.push<String>(Routes.expensesAccountNew, extra: AccountFormScreen.pickExtra);
    if (id != null && mounted) _update(() => _toAccountId = id);
  }

  Future<void> _pickDate() async {
    final now = _now();
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
    final now = _now();
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
                        AmountDisplay(
                          amount: _amount,
                          color: _kind == OperationKind.income ? PalierColors.success : null,
                        ),
                        ..._details(l10n, accounts, categories),
                      ],
                    ),
                  ),
                  AmountPanel(
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
    final now = _now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final day = DateTime(_occurredAt.year, _occurredAt.month, _occurredAt.day);
    final otherDay = day != today && day != yesterday;

    return [
      OperationFields(
        kind: _kind,
        accounts: accounts,
        categories: categories,
        accountId: _accountId,
        toAccountId: _toAccountId,
        categoryId: _categoryId,
        onAccount: (id) => _update(() => _accountId = id),
        onToAccount: (id) => _update(() => _toAccountId = id),
        onCategory: (id) => _update(() => _categoryId = id),
        onAddTargetAccount: _addTargetAccount,
      ),
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

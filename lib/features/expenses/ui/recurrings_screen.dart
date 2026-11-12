import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
// Ses push/pop sur BuildContext masqueraient ceux de go_router.
import 'package:lucid_core_flutter/lucid_core_flutter.dart' hide LucidNavigationExtensions;
import 'package:material_ui/material_ui.dart';

import '../../../app/palier_snack.dart';
import '../../../app/providers.dart';
import '../../../app/routes.dart';
import '../../../app/theme/palier_theme.dart';
import '../../../app/theme/palier_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../profiles/domain/profile.dart';
import '../domain/expense_kinds.dart';
import '../domain/expenses.dart';
import '../domain/money.dart';
import '../domain/recurring.dart';
import 'accounts_screen.dart';
import 'amount_pad.dart';
import 'expense_visuals.dart';
import 'expense_widgets.dart';
import 'expenses_providers.dart';
import 'operation_fields.dart';

/// Un montant avec son sens : « −45 000 F » pour une dépense, « +150 000 F »
/// pour un revenu, sans signe pour un virement.
String signedMoney(OperationKind kind, int amount, PalierCurrency currency) => switch (kind) {
  OperationKind.expense => formatMoney(-amount, currency, signed: true),
  OperationKind.income => formatMoney(amount, currency, signed: true),
  OperationKind.transfer => formatMoney(amount, currency),
};

Color _amountColor(OperationKind kind) => switch (kind) {
  OperationKind.income => PalierColors.success,
  OperationKind.expense => PalierColors.textHigh,
  OperationKind.transfer => PalierColors.textMid,
};

const _figures = [FontFeature.tabularFigures()];

// ------------------------------------------------------------------- liste

/// Ce qui revient, la prochaine échéance d'abord.
class RecurringsScreen extends ConsumerWidget {
  const RecurringsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final currency = ref.watch(activeProfileProvider)?.currency;
    final recurrings = ref.watch(recurringsProvider);
    // Tenue chargée : toucher une pièce de tontine ouvre sa tontine.
    ref.watch(tontinesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.recurringsTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: l10n.recurringsAdd,
            onPressed: () => context.push(Routes.expensesRecurringNew),
          ),
        ],
      ),
      body: switch (recurrings) {
        AsyncValue(error: final Object _) => LucidErrorState(message: l10n.errorGeneric),
        AsyncValue(value: final List<Recurring> list) when currency != null =>
          list.isEmpty ? const _EmptyRecurrings() : _RecurringsList(recurrings: list, currency: currency),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _RecurringsList extends ConsumerWidget {
  const _RecurringsList({required this.recurrings, required this.currency});

  final List<Recurring> recurrings;
  final PalierCurrency currency;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(clockProvider)();
    final today = DateTime(now.year, now.month, now.day);
    final next = {for (final r in recurrings) r.id: r.nextFrom(today)};
    final sorted = [...recurrings]
      ..sort((a, b) {
        final (x, y) = (next[a.id], next[b.id]);
        if (x == null || y == null) return x == null ? (y == null ? 0 : 1) : -1;
        return x.compareTo(y);
      });

    return SafeArea(
      top: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(PalierSpace.page, PalierSpace.sm, PalierSpace.page, PalierSpace.xl),
        children: [
          for (final r in sorted)
            _RecurringRow(
              recurring: r,
              next: next[r.id],
              currency: currency,
              // Une échéance de tontine se change avec sa tontine, jamais seule.
              onTap: () => context.push(switch (ref.read(tontineOwningProvider(r.id))) {
                final tontineId? => Routes.expensesTontine(tontineId),
                null => Routes.expensesRecurring(r.id),
              }),
            ),
        ],
      ),
    );
  }
}

class _RecurringRow extends StatelessWidget {
  const _RecurringRow({required this.recurring, required this.next, required this.currency, required this.onTap});

  final Recurring recurring;
  final DateTime? next;
  final PalierCurrency currency;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final where = recurring.kind == OperationKind.transfer
        ? l10n.expensesTransferRoute(recurring.accountName, recurring.toAccountName ?? '?')
        : recurring.accountName;
    final day = next;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(PalierRadius.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: PalierSpace.sm + 4),
        child: Row(
          children: [
            OperationBadge(kind: recurring.kind, icon: recurring.categoryIcon),
            const SizedBox(width: PalierSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recurring.title(l10n.expensesTransfer),
                    style: text.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    LucidRecurrenceText.summary(context, recurring.rule),
                    style: text.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(where, style: text.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const SizedBox(width: PalierSpace.md),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                LucidPrivateText(
                  signedMoney(recurring.kind, recurring.amount, currency),
                  mask: maskedMoney(currency),
                  style: manrope(
                    size: 15,
                    weight: FontWeight.w700,
                    color: _amountColor(recurring.kind),
                  ).copyWith(fontFeatures: _figures),
                ),
                const SizedBox(height: 2),
                Text(
                  day == null ? l10n.recurringsEnded : l10n.recurringsNext(DateFormat.MMMd('fr').format(day)),
                  style: text.bodySmall,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyRecurrings extends StatelessWidget {
  const _EmptyRecurrings();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(PalierSpace.page, PalierSpace.lg, PalierSpace.page, PalierSpace.xl),
      children: [
        Text(l10n.recurringsEmptyTitle, style: text.titleLarge),
        const SizedBox(height: PalierSpace.sm),
        Text(l10n.recurringsEmptyBody, style: text.bodyMedium?.copyWith(color: PalierColors.textMid)),
        const SizedBox(height: PalierSpace.lg),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: () => context.push(Routes.expensesRecurringNew),
            icon: const Icon(Icons.add_rounded),
            label: Text(l10n.recurringsAdd),
          ),
        ),
      ],
    );
  }
}

// --------------------------------------------------------------- formulaire

/// Créer ou modifier une récurrence : comme « Noter », sans date, avec sa règle.
class RecurringFormScreen extends ConsumerStatefulWidget {
  const RecurringFormScreen({super.key, this.recurringId});

  /// `null` pour une nouvelle récurrence.
  final String? recurringId;

  @override
  ConsumerState<RecurringFormScreen> createState() => _RecurringFormScreenState();
}

class _RecurringFormScreenState extends ConsumerState<RecurringFormScreen> {
  final _note = TextEditingController();
  OperationKind _kind = OperationKind.expense;
  late AmountEntry _amount;
  String? _accountId;
  String? _toAccountId;
  String? _categoryId;
  late LucidRecurrence _rule;
  OperationProblem? _problem;
  bool _saving = false;
  bool _loading = false;
  bool _missing = false;

  bool get _editing => widget.recurringId != null;

  DateTime get _today {
    final now = ref.read(clockProvider)();
    return DateTime(now.year, now.month, now.day);
  }

  @override
  void initState() {
    super.initState();
    _amount = AmountEntry.empty(ref.read(activeProfileProvider)!.currency);
    _rule = LucidRecurrence(unit: LucidRecurrenceUnit.month, start: _today);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ScaffoldMessenger.maybeOf(context)?.removeCurrentSnackBar();
    });
    if (_editing) {
      _loading = true;
      _load(widget.recurringId!);
    }
  }

  Future<void> _load(String id) async {
    final recurring = await ref.read(expensesRepositoryProvider).findRecurring(id);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (recurring == null) {
        _missing = true;
        return;
      }
      _kind = recurring.kind;
      _amount = AmountEntry.fromMinor(recurring.amount, _amount.currency);
      _accountId = recurring.accountId;
      _toAccountId = recurring.toAccountId;
      _categoryId = recurring.categoryId;
      _note.text = recurring.note ?? '';
      _rule = recurring.rule;
    });
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  RecurringDraft get _draft => RecurringDraft(
    kind: _kind,
    amount: _amount.minor,
    accountId: _accountId,
    toAccountId: _toAccountId,
    categoryId: _categoryId,
    note: _note.text,
    rule: _rule,
  );

  void _update(VoidCallback change) => setState(() {
    change();
    _problem = null;
  });

  void _fillDefaults(List<Account> accounts) {
    if (accounts.isEmpty) return;
    final ids = accounts.map((a) => a.id).toSet();
    if (_accountId == null || !ids.contains(_accountId)) _accountId = accounts.first.id;
    if (_toAccountId != null && !ids.contains(_toAccountId)) _toAccountId = null;
    if (_kind == OperationKind.transfer && _toAccountId == null) {
      _toAccountId = accounts.where((a) => a.id != _accountId).firstOrNull?.id;
    }
  }

  Future<void> _addTargetAccount() async {
    final id = await context.push<String>(Routes.expensesAccountNew, extra: AccountFormScreen.pickExtra);
    if (id != null && mounted) _update(() => _toAccountId = id);
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
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final repo = ref.read(expensesRepositoryProvider);
    setState(() => _saving = true);
    try {
      if (_editing) {
        await repo.updateRecurring(widget.recurringId!, draft);
      } else {
        await repo.createRecurring(profileId, draft);
      }
      if (!mounted) return;
      context.pop();
      PalierSnack.done(messenger, l10n.recurringSaved);
    } on Object {
      if (!mounted) return;
      setState(() => _saving = false);
      PalierSnack.problem(messenger, l10n.errorGeneric);
    }
  }

  /// Pas de confirmation : « Annuler » la fait revenir, échéances comprises.
  Future<void> _delete() async {
    final id = widget.recurringId!;
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final repo = ref.read(expensesRepositoryProvider);
    await repo.deleteRecurring(id);
    if (!mounted) return;
    context.pop();
    PalierSnack.deleted(
      messenger,
      l10n.recurringDeleted,
      undoLabel: l10n.operationUndo,
      onUndo: () => repo.restoreRecurring(id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final accounts = ref.watch(accountsProvider).value;
    final categories = _kind.categoryKind == null
        ? const <Category>[]
        : ref.watch(categoriesProvider(_kind.categoryKind)).value ?? const <Category>[];
    if (accounts != null) _fillDefaults(accounts);
    final today = _today;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
          onPressed: () => context.pop(),
        ),
        title: Text(_editing ? l10n.recurringFormEditTitle : l10n.recurringFormNewTitle),
        actions: [
          if (_editing && !_loading && !_missing)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded),
              tooltip: l10n.recurringFormDelete,
              onPressed: _delete,
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: _loading || accounts == null
            ? const Center(child: CircularProgressIndicator())
            : _missing
            ? Center(child: Text(l10n.recurringFormNotFound, style: Theme.of(context).textTheme.bodyLarge))
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
                                label: Text(l10n.operationKindName(kind), textAlign: TextAlign.center),
                              ),
                          ],
                          selected: {_kind},
                          onSelectionChanged: (s) => _update(() {
                            _kind = s.single;
                            _categoryId = null;
                          }),
                        ),
                        AmountDisplay(
                          amount: _amount,
                          color: _kind == OperationKind.income ? PalierColors.success : null,
                        ),
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
                        FieldLabel(l10n.recurringFormRepeatLabel),
                        LucidRecurrenceField(
                          value: _rule,
                          onChanged: (rule) => _update(() => _rule = rule),
                          choiceBuilder: palierChoice,
                          // Une nouvelle récurrence part au plus tôt ce mois-ci :
                          // des échéances d'il y a un an seraient toutes à valider.
                          firstDate: _editing ? null : DateTime(today.year, today.month),
                        ),
                        const SizedBox(height: PalierSpace.lg),
                        TextField(
                          controller: _note,
                          maxLength: OperationDraft.maxNoteLength,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: InputDecoration(
                            labelText: l10n.operationNoteLabel,
                            hintText: l10n.recurringFormNoteHint,
                            counterText: '',
                          ),
                        ),
                      ],
                    ),
                  ),
                  AmountPanel(
                    amount: _amount,
                    onAmountChanged: (value) => _update(() => _amount = value),
                    problem: _problem == null ? null : operationProblemText(l10n, _problem!),
                    saveLabel: l10n.recurringFormSave,
                    saving: _saving,
                    onSave: _save,
                  ),
                ],
              ),
      ),
    );
  }
}

// ----------------------------------------------------------------- échéances

/// Régler une échéance d'un geste : l'opération prend le montant prévu, datée
/// du jour de l'échéance. « Annuler » la retire et l'échéance revient.
Future<void> payDue(BuildContext context, WidgetRef ref, Due due) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final profileId = ref.read(activeProfileIdProvider);
  if (profileId == null) return;
  final repo = ref.read(expensesRepositoryProvider);
  final now = ref.read(clockProvider)();
  final at = DateTime(due.day.year, due.day.month, due.day.day, now.hour, now.minute);
  final id = await repo.addOperation(profileId, due.recurring.draftFor(at), due: due);
  PalierSnack.done(messenger, l10n.dueSettled, undoLabel: l10n.operationUndo, onUndo: () => repo.deleteOperation(id));
}

/// Passer une échéance sans rien enregistrer ; « Annuler » la fait revenir.
Future<void> skipDue(BuildContext context, WidgetRef ref, Due due) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final profileId = ref.read(activeProfileIdProvider);
  if (profileId == null) return;
  final repo = ref.read(expensesRepositoryProvider);
  await repo.skipDue(profileId, due);
  PalierSnack.done(messenger, l10n.dueSkipped, undoLabel: l10n.operationUndo, onUndo: () => repo.unskipDue(due));
}

/// Les échéances arrivées, en tête de l'onglet Dépenses. Trois au plus,
/// les autres à la demande. Rien quand tout est à jour.
class DuesBlock extends ConsumerStatefulWidget {
  const DuesBlock({super.key, required this.currency});

  final PalierCurrency currency;

  static const int folded = 3;

  @override
  ConsumerState<DuesBlock> createState() => _DuesBlockState();
}

class _DuesBlockState extends ConsumerState<DuesBlock> {
  bool _unfolded = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final dues = ref.watch(duesProvider);
    if (dues.isEmpty) return const SizedBox.shrink();
    final now = ref.watch(clockProvider)();
    final today = DateTime(now.year, now.month, now.day);
    final shown = _unfolded ? dues : dues.take(DuesBlock.folded).toList();
    final hidden = dues.length - shown.length;
    final accent = Theme.of(context).colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.only(bottom: PalierSpace.lg),
      child: Material(
        color: PalierColors.surface,
        borderRadius: BorderRadius.circular(PalierRadius.md),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(PalierSpace.md, PalierSpace.sm + 4, PalierSpace.md, PalierSpace.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                child: Row(
                  children: [
                    Text(l10n.duesTitle, style: Theme.of(context).textTheme.labelMedium),
                    const SizedBox(width: PalierSpace.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(PalierRadius.sm),
                      ),
                      child: Text(
                        '${dues.length}',
                        style: manrope(size: 12, weight: FontWeight.w700, color: accent),
                      ),
                    ),
                  ],
                ),
              ),
              for (final due in shown) ...[
                _DueRow(
                  due: due,
                  today: today,
                  currency: widget.currency,
                  onOpen: () => context.push(Routes.expensesDue(due.recurring.id, dayKey(due.day))),
                  onPay: () => payDue(context, ref, due),
                  onSkip: () => skipDue(context, ref, due),
                ),
              ],
              if (dues.length > DuesBlock.folded)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    style: TextButton.styleFrom(padding: EdgeInsets.zero),
                    onPressed: () => setState(() => _unfolded = !_unfolded),
                    child: Text(_unfolded ? l10n.duesFewer : l10n.duesMore(hidden)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Une échéance sur une seule ligne : de quoi la reconnaître (nom, date,
/// montant) et la traiter sans ouvrir d'écran.
class _DueRow extends StatelessWidget {
  const _DueRow({
    required this.due,
    required this.today,
    required this.currency,
    required this.onOpen,
    required this.onPay,
    required this.onSkip,
  });

  final Due due;
  final DateTime today;
  final PalierCurrency currency;
  final VoidCallback onOpen;
  final VoidCallback onPay;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final r = due.recurring;
    final title = r.title(l10n.expensesTransfer);
    final date = DateFormat.MMMd('fr').format(due.day);
    final when = due.day == today ? l10n.expensesToday : date;
    final late = due.day.isBefore(today);
    final small = text.bodySmall!;

    return Padding(
      padding: const EdgeInsets.only(top: PalierSpace.xs),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: onOpen,
              borderRadius: BorderRadius.circular(PalierRadius.sm),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: PalierSpace.xs + 2),
                child: Row(
                  children: [
                    OperationBadge(kind: r.kind, icon: r.categoryIcon, size: 32),
                    const SizedBox(width: PalierSpace.sm + 4),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: text.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Text(when, style: small.copyWith(color: late ? PalierColors.warning : null)),
                              Text(' · ', style: small),
                              Flexible(
                                child: LucidPrivateText(
                                  signedMoney(r.kind, r.amount, currency),
                                  mask: maskedMoney(currency),
                                  style: small.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: _amountColor(r.kind),
                                    fontFeatures: _figures,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Semantics(
            button: true,
            label: l10n.dueSkipFor(title, date),
            excludeSemantics: true,
            child: IconButton(
              // Neutre : l'accent du profil (ambre, corail…) se confondrait avec un retard.
              color: PalierColors.textMid,
              tooltip: l10n.dueSkip,
              icon: const Icon(Icons.skip_next_rounded),
              onPressed: onSkip,
            ),
          ),
          Semantics(
            button: true,
            label: l10n.duePayFor(r.kind.name, title, date),
            excludeSemantics: true,
            child: FilledButton.tonal(
              style: FilledButton.styleFrom(
                minimumSize: const Size(56, kPalierMinTarget),
                padding: const EdgeInsets.symmetric(horizontal: PalierSpace.md),
              ),
              onPressed: onPay,
              child: Text(l10n.duePay(r.kind.name)),
            ),
          ),
        ],
      ),
    );
  }
}

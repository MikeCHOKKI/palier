import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
// Ses push/pop sur BuildContext masqueraient ceux de go_router.
import 'package:lucid_core_flutter/lucid_core_flutter.dart' hide LucidNavigationExtensions;

import '../../../app/palier_snack.dart';
import '../../../app/providers.dart';
import '../../../app/routes.dart';
import '../../../app/theme/palier_theme.dart';
import '../../../app/theme/palier_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../profiles/domain/profile.dart';
import '../domain/expense_kinds.dart';
import '../domain/expenses.dart';
import '../domain/loans.dart';
import '../domain/money.dart';
import '../domain/recurring.dart';
import 'expense_visuals.dart';
import 'expense_widgets.dart';
import 'expenses_providers.dart';

const _figures = [FontFeature.tabularFigures()];

String _dayText(DateTime day) => DateFormat.yMMMd('fr').format(day);

LoanNotes loanNotes(AppLocalizations l10n) =>
    (lent: l10n.loanNoteLent, borrowed: l10n.loanNoteBorrowed, repayment: l10n.loanNoteRepayment);

String loanProblemText(AppLocalizations l10n, LoanProblem problem) => switch (problem) {
  LoanProblem.noName => l10n.loanNoName,
  LoanProblem.noAmount => l10n.loanNoAmount,
  LoanProblem.noAccount => l10n.loanNoAccount,
  LoanProblem.tooMuch => l10n.loanTooMuch,
};

/// Les comptes d'où l'argent part ou où il arrive : pas une tontine ni un prêt.
List<Account> _payable(List<Account> accounts) => [
  for (final a in accounts)
    if (a.kind != AccountKind.tontine && a.kind != AccountKind.loan) a,
];

/// Ce que l'on doit se lit en ambre, ce qu'on nous doit en clair ; un prêt
/// soldé s'efface.
Color _remainingColor(Loan loan) => loan.settled
    ? PalierColors.textLow
    : (loan.direction == LoanDirection.borrowed ? PalierColors.warning : PalierColors.textHigh);

/// Combien est remboursé, en jauge verte : se rapprocher du bout est une bonne nouvelle.
class _RepaidMeter extends StatelessWidget {
  const _RepaidMeter({required this.loan, required this.currency, this.height = 4});

  final Loan loan;
  final PalierCurrency currency;
  final double height;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return LucidMeter(
      value: loan.repaid,
      max: loan.amount,
      color: PalierColors.success,
      warningColor: PalierColors.success,
      overColor: PalierColors.success,
      trackColor: PalierColors.indigo,
      height: height,
      semanticLabel: loan.name,
      semanticValue: l10n.loansRepaid(formatMoney(loan.repaid, currency), formatMoney(loan.amount, currency)),
    );
  }
}

// ------------------------------------------------------------------- liste

/// Les prêts : en cours d'abord, puis les soldés.
class LoansScreen extends ConsumerWidget {
  const LoansScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final currency = ref.watch(activeProfileProvider)?.currency;
    final loans = ref.watch(loansProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.loansTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: l10n.loansAdd,
            onPressed: () => context.push(Routes.expensesLoanNew),
          ),
        ],
      ),
      body: switch (loans) {
        AsyncValue(error: final Object _) => LucidErrorState(message: l10n.errorGeneric),
        AsyncValue(value: final List<Loan> list) when currency != null =>
          list.isEmpty
              ? const _EmptyLoans()
              : ListView(
                  padding: const EdgeInsets.fromLTRB(
                    PalierSpace.page,
                    PalierSpace.sm,
                    PalierSpace.page,
                    PalierSpace.xl,
                  ),
                  children: [
                    for (final loan in [...list.where((l) => !l.settled), ...list.where((l) => l.settled)])
                      _LoanRow(loan: loan, currency: currency),
                  ],
                ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _LoanRow extends StatelessWidget {
  const _LoanRow({required this.loan, required this.currency});

  final Loan loan;
  final PalierCurrency currency;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final who = loan.settled
        ? l10n.loansSettled
        : (loan.direction == LoanDirection.lent ? l10n.loansOwedToYou : l10n.loansYouOwe);

    return InkWell(
      key: ValueKey(loan.id),
      onTap: () => context.push(Routes.expensesLoan(loan.id)),
      borderRadius: BorderRadius.circular(PalierRadius.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: PalierSpace.sm + 4),
        child: Row(
          children: [
            Icon(accountIcon(AccountKind.loan), color: PalierColors.textMid),
            const SizedBox(width: PalierSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(loan.name, style: text.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                      const SizedBox(width: PalierSpace.sm),
                      LucidPrivateText(
                        formatMoney(loan.remaining, currency),
                        mask: maskedMoney(currency),
                        style: manrope(
                          size: 15,
                          weight: FontWeight.w700,
                          color: _remainingColor(loan),
                        ).copyWith(fontFeatures: _figures),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    l10n.loansSince(who, DateFormat.MMMd('fr').format(loan.startedOn)),
                    style: text.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (!loan.settled) ...[
                    const SizedBox(height: PalierSpace.xs + 2),
                    _RepaidMeter(loan: loan, currency: currency),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyLoans extends StatelessWidget {
  const _EmptyLoans();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(PalierSpace.page, PalierSpace.lg, PalierSpace.page, PalierSpace.xl),
      children: [
        Text(l10n.loansEmptyTitle, style: text.titleLarge),
        const SizedBox(height: PalierSpace.sm),
        Text(l10n.loansEmptyBody, style: text.bodyMedium?.copyWith(color: PalierColors.textMid)),
        const SizedBox(height: PalierSpace.lg),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: () => context.push(Routes.expensesLoanNew),
            icon: const Icon(Icons.add_rounded),
            label: Text(l10n.loansAdd),
          ),
        ),
      ],
    );
  }
}

// ----------------------------------------------------------- nouveau prêt

/// Noter un prêt : le sens, la personne, le montant, le compte et le jour.
class LoanFormScreen extends ConsumerStatefulWidget {
  const LoanFormScreen({super.key});

  @override
  ConsumerState<LoanFormScreen> createState() => _LoanFormScreenState();
}

class _LoanFormScreenState extends ConsumerState<LoanFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _amount = TextEditingController();
  LoanDirection _direction = LoanDirection.lent;
  String? _accountId;
  late DateTime _day;
  bool _beforePalier = false;
  bool _saving = false;

  DateTime get _today => localDay(ref.read(clockProvider)());

  @override
  void initState() {
    super.initState();
    _day = _today;
  }

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _pickDay() async {
    final today = _today;
    final picked = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: DateTime(today.year - 5),
      lastDate: today,
    );
    if (picked != null && mounted) setState(() => _day = picked);
  }

  Future<void> _save(PalierCurrency currency) async {
    if (!_formKey.currentState!.validate()) return;
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final draft = LoanDraft(
      name: _name.text,
      direction: _direction,
      amount: parseMoney(_amount.text, currency) ?? 0,
      accountId: _accountId,
      day: _day,
      beforePalier: _beforePalier,
    );
    final problem = draft.problem;
    if (problem != null) {
      PalierSnack.problem(messenger, loanProblemText(l10n, problem));
      return;
    }
    final profileId = ref.read(activeProfileIdProvider);
    if (profileId == null) return;
    setState(() => _saving = true);
    try {
      await ref.read(expensesRepositoryProvider).createLoan(profileId, draft, notes: loanNotes(l10n));
      if (!mounted) return;
      context.pop();
      PalierSnack.done(messenger, l10n.loanSaved);
    } on Object {
      if (!mounted) return;
      setState(() => _saving = false);
      PalierSnack.problem(messenger, l10n.errorGeneric);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final currency = ref.watch(activeProfileProvider)?.currency;
    final accounts = ref.watch(accountsProvider).value;
    final payable = _payable(accounts ?? const []);
    if (_accountId == null && payable.isNotEmpty) _accountId = payable.first.id;
    final lent = _direction == LoanDirection.lent;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.loanNewTitle)),
      body: currency == null || accounts == null
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
                    SegmentedButton<LoanDirection>(
                      showSelectedIcon: false,
                      segments: [
                        ButtonSegment(value: LoanDirection.lent, label: Text(l10n.loanLent)),
                        ButtonSegment(value: LoanDirection.borrowed, label: Text(l10n.loanBorrowed)),
                      ],
                      selected: {_direction},
                      onSelectionChanged: (s) => setState(() => _direction = s.single),
                    ),
                    const SizedBox(height: PalierSpace.lg),
                    LucidTextField(
                      controller: _name,
                      label: lent ? l10n.loanNameLentLabel : l10n.loanNameBorrowedLabel,
                      textCapitalization: TextCapitalization.words,
                      autofocus: true,
                      textInputAction: TextInputAction.next,
                      inputFormatters: [LengthLimitingTextInputFormatter(LoanDraft.maxNameLength)],
                      validator: (v) => (v?.trim() ?? '').isEmpty ? l10n.loanNoName : null,
                    ),
                    const SizedBox(height: PalierSpace.md),
                    LucidTextField(
                      key: const ValueKey('montant'),
                      controller: _amount,
                      label: '${l10n.loanAmountLabel} (${currency.symbol})',
                      keyboardType: TextInputType.numberWithOptions(decimal: currency.decimals > 0),
                      textInputAction: TextInputAction.done,
                      validator: (v) {
                        final amount = parseMoney(v ?? '', currency);
                        return amount == null || amount <= 0 ? l10n.loanNoAmount : null;
                      },
                    ),
                    FieldLabel(lent ? l10n.loanAccountLentLabel : l10n.loanAccountBorrowedLabel),
                    Wrap(
                      spacing: PalierSpace.sm,
                      runSpacing: PalierSpace.sm,
                      children: [
                        for (final a in payable)
                          ChoicePill(
                            label: a.name,
                            icon: accountIcon(a.kind),
                            selected: _accountId == a.id,
                            onTap: () => setState(() => _accountId = a.id),
                          ),
                      ],
                    ),
                    const SizedBox(height: PalierSpace.md),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: _pickDay,
                        icon: const Icon(Icons.event_outlined),
                        label: Text(l10n.loanDayLabel(_dayText(_day))),
                      ),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _beforePalier,
                      onChanged: (v) => setState(() => _beforePalier = v),
                      title: Text(l10n.loanBeforePalier),
                      subtitle: Text(l10n.loanBeforePalierHelp),
                    ),
                    const SizedBox(height: PalierSpace.lg),
                    LucidButton(
                      label: l10n.loanSave,
                      expand: true,
                      isLoading: _saving,
                      onPressed: () => _save(currency),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

// --------------------------------------------------------------- un prêt

/// Un prêt : ce qui reste, ce qui est remboursé, et de quoi noter un
/// remboursement sans quitter l'écran.
class LoanScreen extends ConsumerStatefulWidget {
  const LoanScreen({super.key, required this.loanId});

  final String loanId;

  @override
  ConsumerState<LoanScreen> createState() => _LoanScreenState();
}

class _LoanScreenState extends ConsumerState<LoanScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  String? _accountId;
  bool _saving = false;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _repay(Loan loan, PalierCurrency currency) async {
    if (!_formKey.currentState!.validate()) return;
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final profileId = ref.read(activeProfileIdProvider);
    if (profileId == null) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(expensesRepositoryProvider)
          .repayLoan(
            profileId,
            loan,
            amount: parseMoney(_amount.text, currency) ?? 0,
            accountId: _accountId,
            day: localDay(ref.read(clockProvider)()),
            notes: loanNotes(l10n),
          );
      if (!mounted) return;
      _amount.clear();
      FocusScope.of(context).unfocus();
      PalierSnack.done(messenger, l10n.loanRepaid);
    } on Object {
      PalierSnack.problem(messenger, l10n.errorGeneric);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _rename(Loan loan) async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) => _RenameDialog(name: loan.name),
    );
    if (name == null || name.trim().isEmpty || !mounted) return;
    await ref.read(expensesRepositoryProvider).renameLoan(loan.id, name);
  }

  Future<void> _delete(Loan loan) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.loanDeleteTitle(loan.name)),
        content: Text(l10n.loanDeleteBody),
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
    await ref.read(expensesRepositoryProvider).deleteLoan(loan.id);
    if (!mounted) return;
    context.pop();
    PalierSnack.deleted(messenger, l10n.loanDeleted);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final currency = ref.watch(activeProfileProvider)?.currency;
    final loans = ref.watch(loansProvider).value;
    final accounts = ref.watch(accountsProvider).value;
    final loan = loans?.where((l) => l.id == widget.loanId).firstOrNull;
    final payable = _payable(accounts ?? const []);
    if (loan != null && _accountId == null) {
      _accountId = payable.any((a) => a.id == loan.payAccountId) ? loan.payAccountId : payable.firstOrNull?.id;
    }

    if (currency == null || loans == null || accounts == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (loan == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(l10n.loanNotFound, style: text.bodyLarge)),
      );
    }
    final lent = loan.direction == LoanDirection.lent;
    final who = loan.settled ? l10n.loansSettled : (lent ? l10n.loansOwedToYou : l10n.loansYouOwe);

    return Scaffold(
      appBar: AppBar(
        title: Text(loan.name),
        actions: [
          IconButton(icon: const Icon(Icons.edit_outlined), tooltip: l10n.loanRename, onPressed: () => _rename(loan)),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(PalierSpace.page, PalierSpace.sm, PalierSpace.page, PalierSpace.xl),
            children: [
              Text(who, style: text.bodyMedium?.copyWith(color: PalierColors.textMid)),
              const SizedBox(height: PalierSpace.xs),
              LucidPrivateText(
                loan.settled
                    ? formatMoney(loan.amount, currency)
                    : l10n.loanRemaining(formatMoney(loan.remaining, currency)),
                mask: loan.settled ? maskedMoney(currency) : l10n.loanRemaining(maskedMoney(currency)),
                style: TextStyle(
                  fontFamily: PalierFonts.display,
                  fontSize: 26,
                  fontWeight: FontWeight.w600,
                  color: _remainingColor(loan),
                  fontFeatures: _figures,
                ),
              ),
              const SizedBox(height: PalierSpace.sm),
              _RepaidMeter(loan: loan, currency: currency, height: 6),
              const SizedBox(height: PalierSpace.sm),
              LucidPrivateText(
                l10n.loansRepaid(formatMoney(loan.repaid, currency), formatMoney(loan.amount, currency)),
                mask: l10n.loansRepaid(maskedMoney(currency), maskedMoney(currency)),
                style: text.bodySmall,
              ),
              Text('${_dayText(loan.startedOn)} · ${loan.payAccountName}', style: text.bodySmall),
              if (!loan.settled) ...[
                FieldLabel(l10n.loanRepayTitle),
                LucidTextField(
                  key: const ValueKey('remboursement'),
                  controller: _amount,
                  label: '${l10n.loanAmountLabel} (${currency.symbol})',
                  keyboardType: TextInputType.numberWithOptions(decimal: currency.decimals > 0),
                  validator: (v) {
                    final problem = loan.repaymentProblem(parseMoney(v ?? '', currency) ?? 0, _accountId);
                    return problem == null ? null : loanProblemText(l10n, problem);
                  },
                ),
                const SizedBox(height: PalierSpace.sm),
                Align(
                  alignment: Alignment.centerLeft,
                  child: ChoicePill(
                    label: l10n.loanRepayAll,
                    selected: false,
                    onTap: () => _amount.text = formatMoney(loan.remaining, currency, withSymbol: false),
                  ),
                ),
                FieldLabel(lent ? l10n.loanRepayAccountLentLabel : l10n.loanRepayAccountBorrowedLabel),
                Wrap(
                  spacing: PalierSpace.sm,
                  runSpacing: PalierSpace.sm,
                  children: [
                    for (final a in payable)
                      ChoicePill(
                        label: a.name,
                        icon: accountIcon(a.kind),
                        selected: _accountId == a.id,
                        onTap: () => setState(() => _accountId = a.id),
                      ),
                  ],
                ),
                const SizedBox(height: PalierSpace.lg),
                LucidButton(
                  label: l10n.loanRepaySave,
                  expand: true,
                  isLoading: _saving,
                  onPressed: () => _repay(loan, currency),
                ),
              ],
              const SizedBox(height: PalierSpace.md),
              TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: PalierColors.danger),
                onPressed: () => _delete(loan),
                icon: const Icon(Icons.delete_outline_rounded),
                label: Text(l10n.loanDelete),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// La fenêtre « Renommer » : elle garde son champ jusqu'à la fin de son
/// animation de fermeture. Libéré dès le retour de showDialog, le champ
/// servait encore à la fenêtre qui s'effaçait (écran rouge en annulant).
class _RenameDialog extends StatefulWidget {
  const _RenameDialog({required this.name});

  final String name;

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final _controller = TextEditingController(text: widget.name);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.loanRename),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        inputFormatters: [LengthLimitingTextInputFormatter(LoanDraft.maxNameLength)],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
        TextButton(onPressed: () => Navigator.pop(context, _controller.text), child: Text(l10n.loanRename)),
      ],
    );
  }
}

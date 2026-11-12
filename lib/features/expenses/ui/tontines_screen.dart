import 'package:flutter/services.dart';
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
import '../domain/tontines.dart';
import 'expense_visuals.dart';
import 'expense_widgets.dart';
import 'expenses_providers.dart';
import 'operation_fields.dart';

const _figures = [FontFeature.tabularFigures()];

/// Les rythmes d'une tontine : pas d'année, mais la quinzaine et les trois
/// semaines, courantes.
const List<LucidRecurrenceFrequency> _rhythms = [
  (unit: LucidRecurrenceUnit.week, interval: 1),
  (unit: LucidRecurrenceUnit.week, interval: 2),
  (unit: LucidRecurrenceUnit.week, interval: 3),
  (unit: LucidRecurrenceUnit.month, interval: 1),
];

String _day(DateTime day) => DateFormat.yMMMd('fr').format(day);

TontineNotes tontineNotes(AppLocalizations l10n) =>
    (contribution: l10n.tontineNoteContribution, hand: l10n.tontineNoteHand);

String tontineProblemText(AppLocalizations l10n, TontineProblem problem) => switch (problem) {
  TontineProblem.noName => l10n.tontineNoName,
  TontineProblem.noContribution => l10n.tontineNoContribution,
  TontineProblem.tooFewMembers => l10n.tontineTooFewMembers,
  TontineProblem.tooManyMembers => l10n.tontineTooManyMembers,
  TontineProblem.badRank => l10n.tontineBadRank,
  TontineProblem.noAccount => l10n.tontineNoAccount,
};

// ------------------------------------------------------------------- liste

/// Les tontines suivies : où en est le tour, quand vient sa main, et ce que
/// l'on a avancé au groupe ou qu'on lui doit encore.
class TontinesScreen extends ConsumerWidget {
  const TontinesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final currency = ref.watch(activeProfileProvider)?.currency;
    final tontines = ref.watch(tontinesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.tontinesTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: l10n.tontinesAdd,
            onPressed: () => context.push(Routes.expensesTontineNew),
          ),
        ],
      ),
      body: switch (tontines) {
        AsyncValue(error: final Object _) => LucidErrorState(message: l10n.errorGeneric),
        AsyncValue(value: final List<Tontine> list) when currency != null =>
          list.isEmpty
              ? const _EmptyTontines()
              : ListView(
                  padding: const EdgeInsets.fromLTRB(
                    PalierSpace.page,
                    PalierSpace.sm,
                    PalierSpace.page,
                    PalierSpace.xl,
                  ),
                  children: [for (final t in list) _TontineRow(tontine: t, currency: currency)],
                ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _TontineRow extends ConsumerWidget {
  const _TontineRow({required this.tontine, required this.currency});

  final Tontine tontine;
  final PalierCurrency currency;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final terms = tontine.terms;
    final today = localDay(ref.watch(clockProvider)());
    final done = terms.roundsUntil(today);
    final progress = switch (done) {
      0 => l10n.tontinesNotStarted(_day(terms.firstRound)),
      final n when n >= terms.members => l10n.tontinesFinished,
      final n =>
        '${l10n.tontinesRound(n, terms.members)} · ${l10n.tontinesHand(DateFormat.MMMd('fr').format(terms.handDay))}',
    };
    final balance = tontine.balance;

    return InkWell(
      key: ValueKey(tontine.id),
      onTap: () => context.push(Routes.expensesTontine(tontine.id)),
      borderRadius: BorderRadius.circular(PalierRadius.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: PalierSpace.sm + 4),
        child: Row(
          children: [
            Icon(accountIcon(AccountKind.tontine), color: PalierColors.textMid),
            const SizedBox(width: PalierSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tontine.name, style: text.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  LucidPrivateText(
                    '${formatMoney(terms.contribution, currency)} · '
                    '${LucidRecurrenceText.frequency(context, terms.unit, terms.interval)}',
                    mask:
                        '${maskedMoney(currency)} · ${LucidRecurrenceText.frequency(context, terms.unit, terms.interval)}',
                    style: text.bodySmall,
                  ),
                  Text(progress, style: text.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const SizedBox(width: PalierSpace.md),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                LucidPrivateText(
                  formatMoney(balance, currency),
                  mask: maskedMoney(currency),
                  style: manrope(
                    size: 15,
                    weight: FontWeight.w700,
                    color: balance < 0 ? PalierColors.warning : PalierColors.textHigh,
                  ).copyWith(fontFeatures: _figures),
                ),
                if (balance != 0) ...[
                  const SizedBox(height: 2),
                  Text(balance > 0 ? l10n.tontinesAhead : l10n.tontinesOwed, style: text.bodySmall),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyTontines extends StatelessWidget {
  const _EmptyTontines();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(PalierSpace.page, PalierSpace.lg, PalierSpace.page, PalierSpace.xl),
      children: [
        Text(l10n.tontinesEmptyTitle, style: text.titleLarge),
        const SizedBox(height: PalierSpace.sm),
        Text(l10n.tontinesEmptyBody, style: text.bodyMedium?.copyWith(color: PalierColors.textMid)),
        const SizedBox(height: PalierSpace.lg),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: () => context.push(Routes.expensesTontineNew),
            icon: const Icon(Icons.add_rounded),
            label: Text(l10n.tontinesAdd),
          ),
        ),
      ],
    );
  }
}

// --------------------------------------------------------------- formulaire

/// Créer ou modifier une tontine : nom, cotisation, rythme, membres, rang et
/// compte. Le résumé dit tout de suite quand vient la main, et combien.
class TontineFormScreen extends ConsumerStatefulWidget {
  const TontineFormScreen({super.key, this.tontineId});

  /// `null` pour une nouvelle tontine.
  final String? tontineId;

  @override
  ConsumerState<TontineFormScreen> createState() => _TontineFormScreenState();
}

class _TontineFormScreenState extends ConsumerState<TontineFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _contribution = TextEditingController();
  final _members = TextEditingController();
  final _rank = TextEditingController();
  late LucidRecurrence _rule;
  String? _accountId;
  bool _filled = false;
  bool _saving = false;

  bool get _editing => widget.tontineId != null;

  DateTime get _today => localDay(ref.read(clockProvider)());

  @override
  void initState() {
    super.initState();
    _rule = LucidRecurrence(unit: LucidRecurrenceUnit.week, start: _today);
    for (final c in [_contribution, _members, _rank]) {
      c.addListener(_refresh);
    }
  }

  void _refresh() => setState(() {});

  @override
  void dispose() {
    for (final c in [_name, _contribution, _members, _rank]) {
      c.dispose();
    }
    super.dispose();
  }

  void _fill(Tontine tontine, PalierCurrency currency) {
    if (_filled) return;
    _filled = true;
    final terms = tontine.terms;
    _name.text = tontine.name;
    _contribution.text = formatMoney(terms.contribution, currency, withSymbol: false);
    _members.text = '${terms.members}';
    _rank.text = '${terms.rank}';
    _rule = LucidRecurrence(unit: terms.unit, interval: terms.interval, start: terms.firstRound);
    _accountId = tontine.payAccountId;
  }

  TontineDraft _draft(PalierCurrency currency) => TontineDraft(
    name: _name.text,
    accountId: _accountId,
    terms: TontineTerms(
      contribution: parseMoney(_contribution.text, currency) ?? 0,
      members: int.tryParse(_members.text.trim()) ?? 0,
      rank: int.tryParse(_rank.text.trim()) ?? 0,
      unit: _rule.unit,
      interval: _rule.interval,
      firstRound: _rule.start,
    ),
  );

  Future<void> _save(PalierCurrency currency) async {
    if (!_formKey.currentState!.validate()) return;
    final draft = _draft(currency);
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final problem = draft.problem;
    if (problem != null) {
      PalierSnack.problem(messenger, tontineProblemText(l10n, problem));
      return;
    }
    final profileId = ref.read(activeProfileIdProvider);
    if (profileId == null) return;
    final repo = ref.read(expensesRepositoryProvider);
    setState(() => _saving = true);
    try {
      if (_editing) {
        await repo.updateTontine(widget.tontineId!, draft, notes: tontineNotes(l10n));
      } else {
        await repo.createTontine(profileId, draft, notes: tontineNotes(l10n));
      }
      if (!mounted) return;
      context.pop();
      PalierSnack.done(messenger, l10n.tontineSaved);
    } on Object {
      if (!mounted) return;
      setState(() => _saving = false);
      PalierSnack.problem(messenger, l10n.errorGeneric);
    }
  }

  Future<void> _stop(Tontine tontine) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.tontineStopTitle(tontine.name)),
        content: Text(l10n.tontineStopBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancel)),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: PalierColors.danger),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.tontineStop),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await ref.read(expensesRepositoryProvider).deleteTontine(tontine.id);
    if (!mounted) return;
    context.pop();
    PalierSnack.deleted(messenger, l10n.tontineStopped);
  }

  String? _required(String? value, String message) => (value?.trim() ?? '').isEmpty ? message : null;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final currency = ref.watch(activeProfileProvider)?.currency;
    final accounts = ref.watch(accountsProvider).value;
    final tontines = ref.watch(tontinesProvider).value;
    Tontine? existing;
    if (_editing && tontines != null) {
      existing = tontines.where((t) => t.id == widget.tontineId).firstOrNull;
      if (existing != null && currency != null) _fill(existing, currency);
    }
    // On cotise depuis un vrai compte, pas depuis une tontine ni un prêt.
    final payable = [
      for (final a in accounts ?? const <Account>[])
        if (a.kind != AccountKind.tontine && a.kind != AccountKind.loan) a,
    ];
    if (_accountId == null && payable.isNotEmpty) _accountId = payable.first.id;
    final loading = currency == null || accounts == null || (_editing && tontines == null);

    return Scaffold(
      appBar: AppBar(title: Text(_editing ? l10n.tontineEditTitle : l10n.tontineNewTitle)),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : _editing && existing == null
          ? Center(child: Text(l10n.tontineNotFound, style: Theme.of(context).textTheme.bodyLarge))
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
                      label: l10n.tontineNameLabel,
                      hint: l10n.tontineNameHint,
                      textCapitalization: TextCapitalization.sentences,
                      autofocus: !_editing,
                      textInputAction: TextInputAction.next,
                      inputFormatters: [LengthLimitingTextInputFormatter(TontineDraft.maxNameLength)],
                      validator: (v) => _required(v, l10n.tontineNoName),
                    ),
                    const SizedBox(height: PalierSpace.md),
                    LucidTextField(
                      key: const ValueKey('cotisation'),
                      controller: _contribution,
                      label: '${l10n.tontineContributionLabel} (${currency.symbol})',
                      keyboardType: TextInputType.numberWithOptions(decimal: currency.decimals > 0),
                      textInputAction: TextInputAction.next,
                      validator: (v) {
                        final amount = parseMoney(v ?? '', currency);
                        return amount == null || amount <= 0 ? l10n.tontineNoContribution : null;
                      },
                    ),
                    FieldLabel(l10n.tontineRhythmLabel),
                    LucidRecurrenceField(
                      value: _rule,
                      frequencies: _rhythms,
                      showUntil: false,
                      choiceBuilder: palierChoice,
                      // Une tontine se suit souvent en cours de route : son
                      // premier tour peut dater de plusieurs mois.
                      firstDate: DateTime(_today.year - 3),
                      onChanged: (rule) => setState(() => _rule = rule),
                    ),
                    const SizedBox(height: PalierSpace.lg),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: LucidTextField(
                            key: const ValueKey('membres'),
                            controller: _members,
                            label: l10n.tontineMembersLabel,
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            textInputAction: TextInputAction.next,
                            validator: (v) {
                              final n = int.tryParse(v?.trim() ?? '') ?? 0;
                              if (n < TontineTerms.minMembers) return l10n.tontineTooFewMembers;
                              if (n > TontineTerms.maxMembers) return l10n.tontineTooManyMembers;
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: PalierSpace.md),
                        Expanded(
                          child: LucidTextField(
                            key: const ValueKey('rang'),
                            controller: _rank,
                            label: l10n.tontineRankLabel,
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            textInputAction: TextInputAction.done,
                            validator: (v) {
                              final rank = int.tryParse(v?.trim() ?? '') ?? 0;
                              final members = int.tryParse(_members.text.trim()) ?? 0;
                              return rank < 1 || rank > members ? l10n.tontineBadRank : null;
                            },
                          ),
                        ),
                      ],
                    ),
                    FieldLabel(l10n.tontineAccountLabel),
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
                    _Summary(draft: _draft(currency), currency: currency, today: _today, editing: _editing),
                    const SizedBox(height: PalierSpace.lg),
                    LucidButton(
                      label: l10n.tontineSave,
                      expand: true,
                      isLoading: _saving,
                      onPressed: () => _save(currency),
                    ),
                    if (existing != null) ...[
                      const SizedBox(height: PalierSpace.sm),
                      TextButton.icon(
                        style: TextButton.styleFrom(foregroundColor: PalierColors.danger),
                        onPressed: () => _stop(existing!),
                        icon: const Icon(Icons.stop_circle_outlined),
                        label: Text(l10n.tontineStop),
                      ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }
}

/// Ce que donnera la tontine, dès que la saisie le permet : la main, son jour,
/// le dernier tour, et ce qui est déjà passé.
class _Summary extends StatelessWidget {
  const _Summary({required this.draft, required this.currency, required this.today, required this.editing});

  final TontineDraft draft;
  final PalierCurrency currency;
  final DateTime today;
  final bool editing;

  @override
  Widget build(BuildContext context) {
    final terms = draft.terms;
    // Le nom ni le compte ne changent le calendrier : le résumé n'attend qu'eux.
    if (TontineDraft(name: '-', terms: terms, accountId: '-').problem != null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final before = terms.roundsUntil(today.subtract(const Duration(days: 1)));
    final summary = l10n.tontineSummary(
      formatMoney(terms.pot, currency),
      _day(terms.handDay),
      terms.rank,
      terms.members,
      _day(terms.lastRound),
    );

    return Padding(
      padding: const EdgeInsets.only(top: PalierSpace.lg),
      child: DecoratedBox(
        decoration: BoxDecoration(color: PalierColors.surface, borderRadius: BorderRadius.circular(PalierRadius.md)),
        child: Padding(
          padding: const EdgeInsets.all(PalierSpace.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LucidPrivateText(
                summary,
                mask: l10n.tontineSummary(
                  maskedMoney(currency),
                  _day(terms.handDay),
                  terms.rank,
                  terms.members,
                  _day(terms.lastRound),
                ),
                style: text.bodyMedium?.copyWith(color: PalierColors.textHigh),
              ),
              // À la création seulement : modifier ne touche pas au départ.
              if (!editing && before > 0) ...[
                const SizedBox(height: PalierSpace.xs),
                Text(l10n.tontineAlreadyRun(before), style: text.bodySmall),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

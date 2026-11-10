import 'package:flutter/material.dart';
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
import '../domain/budgets.dart';
import '../domain/expense_kinds.dart';
import '../domain/expenses.dart';
import '../domain/money.dart';
import 'amount_pad.dart';
import 'expense_widgets.dart';
import 'expenses_providers.dart';

/// La jauge d'un budget aux couleurs de Palier : gris-bleu tant que tout va
/// bien (comme la barre « Sorti »), ambre à 80 % du plafond, rouge au-delà.
/// Pas l'accent du profil : un profil ambre aurait des jauges normales
/// identiques à celles en alerte.
class BudgetMeter extends StatelessWidget {
  const BudgetMeter({
    super.key,
    required this.spent,
    required this.limit,
    required this.label,
    required this.currency,
    this.projected,
    this.height = 6,
  });

  final int spent;
  final int limit;
  final int? projected;
  final String label;
  final PalierCurrency currency;
  final double height;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return LucidMeter(
      value: spent,
      max: limit,
      projected: projected,
      warningAt: budgetNearingAt,
      color: PalierColors.textMid,
      warningColor: PalierColors.warning,
      overColor: PalierColors.danger,
      trackColor: PalierColors.indigo,
      height: height,
      semanticLabel: label,
      semanticValue: l10n.budgetsOf(formatMoney(spent, currency), formatMoney(limit, currency)),
    );
  }
}

/// Ce que dit un plafond sous sa jauge : ce qui reste, le jour où il sera
/// atteint à ce rythme, ou de combien il est dépassé.
/// [mask] est le même texte, montant masqué.
({String text, String mask, Color color}) budgetStatus(
  AppLocalizations l10n,
  BudgetLine line,
  PalierCurrency currency,
) {
  final limit = line.budget.amount;
  final hidden = maskedMoney(currency);
  if (line.spent > limit) {
    return (
      text: l10n.budgetsOver(formatMoney(line.spent - limit, currency)),
      mask: l10n.budgetsOver(hidden),
      color: PalierColors.danger,
    );
  }
  if (line.spent == limit) return (text: l10n.budgetsReached, mask: l10n.budgetsReached, color: PalierColors.warning);
  final reach = line.reachDay;
  if (reach != null) {
    final text = l10n.budgetsReachDay(reach);
    return (text: text, mask: text, color: PalierColors.warning);
  }
  return (
    text: l10n.budgetsLeft(formatMoney(limit - line.spent, currency)),
    mask: l10n.budgetsLeft(hidden),
    color: PalierColors.textLow,
  );
}

/// Les plafonds du mois affiché, puis les catégories qui n'en ont pas.
class BudgetsScreen extends ConsumerWidget {
  const BudgetsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final currency = ref.watch(activeProfileProvider)?.currency;
    final month = ref.watch(budgetMonthProvider);
    final categories = ref.watch(categoriesProvider(CategoryKind.expense));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.budgetsTitle)),
      body: switch ((month, categories)) {
        (AsyncValue(error: final Object _), _) ||
        (_, AsyncValue(error: final Object _)) => LucidErrorState(message: l10n.errorGeneric),
        (AsyncValue(value: final BudgetMonth m), AsyncValue(value: final List<Category> list)) when currency != null =>
          _BudgetsList(month: m, categories: list, currency: currency),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _BudgetsList extends ConsumerWidget {
  const _BudgetsList({required this.month, required this.categories, required this.currency});

  final BudgetMonth month;
  final List<Category> categories;
  final PalierCurrency currency;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final budgeted = {for (final line in month.lines) line.budget.categoryId};
    final spentOutside = {for (final o in month.outside) o.categoryId: o.spent};
    final unset = [
      for (final c in categories)
        if (!budgeted.contains(c.id)) c,
    ]..sort((a, b) => (spentOutside[b.id] ?? 0).compareTo(spentOutside[a.id] ?? 0));
    final monthLabel = DateFormat.yMMMM('fr').format(month.month);

    return SafeArea(
      top: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(PalierSpace.page, PalierSpace.sm, PalierSpace.page, PalierSpace.xl),
        children: [
          Text(monthLabel[0].toUpperCase() + monthLabel.substring(1), style: text.labelMedium),
          const SizedBox(height: PalierSpace.xs),
          if (month.isEmpty) ...[
            Text(l10n.budgetsEmptyTitle, style: text.titleLarge),
            const SizedBox(height: PalierSpace.sm),
            Text(l10n.budgetsEmptyBody, style: text.bodyMedium?.copyWith(color: PalierColors.textMid)),
          ] else ...[
            BudgetTotal(month: month, currency: currency, large: true),
            _SectionTitle(l10n.budgetsSectionSet),
            for (final line in month.lines)
              _BudgetRow(
                line: line,
                currency: currency,
                onTap: () => context.push(Routes.expensesBudget(line.budget.categoryId)),
              ),
          ],
          if (unset.isNotEmpty) ...[
            _SectionTitle(l10n.budgetsSectionUnset),
            Text(l10n.budgetsUnsetHint, style: text.bodySmall?.copyWith(color: PalierColors.textLow)),
            const SizedBox(height: PalierSpace.xs),
            for (final category in unset)
              _UnsetRow(
                category: category,
                spent: spentOutside[category.id] ?? 0,
                currency: currency,
                onTap: () => context.push(Routes.expensesBudget(category.id)),
              ),
          ],
        ],
      ),
    );
  }
}

/// Le total des plafonds du mois : dépensé sur prévu, la jauge et la prévision.
/// Sert en tête de l'écran Budgets et dans l'onglet Dépenses.
class BudgetTotal extends StatelessWidget {
  const BudgetTotal({super.key, required this.month, required this.currency, this.large = false});

  final BudgetMonth month;
  final PalierCurrency currency;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final projected = month.projected;
    final lastDay = DateTime(month.month.year, month.month.month + 1, 0).day;
    const figures = [FontFeature.tabularFigures()];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Flexible(
              child: LucidPrivateText(
                formatMoney(month.spent, currency, withSymbol: false),
                mask: '•••',
                style: TextStyle(
                  fontFamily: PalierFonts.display,
                  fontSize: large ? 30 : 22,
                  fontWeight: FontWeight.w600,
                  color: PalierColors.textHigh,
                  fontFeatures: figures,
                ),
              ),
            ),
            const SizedBox(width: PalierSpace.sm),
            Flexible(
              child: LucidPrivateText(
                '/ ${formatMoney(month.limit, currency)}',
                mask: '/ ${maskedMoney(currency)}',
                style: manrope(
                  size: large ? 16 : 14,
                  weight: FontWeight.w600,
                  color: PalierColors.textMid,
                ).copyWith(fontFeatures: figures),
              ),
            ),
          ],
        ),
        const SizedBox(height: PalierSpace.sm + 2),
        BudgetMeter(
          spent: month.spent,
          limit: month.limit,
          projected: projected,
          label: l10n.budgetsTitle,
          currency: currency,
          height: large ? 10 : 8,
        ),
        if (projected != null) ...[
          const SizedBox(height: PalierSpace.sm),
          Row(
            children: [
              Icon(
                Icons.trending_up_rounded,
                size: 18,
                color: projected > month.limit ? PalierColors.danger : PalierColors.textLow,
              ),
              const SizedBox(width: PalierSpace.sm - 2),
              Expanded(
                child: LucidPrivateText(
                  l10n.budgetsForecast(formatMoney(projected, currency), lastDay),
                  mask: l10n.budgetsForecast(maskedMoney(currency), lastDay),
                  style: manrope(
                    size: 13,
                    weight: FontWeight.w600,
                    color: projected > month.limit ? PalierColors.danger : PalierColors.textMid,
                  ),
                ),
              ),
            ],
          ),
        ],
        if (month.outsideSpent > 0) ...[
          const SizedBox(height: PalierSpace.xs),
          LucidPrivateText(
            l10n.budgetsOutside(formatMoney(month.outsideSpent, currency)),
            mask: l10n.budgetsOutside(maskedMoney(currency)),
            style: manrope(size: 13, weight: FontWeight.w500, color: PalierColors.textLow),
          ),
        ],
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: PalierSpace.xl, bottom: PalierSpace.sm),
      child: Semantics(header: true, child: Text(text, style: Theme.of(context).textTheme.titleMedium)),
    );
  }
}

class _BudgetRow extends StatelessWidget {
  const _BudgetRow({required this.line, required this.currency, required this.onTap});

  final BudgetLine line;
  final PalierCurrency currency;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final status = budgetStatus(l10n, line, currency);
    const figures = [FontFeature.tabularFigures()];
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(PalierRadius.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: PalierSpace.sm + 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            OperationBadge(kind: OperationKind.expense, icon: line.budget.categoryIcon, size: 36),
            const SizedBox(width: PalierSpace.sm + 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          line.budget.categoryName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: manrope(size: 15, weight: FontWeight.w600, color: PalierColors.textHigh),
                        ),
                      ),
                      const SizedBox(width: PalierSpace.sm),
                      LucidPrivateText(
                        '${formatMoney(line.spent, currency, withSymbol: false)} / '
                        '${formatMoney(line.budget.amount, currency)}',
                        mask: maskedMoney(currency),
                        style: manrope(
                          size: 13,
                          weight: FontWeight.w600,
                          color: PalierColors.textMid,
                        ).copyWith(fontFeatures: figures),
                      ),
                    ],
                  ),
                  const SizedBox(height: PalierSpace.sm),
                  // Pas de prévision sur la jauge d'une ligne : la phrase dessous
                  // (« atteint vers le 12 ») la dit, et une jauge sur deux serait hachurée.
                  BudgetMeter(
                    spent: line.spent,
                    limit: line.budget.amount,
                    label: line.budget.categoryName,
                    currency: currency,
                  ),
                  const SizedBox(height: PalierSpace.xs + 2),
                  LucidPrivateText(
                    status.text,
                    mask: status.mask,
                    style: manrope(size: 13, weight: FontWeight.w600, color: status.color),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UnsetRow extends StatelessWidget {
  const _UnsetRow({required this.category, required this.spent, required this.currency, required this.onTap});

  final Category category;
  final int spent;
  final PalierCurrency currency;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: OperationBadge(kind: OperationKind.expense, icon: category.icon, size: 36),
      title: Text(category.name),
      subtitle: spent == 0
          ? Text(l10n.budgetsNothingSpent)
          : LucidPrivateText(formatMoney(spent, currency), mask: maskedMoney(currency)),
      trailing: Icon(Icons.add_rounded, color: PalierColors.textLow, semanticLabel: l10n.budgetsSet),
      onTap: onTap,
    );
  }
}

/// Poser, changer ou retirer le plafond d'une catégorie, au pavé.
class BudgetFormScreen extends ConsumerStatefulWidget {
  const BudgetFormScreen({super.key, required this.categoryId});

  final String categoryId;

  @override
  ConsumerState<BudgetFormScreen> createState() => _BudgetFormScreenState();
}

class _BudgetFormScreenState extends ConsumerState<BudgetFormScreen> {
  late AmountEntry _amount;
  bool _filled = false;
  bool _saving = false;
  bool _showProblem = false;

  @override
  void initState() {
    super.initState();
    _amount = AmountEntry.empty(ref.read(activeProfileProvider)!.currency);
    // Comme la saisie : un message encore affiché couvrirait « Enregistrer ».
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ScaffoldMessenger.maybeOf(context)?.removeCurrentSnackBar();
    });
  }

  /// Reprend le plafond existant une fois, dès qu'il est connu.
  void _fill(Budget? existing) {
    if (_filled) return;
    _filled = true;
    if (existing != null) _amount = AmountEntry.fromMinor(existing.amount, _amount.currency);
  }

  Future<void> _save() async {
    if (_amount.minor <= 0) {
      setState(() => _showProblem = true);
      return;
    }
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final profileId = ref.read(activeProfileProvider)!.id;
    setState(() => _saving = true);
    try {
      await ref.read(expensesRepositoryProvider).setBudget(profileId, widget.categoryId, _amount.minor);
      if (!mounted) return;
      context.pop();
      PalierSnack.done(messenger, l10n.budgetSaved);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Retirer se rattrape : « Annuler » remet le même plafond.
  Future<void> _remove(Budget existing) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final profileId = ref.read(activeProfileProvider)!.id;
    final repo = ref.read(expensesRepositoryProvider);
    await repo.removeBudget(widget.categoryId);
    if (!mounted) return;
    context.pop();
    PalierSnack.deleted(
      messenger,
      l10n.budgetRemoved,
      undoLabel: l10n.operationUndo,
      onUndo: () => repo.setBudget(profileId, existing.categoryId, existing.amount),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final categories = ref.watch(categoriesProvider(CategoryKind.expense)).value;
    final budgets = ref.watch(budgetsProvider).value;
    final month = ref.watch(budgetMonthProvider).value;

    Category? category;
    for (final c in categories ?? const <Category>[]) {
      if (c.id == widget.categoryId) category = c;
    }
    Budget? existing;
    for (final b in budgets ?? const <Budget>[]) {
      if (b.categoryId == widget.categoryId) existing = b;
    }
    final loading = categories == null || budgets == null;
    if (!loading) _fill(existing);

    var spent = 0;
    for (final line in month?.lines ?? const <BudgetLine>[]) {
      if (line.budget.categoryId == widget.categoryId) spent = line.spent;
    }
    for (final o in month?.outside ?? const <UnbudgetedSpend>[]) {
      if (o.categoryId == widget.categoryId) spent = o.spent;
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
          onPressed: () => context.pop(),
        ),
        title: Text(l10n.budgetFormTitle),
        actions: [
          if (existing != null)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded),
              tooltip: l10n.budgetFormRemove,
              onPressed: () => _remove(existing!),
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : category == null
            ? Center(child: Text(l10n.budgetFormNotFound, style: text.bodyLarge))
            : Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(
                        PalierSpace.page,
                        PalierSpace.lg,
                        PalierSpace.page,
                        PalierSpace.md,
                      ),
                      children: [
                        Center(
                          child: OperationBadge(kind: OperationKind.expense, icon: category.icon, size: 56),
                        ),
                        const SizedBox(height: PalierSpace.sm + 4),
                        Text(
                          l10n.budgetFormPerMonth(category.name),
                          textAlign: TextAlign.center,
                          style: text.titleMedium,
                        ),
                        AmountDisplay(amount: _amount),
                        if (spent > 0)
                          Center(
                            child: LucidPrivateText(
                              l10n.budgetFormSpent(formatMoney(spent, _amount.currency)),
                              mask: l10n.budgetFormSpent(maskedMoney(_amount.currency)),
                              style: manrope(size: 14, weight: FontWeight.w500, color: PalierColors.textMid),
                            ),
                          ),
                      ],
                    ),
                  ),
                  AmountPanel(
                    amount: _amount,
                    onAmountChanged: (value) => setState(() {
                      _amount = value;
                      _showProblem = false;
                    }),
                    problem: _showProblem ? l10n.budgetFormNoAmount : null,
                    saveLabel: l10n.budgetFormSave,
                    saving: _saving,
                    onSave: _save,
                  ),
                ],
              ),
      ),
    );
  }
}

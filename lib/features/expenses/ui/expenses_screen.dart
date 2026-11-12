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
import '../domain/expenses.dart';
import '../domain/money.dart';
import 'budgets_screen.dart';
import 'expense_visuals.dart';
import 'expense_widgets.dart';
import 'expenses_providers.dart';
import 'recurrings_screen.dart';

/// L'onglet Dépenses : ce qu'il y a sur les comptes, puis le mois jour par jour.
class ExpensesScreen extends ConsumerWidget {
  const ExpensesScreen({super.key});

  /// Le bouton « Noter ». Il vit dans le Scaffold des onglets ([HomeShell]) et
  /// non dans celui de l'écran : c'est ce Scaffold-là qui affiche les messages
  /// du bas, et il ne les remonte au-dessus que du bouton qu'il porte lui-même.
  static Widget addButton(BuildContext context) => FloatingActionButton.extended(
    onPressed: () => context.push(Routes.expensesNew),
    icon: const Icon(Icons.add_rounded),
    label: Text(AppLocalizations.of(context).expensesAdd),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final profile = ref.watch(activeProfileProvider);
    if (profile == null) return const SizedBox.shrink();

    final accounts = ref.watch(accountsProvider);
    final month = ref.watch(monthViewProvider);

    return Scaffold(
      body: SafeArea(
        child: switch ((accounts, month)) {
          (AsyncValue(error: final Object _), _) ||
          (_, AsyncValue(error: final Object _)) => LucidErrorState(message: l10n.errorGeneric),
          (AsyncValue(value: final List<Account> list), AsyncValue(value: final MonthView view)) => _Content(
            currency: profile.currency,
            accounts: list,
            month: view,
          ),
          _ => const Center(child: CircularProgressIndicator()),
        },
      ),
    );
  }
}

class _Content extends ConsumerStatefulWidget {
  const _Content({required this.currency, required this.accounts, required this.month});

  final PalierCurrency currency;
  final List<Account> accounts;
  final MonthView month;

  @override
  ConsumerState<_Content> createState() => _ContentState();
}

/// Les jours du mois se replient : seul le plus récent est ouvert d'office,
/// les autres se résument à leur en-tête (date, nombre d'opérations, solde).
class _ContentState extends ConsumerState<_Content> {
  /// Les jours dont on a changé l'état d'office (ouvert ou replié).
  final _toggled = <DateTime>{};

  bool _isOpen(int index, DateTime day) => (index == 0) != _toggled.contains(day);

  void _toggle(DateTime day) => setState(() => _toggled.contains(day) ? _toggled.remove(day) : _toggled.add(day));

  PalierCurrency get currency => widget.currency;
  List<Account> get accounts => widget.accounts;
  MonthView get month => widget.month;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final dayFormat = DateFormat.MMMMEEEEd('fr');
    final now = ref.watch(clockProvider)();
    final total = availableBalance(accounts);

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(PalierSpace.page, PalierSpace.lg, PalierSpace.page, 0),
          sliver: SliverList.list(
            children: [
              Row(
                children: [
                  Expanded(child: Text(l10n.expensesTitle, style: text.headlineMedium)),
                  PopupMenuButton<String>(
                    tooltip: l10n.expensesMenu,
                    icon: const Icon(Icons.tune_rounded),
                    onSelected: context.push,
                    itemBuilder: (_) => [
                      PopupMenuItem(value: Routes.expensesAccounts, child: Text(l10n.expensesManageAccounts)),
                      PopupMenuItem(value: Routes.expensesCategories, child: Text(l10n.expensesManageCategories)),
                      PopupMenuItem(value: Routes.expensesBudgets, child: Text(l10n.expensesManageBudgets)),
                      PopupMenuItem(value: Routes.expensesRecurrings, child: Text(l10n.expensesManageRecurrings)),
                      PopupMenuItem(value: Routes.expensesTontines, child: Text(l10n.expensesManageTontines)),
                      PopupMenuItem(value: Routes.expensesLoans, child: Text(l10n.expensesManageLoans)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: PalierSpace.lg),
              DuesBlock(currency: currency),
              Row(
                children: [
                  Expanded(child: Text(l10n.expensesBalanceLabel, style: text.labelMedium)),
                  const LucidPrivacyToggle(color: PalierColors.textMid, iconSize: 20),
                ],
              ),
              FittedBox(
                alignment: Alignment.centerLeft,
                fit: BoxFit.scaleDown,
                child: LucidPrivateText(
                  formatBalance(total, currency),
                  mask: maskedMoney(currency),
                  style: text.displaySmall!.copyWith(
                    color: balanceColor(context, total),
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              _AfterDues(total: total, currency: currency),
              const SizedBox(height: PalierSpace.md),
            ],
          ),
        ),
        SliverToBoxAdapter(
          child: SizedBox(
            height: 76,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: PalierSpace.page),
              children: [
                for (final account in accounts) ...[
                  _AccountChip(
                    account: account,
                    currency: currency,
                    onTap: () => context.push(Routes.expensesAccount(account.id)),
                  ),
                  const SizedBox(width: PalierSpace.sm),
                ],
                _AddAccountChip(label: l10n.accountsAdd, onTap: () => context.push(Routes.expensesAccountNew)),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(PalierSpace.page, PalierSpace.xl, PalierSpace.page, 0),
          sliver: SliverList.list(
            children: [
              _MonthBar(month: month.month),
              const SizedBox(height: PalierSpace.md),
              _MonthSummary(spent: month.spent, received: month.received, currency: currency),
              const SizedBox(height: PalierSpace.lg),
              _BudgetsBlock(currency: currency),
            ],
          ),
        ),
        if (month.isEmpty)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(PalierSpace.page, PalierSpace.xl, PalierSpace.page, 0),
            sliver: SliverToBoxAdapter(child: _EmptyMonth()),
          )
        else
          for (final (index, day) in month.days.indexed)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(PalierSpace.page, PalierSpace.md, PalierSpace.page, 0),
              sliver: SliverList.list(
                children: [
                  _DayHeader(
                    label: dayLabel(l10n, day.day, dayFormat.format, now: now),
                    net: day.received - day.spent,
                    count: day.entries.length,
                    open: _isOpen(index, day.day),
                    onTap: () => _toggle(day.day),
                    currency: currency,
                  ),
                  if (_isOpen(index, day.day))
                    for (final entry in day.entries)
                      // Glisser n'est qu'un raccourci : le toucher ouvre aussi la ligne.
                      LucidSwipeActions(
                        key: ValueKey(entry.id),
                        borderRadius: BorderRadius.circular(PalierRadius.sm),
                        startAction: LucidSwipeAction(
                          icon: Icons.delete_outline_rounded,
                          label: l10n.delete,
                          color: PalierColors.danger,
                          removesItem: true,
                          threshold: 0.4,
                          onTriggered: () => _delete(context, entry.id),
                        ),
                        endAction: LucidSwipeAction(
                          icon: Icons.edit_outlined,
                          label: l10n.operationEditTitle,
                          threshold: 0.25,
                          onTriggered: () => context.push(Routes.expensesOperation(entry.id)),
                        ),
                        child: OperationTile(
                          entry: entry,
                          currency: currency,
                          onTap: () => context.push(Routes.expensesOperation(entry.id)),
                        ),
                      ),
                ],
              ),
            ),
        // Place pour le bouton flottant sous la dernière ligne.
        const SliverToBoxAdapter(child: SizedBox(height: 96)),
      ],
    );
  }

  /// Suppression d'un glissement : pas de confirmation, « Annuler » la rattrape.
  Future<void> _delete(BuildContext context, String id) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final repo = ref.read(expensesRepositoryProvider);
    await repo.deleteOperation(id);
    PalierSnack.deleted(
      messenger,
      l10n.operationDeleted,
      undoLabel: l10n.operationUndo,
      onUndo: () => repo.restoreOperation(id),
    );
  }
}

/// Le solde une fois passées les échéances encore attendues ce mois-ci
/// (retards compris) ; rien s'il n'y en a pas.
class _AfterDues extends ConsumerWidget {
  const _AfterDues({required this.total, required this.currency});

  final int total;
  final PalierCurrency currency;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final net = ref.watch(pendingNetProvider);
    if (net == null) return const SizedBox.shrink();
    final after = total + net;
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: LucidPrivateText(
        l10n.expensesAfterDues(formatBalance(after, currency)),
        mask: l10n.expensesAfterDues(maskedMoney(currency)),
        style: manrope(
          size: 14,
          weight: FontWeight.w600,
          color: after < 0 && !LucidPrivacyScope.isHidden(context) ? PalierColors.danger : PalierColors.textMid,
        ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
      ),
    );
  }
}

class _AccountChip extends StatelessWidget {
  const _AccountChip({required this.account, required this.currency, required this.onTap});

  final Account account;
  final PalierCurrency currency;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: PalierColors.surface,
      borderRadius: BorderRadius.circular(PalierRadius.md),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: PalierSpace.md, vertical: PalierSpace.sm + 2),
          child: Row(
            children: [
              Icon(accountIcon(account.kind), size: 20, color: PalierColors.textMid),
              const SizedBox(width: PalierSpace.sm + 2),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    account.name,
                    style: manrope(size: 13, weight: FontWeight.w600, color: PalierColors.textMid),
                  ),
                  const SizedBox(height: 2),
                  LucidPrivateText(
                    formatBalance(account.balance, currency),
                    mask: maskedMoney(currency),
                    style: manrope(
                      size: 15,
                      weight: FontWeight.w700,
                      color: balanceColor(context, account.balance),
                    ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddAccountChip extends StatelessWidget {
  const _AddAccountChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        child: Material(
          color: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(PalierRadius.md),
            side: const BorderSide(color: PalierColors.line),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: const SizedBox(width: 64, child: Icon(Icons.add_rounded, color: PalierColors.textMid)),
          ),
        ),
      ),
    );
  }
}

class _MonthBar extends ConsumerWidget {
  const _MonthBar({required this.month});

  final DateTime month;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    ref.watch(selectedMonthProvider);
    final controller = ref.read(selectedMonthProvider.notifier);
    final label = DateFormat.yMMMM('fr').format(month);
    final isCurrent = controller.isCurrent;
    return Row(
      children: [
        Expanded(
          child: Text(label[0].toUpperCase() + label.substring(1), style: Theme.of(context).textTheme.titleLarge),
        ),
        IconButton(
          tooltip: l10n.expensesPreviousMonth,
          icon: const Icon(Icons.chevron_left_rounded),
          onPressed: controller.previous,
        ),
        IconButton(
          tooltip: l10n.expensesNextMonth,
          icon: const Icon(Icons.chevron_right_rounded),
          onPressed: isCurrent ? null : controller.next,
        ),
      ],
    );
  }
}

/// Sorti et entré sur le mois, et une barre qui les compare : on voit d'un coup
/// d'œil si le mois dépense plus qu'il ne reçoit.
class _MonthSummary extends StatelessWidget {
  const _MonthSummary({required this.spent, required this.received, required this.currency});

  final int spent;
  final int received;
  final PalierCurrency currency;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final larger = spent > received ? spent : received;

    Widget figure(String label, int amount, Color color, CrossAxisAlignment align) => Column(
      crossAxisAlignment: align,
      children: [
        Text(label, style: text.labelMedium),
        const SizedBox(height: 2),
        LucidPrivateText(
          formatMoney(amount, currency),
          mask: maskedMoney(currency),
          style: manrope(
            size: 17,
            weight: FontWeight.w700,
            color: color,
          ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
        ),
      ],
    );

    // Une simple jauge, pas un indicateur de progression : rien n'est en cours.
    Widget bar(int amount, Color color) => Container(
      height: 6,
      decoration: BoxDecoration(color: PalierColors.indigo, borderRadius: BorderRadius.circular(3)),
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: larger == 0 ? 0 : amount / larger,
        child: DecoratedBox(
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
          child: const SizedBox.expand(),
        ),
      ),
    );

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: figure(l10n.expensesSpentLabel, spent, PalierColors.textHigh, CrossAxisAlignment.start)),
            Expanded(child: figure(l10n.expensesReceivedLabel, received, PalierColors.success, CrossAxisAlignment.end)),
          ],
        ),
        const SizedBox(height: PalierSpace.sm + 2),
        ExcludeSemantics(
          child: Column(
            children: [
              bar(spent, PalierColors.textMid),
              const SizedBox(height: PalierSpace.xs),
              bar(received, PalierColors.success),
            ],
          ),
        ),
      ],
    );
  }
}

/// Les budgets du mois en un coup d'œil ; un toucher ouvre l'écran Budgets.
/// Sans plafond, une invitation discrète à en poser.
class _BudgetsBlock extends ConsumerWidget {
  const _BudgetsBlock({required this.currency});

  final PalierCurrency currency;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final month = ref.watch(budgetMonthProvider).value;
    if (month == null) return const SizedBox.shrink();
    void open() => context.push(Routes.expensesBudgets);

    if (month.isEmpty) {
      return Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          // Aligné sur le bord de page, comme le texte au-dessus.
          style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: PalierSpace.sm + 4)),
          onPressed: open,
          icon: const Icon(Icons.speed_rounded, size: 20),
          label: Text(l10n.budgetsSet),
        ),
      );
    }
    return Material(
      color: PalierColors.surface,
      borderRadius: BorderRadius.circular(PalierRadius.md),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: open,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(PalierSpace.md, PalierSpace.sm + 4, PalierSpace.sm, PalierSpace.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(l10n.budgetsTitle, style: Theme.of(context).textTheme.labelMedium)),
                  const Icon(Icons.chevron_right_rounded, color: PalierColors.textLow),
                ],
              ),
              const SizedBox(height: PalierSpace.xs),
              Padding(
                padding: const EdgeInsets.only(right: PalierSpace.sm),
                child: BudgetTotal(month: month, currency: currency),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// L'en-tête d'un jour : le toucher ouvre ou replie ses opérations.
class _DayHeader extends StatelessWidget {
  const _DayHeader({
    required this.label,
    required this.net,
    required this.count,
    required this.open,
    required this.onTap,
    required this.currency,
  });

  final String label;
  final int net;
  final int count;
  final bool open;
  final VoidCallback onTap;
  final PalierCurrency currency;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      expanded: open,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(PalierRadius.sm),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: kPalierMinTarget),
          child: Row(
            children: [
              Expanded(
                child: Text.rich(
                  TextSpan(
                    text: label,
                    children: [
                      if (!open)
                        TextSpan(
                          text: ' · ${l10n.expensesDayCount(count)}',
                          style: text.labelMedium!.copyWith(color: PalierColors.textLow),
                        ),
                    ],
                  ),
                  style: text.labelLarge!.copyWith(color: PalierColors.textMid),
                ),
              ),
              if (net != 0)
                LucidPrivateText(
                  formatMoney(net, currency, signed: true),
                  mask: maskedMoney(currency),
                  style: text.labelMedium!.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
                ),
              const SizedBox(width: PalierSpace.xs),
              AnimatedRotation(
                turns: open ? 0.5 : 0,
                duration: const Duration(milliseconds: 180),
                child: const Icon(Icons.expand_more_rounded, size: 20, color: PalierColors.textLow),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyMonth extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.expensesEmptyTitle, style: text.titleMedium),
        const SizedBox(height: PalierSpace.xs),
        Text(l10n.expensesEmptyBody, style: text.bodyMedium),
      ],
    );
  }
}

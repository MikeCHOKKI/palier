import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../app/theme/palier_accent.dart';
import '../../../app/theme/palier_theme.dart';
import '../../../app/theme/palier_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/expense_kinds.dart';
import '../domain/expenses.dart';
import 'expense_visuals.dart';
import 'expense_widgets.dart';

/// Ce qu'une opération et une récurrence ont en commun à choisir : la catégorie
/// et le compte, ou les deux comptes d'un virement. Partagé par l'écran « Noter »
/// et le formulaire d'une récurrence.
class OperationFields extends StatelessWidget {
  const OperationFields({
    super.key,
    required this.kind,
    required this.accounts,
    required this.categories,
    required this.accountId,
    required this.toAccountId,
    required this.categoryId,
    required this.onAccount,
    required this.onToAccount,
    required this.onCategory,
    required this.onAddTargetAccount,
  });

  final OperationKind kind;
  final List<Account> accounts;
  final List<Category> categories;
  final String? accountId;
  final String? toAccountId;
  final String? categoryId;
  final ValueChanged<String> onAccount;
  final ValueChanged<String> onToAccount;
  final ValueChanged<String> onCategory;
  final VoidCallback onAddTargetAccount;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (kind == OperationKind.transfer) ...[
          if (accounts.length < 2)
            _TransferNeedsTwoAccounts(onAdd: onAddTargetAccount)
          else ...[
            FieldLabel(l10n.operationFromLabel),
            accountPills(accountId, onAccount),
            FieldLabel(l10n.operationToLabel),
            accountPills(toAccountId, onToAccount),
          ],
        ] else ...[
          FieldLabel(l10n.operationCategoryLabel),
          _CategoryStrip(
            categories: categories,
            selectedId: categoryId,
            onSelect: onCategory,
            onManage: () => context.push(Routes.expensesCategories),
            manageLabel: l10n.expensesManageCategories,
          ),
          FieldLabel(l10n.operationAccountLabel),
          accountPills(accountId, onAccount),
        ],
      ],
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

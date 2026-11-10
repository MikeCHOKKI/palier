import 'package:flutter/material.dart';
import 'package:lucid_core_flutter/lucid_core_flutter.dart' show LucidPrivacyScope, LucidPrivateText;

import '../../../app/theme/palier_theme.dart';
import '../../../app/theme/palier_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../profiles/domain/profile.dart';
import '../domain/expense_kinds.dart';
import '../domain/expenses.dart';
import '../domain/money.dart';
import 'expense_visuals.dart';

/// Titre court au-dessus d'un groupe de choix.
class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: PalierSpace.md + 4, bottom: PalierSpace.sm),
      child: Text(text, style: Theme.of(context).textTheme.labelMedium),
    );
  }
}

/// Une pastille à choisir (compte, date) : contour discret, accent quand elle est choisie.
class ChoicePill extends StatelessWidget {
  const ChoicePill({super.key, required this.label, required this.selected, required this.onTap, this.icon});

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? accent.withValues(alpha: 0.16) : Colors.transparent,
        shape: StadiumBorder(side: BorderSide(color: selected ? accent : PalierColors.line)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: kPalierMinTarget),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: PalierSpace.md),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 18, color: selected ? accent : PalierColors.textMid),
                    const SizedBox(width: PalierSpace.sm),
                  ],
                  Text(
                    label,
                    style: manrope(
                      size: 14,
                      weight: FontWeight.w600,
                      color: selected ? PalierColors.textHigh : PalierColors.textMid,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Rangée de pastilles qui défile si elle déborde.
class PillRow extends StatelessWidget {
  const PillRow({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        children: [
          for (var i = 0; i < children.length; i++) ...[if (i > 0) const SizedBox(width: PalierSpace.sm), children[i]],
        ],
      ),
    );
  }
}

/// Pastille ronde d'une opération : l'icône de sa catégorie, ou celle du virement.
class OperationBadge extends StatelessWidget {
  const OperationBadge({super.key, required this.kind, this.icon, this.size = 40});

  final OperationKind kind;
  final String? icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = switch (kind) {
      OperationKind.expense => (PalierColors.indigo, PalierColors.textMid),
      OperationKind.income => (PalierColors.success.withValues(alpha: 0.14), PalierColors.success),
      OperationKind.transfer => (PalierColors.steel.withValues(alpha: 0.22), PalierColors.textMid),
    };
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: background, shape: BoxShape.circle),
        child: Icon(
          kind == OperationKind.transfer ? transferIcon : categoryIcon(icon),
          size: size * 0.5,
          color: foreground,
        ),
      ),
    );
  }
}

/// Une ligne de la liste des opérations.
class OperationTile extends StatelessWidget {
  const OperationTile({super.key, required this.entry, required this.currency, required this.onTap});

  final OperationEntry entry;
  final PalierCurrency currency;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;

    final title = switch (entry.kind) {
      OperationKind.transfer => l10n.expensesTransfer,
      _ => entry.categoryName ?? l10n.expensesUncategorized,
    };
    final where = entry.kind == OperationKind.transfer
        ? l10n.expensesTransferRoute(entry.accountName, entry.toAccountName ?? '?')
        : entry.accountName;
    final subtitle = entry.note == null ? where : '${entry.note} · $where';

    final amount = switch (entry.kind) {
      OperationKind.expense => formatMoney(-entry.amount, currency, signed: true),
      OperationKind.income => formatMoney(entry.amount, currency, signed: true),
      OperationKind.transfer => formatMoney(entry.amount, currency),
    };
    final amountColor = switch (entry.kind) {
      OperationKind.income => PalierColors.success,
      OperationKind.expense => PalierColors.textHigh,
      OperationKind.transfer => PalierColors.textMid,
    };

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(PalierRadius.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: PalierSpace.sm + 2),
        child: Row(
          children: [
            OperationBadge(kind: entry.kind, icon: entry.categoryIcon),
            const SizedBox(width: PalierSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: text.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(subtitle, style: text.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const SizedBox(width: PalierSpace.md),
            LucidPrivateText(
              amount,
              mask: maskedMoney(currency),
              style: manrope(
                size: 15,
                weight: FontWeight.w700,
                color: amountColor,
              ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
            ),
          ],
        ),
      ),
    );
  }
}

/// « Aujourd'hui », « Hier », ou « Samedi 7 novembre ».
String dayLabel(AppLocalizations l10n, DateTime day, String Function(DateTime) longFormat, {required DateTime now}) {
  final today = DateTime(now.year, now.month, now.day);
  if (day == today) return l10n.expensesToday;
  if (day == today.subtract(const Duration(days: 1))) return l10n.expensesYesterday;
  final label = longFormat(day);
  return label[0].toUpperCase() + label.substring(1);
}

/// Couleur d'un solde : rouge s'il est négatif, sauf montants masqués (le
/// rouge dirait encore que le compte est à découvert).
Color balanceColor(BuildContext context, int balance) =>
    balance < 0 && !LucidPrivacyScope.isHidden(context) ? PalierColors.danger : PalierColors.textHigh;

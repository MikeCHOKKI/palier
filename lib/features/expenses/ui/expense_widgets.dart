import 'package:lucid_core_flutter/lucid_core_flutter.dart' show LucidPrivacyScope, LucidPrivateText;
import 'package:material_ui/material_ui.dart';

import '../../../app/theme/palier_theme.dart';
import '../../../app/theme/palier_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../profiles/domain/profile.dart';
import '../domain/expense_kinds.dart';
import '../domain/expenses.dart';
import '../domain/money.dart';
import 'expense_visuals.dart';

export '../../../core/ui/choice_widgets.dart';

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

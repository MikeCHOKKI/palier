import 'package:flutter/material.dart';
import 'package:lucid_core_flutter/lucid_core_flutter.dart';

import '../../l10n/app_localizations.dart';

/// Onglet d'un module pas encore livré (dépenses au lot 2, sport au lot 3).
class ComingSoonScreen extends StatelessWidget {
  const ComingSoonScreen.expenses({super.key}) : _expenses = true;

  const ComingSoonScreen.sport({super.key}) : _expenses = false;

  final bool _expenses;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      child: LucidEmptyState(
        icon: _expenses ? Icons.account_balance_wallet_outlined : Icons.directions_run_rounded,
        title: _expenses ? l10n.expensesSoonTitle : l10n.sportSoonTitle,
        message: _expenses ? l10n.expensesSoonBody : l10n.sportSoonBody,
      ),
    );
  }
}

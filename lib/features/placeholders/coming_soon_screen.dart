import 'package:flutter/material.dart';
import 'package:lucid_core_flutter/lucid_core_flutter.dart';

import '../../l10n/app_localizations.dart';

/// Onglet d'un module pas encore livré (le sport, au lot 3).
class ComingSoonScreen extends StatelessWidget {
  const ComingSoonScreen.sport({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      child: LucidEmptyState(
        icon: Icons.directions_run_rounded,
        title: l10n.sportSoonTitle,
        message: l10n.sportSoonBody,
      ),
    );
  }
}

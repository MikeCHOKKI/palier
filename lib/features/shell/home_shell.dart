import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/providers.dart';
import '../../l10n/app_localizations.dart';
import '../expenses/ui/expenses_providers.dart';
import '../expenses/ui/expenses_screen.dart';

/// Les onglets du profil ouvert. Un module désactivé n'a pas d'onglet.
class HomeShell extends ConsumerWidget {
  const HomeShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  /// Index des branches déclarées dans le routeur.
  static const int _home = 0;
  static const int _expenses = 1;
  static const int _sport = 2;
  static const int _settings = 3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final profile = ref.watch(activeProfileProvider);
    final dues = (profile?.expensesEnabled ?? false) ? ref.watch(duesProvider).length : 0;

    final tabs = <(int, NavigationDestination)>[
      (
        _home,
        NavigationDestination(
          icon: const Icon(Icons.home_outlined),
          selectedIcon: const Icon(Icons.home_rounded),
          label: l10n.navHome,
        ),
      ),
      if (profile?.expensesEnabled ?? false)
        (
          _expenses,
          NavigationDestination(
            // Le nombre d'échéances à valider, comme un message non lu.
            icon: Badge.count(
              count: dues,
              isLabelVisible: dues > 0,
              child: const Icon(Icons.account_balance_wallet_outlined),
            ),
            selectedIcon: Badge.count(
              count: dues,
              isLabelVisible: dues > 0,
              child: const Icon(Icons.account_balance_wallet_rounded),
            ),
            label: l10n.navExpenses,
          ),
        ),
      if (profile?.sportEnabled ?? false)
        (
          _sport,
          NavigationDestination(
            icon: const Icon(Icons.directions_run_outlined),
            selectedIcon: const Icon(Icons.directions_run_rounded),
            label: l10n.navSport,
          ),
        ),
      (
        _settings,
        NavigationDestination(
          icon: const Icon(Icons.tune_outlined),
          selectedIcon: const Icon(Icons.tune_rounded),
          label: l10n.navSettings,
        ),
      ),
    ];

    final selected = tabs.indexWhere((tab) => tab.$1 == shell.currentIndex);

    return Scaffold(
      body: shell,
      // Porté ici pour que les messages du bas passent au-dessus du bouton.
      floatingActionButton: switch (shell.currentIndex) {
        _expenses => ExpensesScreen.addButton(context),
        _ => null,
      },
      bottomNavigationBar: NavigationBar(
        selectedIndex: selected < 0 ? 0 : selected,
        destinations: [for (final tab in tabs) tab.$2],
        onDestinationSelected: (i) {
          final branch = tabs[i].$1;
          // Toucher l'onglet déjà ouvert ramène à sa racine.
          shell.goBranch(branch, initialLocation: branch == shell.currentIndex);
        },
      ),
    );
  }
}

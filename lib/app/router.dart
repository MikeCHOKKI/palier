import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/backup/ui/backup_screen.dart';
import '../features/expenses/ui/accounts_screen.dart';
import '../features/expenses/ui/budgets_screen.dart';
import '../features/expenses/ui/categories_screen.dart';
import '../features/expenses/ui/expenses_screen.dart';
import '../features/expenses/ui/operation_screen.dart';
import '../features/home/home_screen.dart';
import '../features/placeholders/coming_soon_screen.dart';
import '../features/profiles/ui/loading_screen.dart';
import '../features/profiles/ui/lock_settings_screen.dart';
import '../features/profiles/ui/profile_form_screen.dart';
import '../features/profiles/ui/profile_picker_screen.dart';
import '../features/profiles/ui/set_pin_screen.dart';
import '../features/profiles/ui/unlock_screen.dart';
import '../features/profiles/ui/welcome_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/shell/home_shell.dart';
import 'providers.dart';
import 'routes.dart';

final routerProvider = Provider<GoRouter>((ref) {
  // go_router relit la redirection quand les profils ou la session changent.
  final refresh = ValueNotifier<int>(0);
  ref
    ..listen(profilesProvider, (_, _) => refresh.value++)
    ..listen(sessionProvider, (_, _) => refresh.value++);

  // Les écrans de saisie s'ouvrent en plein écran, au-dessus des onglets : un
  // écran poussé depuis l'un d'eux reste ainsi visible, au lieu de tomber sous lui
  // dans la pile de l'onglet.
  final rootKey = GlobalKey<NavigatorState>(debugLabel: 'racine');
  GoRoute fullScreen(String path, Widget Function(GoRouterState state) build, {List<RouteBase> routes = const []}) =>
      GoRoute(path: path, parentNavigatorKey: rootKey, builder: (_, state) => build(state), routes: routes);

  final router = GoRouter(
    navigatorKey: rootKey,
    initialLocation: Routes.loading,
    refreshListenable: refresh,
    redirect: (context, state) => resolveRedirect(
      profiles: ref.read(profilesProvider),
      session: ref.read(sessionProvider),
      location: state.matchedLocation,
    ),
    routes: [
      GoRoute(path: Routes.loading, builder: (_, _) => const LoadingScreen()),
      GoRoute(
        path: Routes.welcome,
        builder: (_, _) => const WelcomeScreen(),
        routes: [
          GoRoute(
            path: 'profil',
            builder: (_, _) => const ProfileFormScreen(mode: ProfileFormMode.first),
          ),
        ],
      ),
      GoRoute(
        path: Routes.picker,
        builder: (_, _) => const ProfilePickerScreen(),
        routes: [
          GoRoute(
            path: 'nouveau',
            builder: (_, _) => const ProfileFormScreen(mode: ProfileFormMode.fromPicker),
          ),
          GoRoute(
            path: ':id/code',
            builder: (_, state) => UnlockScreen(profileId: state.pathParameters['id']!),
          ),
        ],
      ),
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => HomeShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [GoRoute(path: Routes.home, builder: (_, _) => const HomeScreen())],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.expenses,
                builder: (_, _) => const ExpensesScreen(),
                routes: [
                  fullScreen('noter', (_) => const OperationScreen()),
                  fullScreen('operations/:id', (s) => OperationScreen(operationId: s.pathParameters['id'])),
                  fullScreen(
                    'comptes',
                    (_) => const AccountsScreen(),
                    routes: [
                      fullScreen(
                        'nouveau',
                        (s) => AccountFormScreen(returnsSelection: s.extra == AccountFormScreen.pickExtra),
                      ),
                      fullScreen(':id', (s) => AccountFormScreen(accountId: s.pathParameters['id'])),
                    ],
                  ),
                  fullScreen(
                    'categories',
                    (_) => const CategoriesScreen(),
                    routes: [
                      fullScreen('nouvelle', (_) => const CategoryFormScreen()),
                      fullScreen(':id', (s) => CategoryFormScreen(categoryId: s.pathParameters['id'])),
                    ],
                  ),
                  fullScreen(
                    'budgets',
                    (_) => const BudgetsScreen(),
                    routes: [fullScreen(':id', (s) => BudgetFormScreen(categoryId: s.pathParameters['id']!))],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: Routes.sport, builder: (_, _) => const ComingSoonScreen.sport())],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.settings,
                builder: (_, _) => const SettingsScreen(),
                routes: [
                  GoRoute(
                    path: 'profil',
                    builder: (_, _) => const ProfileFormScreen(mode: ProfileFormMode.edit),
                  ),
                  GoRoute(
                    path: 'verrou',
                    builder: (_, _) => const LockSettingsScreen(),
                    routes: [GoRoute(path: 'code', builder: (_, _) => const SetPinScreen())],
                  ),
                  GoRoute(path: 'sauvegarde', builder: (_, _) => const BackupScreen()),
                  GoRoute(
                    path: 'nouveau-membre',
                    builder: (_, _) => const ProfileFormScreen(mode: ProfileFormMode.fromSettings),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );

  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../domain/expense_kinds.dart';
import '../domain/expenses.dart';

/// Identifiant du profil ouvert : ne change pas quand on renomme le profil.
final activeProfileIdProvider = Provider<String?>((ref) => ref.watch(activeProfileProvider.select((p) => p?.id)));

/// Kit de départ du profil, posé à sa première visite des dépenses.
final expensesSetupProvider = FutureProvider.family<void, String>(
  (ref, profileId) => ref.watch(expensesRepositoryProvider).ensureStarterKit(profileId),
);

/// Les comptes du profil ouvert, avec leur solde.
final accountsProvider = StreamProvider<List<Account>>((ref) async* {
  final profileId = ref.watch(activeProfileIdProvider);
  if (profileId == null) {
    yield const [];
    return;
  }
  await ref.watch(expensesSetupProvider(profileId).future);
  yield* ref.watch(expensesRepositoryProvider).watchAccounts(profileId);
});

/// Les catégories du profil ouvert ; toutes si [kind] est `null`.
final categoriesProvider = StreamProvider.family<List<Category>, CategoryKind?>((ref, kind) async* {
  final profileId = ref.watch(activeProfileIdProvider);
  if (profileId == null) {
    yield const [];
    return;
  }
  await ref.watch(expensesSetupProvider(profileId).future);
  yield* ref.watch(expensesRepositoryProvider).watchCategories(profileId, kind: kind);
});

/// Le mois affiché (premier jour, heure locale). On ne va pas au-delà du mois en cours.
class SelectedMonth extends Notifier<DateTime> {
  @override
  DateTime build() => _thisMonth();

  static DateTime _thisMonth() {
    final now = DateTime.now();
    return DateTime(now.year, now.month);
  }

  bool get isCurrent => state == _thisMonth();

  void previous() => state = DateTime(state.year, state.month - 1);

  void next() {
    if (!isCurrent) state = DateTime(state.year, state.month + 1);
  }
}

final selectedMonthProvider = NotifierProvider<SelectedMonth, DateTime>(SelectedMonth.new);

/// Les opérations du mois affiché, groupées par jour.
final monthViewProvider = StreamProvider<MonthView>((ref) async* {
  final profileId = ref.watch(activeProfileIdProvider);
  final month = ref.watch(selectedMonthProvider);
  if (profileId == null) {
    yield MonthView(month: month, entries: const []);
    return;
  }
  await ref.watch(expensesSetupProvider(profileId).future);
  final (from, to) = MonthView.bounds(month);
  yield* ref
      .watch(expensesRepositoryProvider)
      .watchOperations(profileId, from: from, to: to)
      .map((entries) => MonthView(month: month, entries: entries));
});

/// Le profil a-t-il déjà noté une opération ? Sa devise est alors figée.
final hasOperationsProvider = FutureProvider.autoDispose.family<bool, String>(
  (ref, profileId) => ref.watch(expensesRepositoryProvider).hasOperations(profileId),
);

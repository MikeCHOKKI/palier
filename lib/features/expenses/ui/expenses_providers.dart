import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucid_core_flutter/lucid_core_flutter.dart' show LucidPrivacyController;

import '../../../app/providers.dart';
import '../domain/budgets.dart';
import '../domain/expense_kinds.dart';
import '../domain/expenses.dart';
import '../domain/recurring.dart';

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

/// L'œil des montants d'un profil, retenu sur ce téléphone : un réglage
/// d'affichage, pas une donnée du profil (il ne part pas dans les sauvegardes).
final amountsPrivacyProvider = Provider.family<LucidPrivacyController, String>((ref, profileId) {
  final preferences = ref.watch(preferencesProvider);
  final key = 'palier.amountsHidden.$profileId';
  final controller = LucidPrivacyController(hidden: preferences.getBool(key) ?? false);
  controller.addListener(() => preferences.setBool(key, controller.hidden));
  ref.onDispose(controller.dispose);
  return controller;
});

/// Le mois affiché (premier jour, heure locale). On ne va pas au-delà du mois en cours.
class SelectedMonth extends Notifier<DateTime> {
  @override
  DateTime build() => _thisMonth();

  DateTime _thisMonth() {
    final now = ref.read(clockProvider)();
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

/// Les plafonds du profil ouvert.
final budgetsProvider = StreamProvider<List<Budget>>((ref) async* {
  final profileId = ref.watch(activeProfileIdProvider);
  if (profileId == null) {
    yield const [];
    return;
  }
  await ref.watch(expensesSetupProvider(profileId).future);
  yield* ref.watch(expensesRepositoryProvider).watchBudgets(profileId);
});

/// Les budgets du mois affiché : chaque plafond face à ses dépenses, et la
/// prévision si c'est le mois en cours.
final budgetMonthProvider = Provider<AsyncValue<BudgetMonth>>((ref) {
  final budgets = ref.watch(budgetsProvider);
  final month = ref.watch(monthViewProvider);
  final recurrings = ref.watch(recurringsProvider);
  if (budgets.hasError) return AsyncValue.error(budgets.error!, budgets.stackTrace!);
  if (month.hasError) return AsyncValue.error(month.error!, month.stackTrace!);
  if (recurrings.hasError) return AsyncValue.error(recurrings.error!, recurrings.stackTrace!);
  if (!budgets.hasValue || !month.hasValue || !recurrings.hasValue) return const AsyncValue.loading();
  final view = month.requireValue;
  return AsyncValue.data(
    BudgetMonth(
      month: view.month,
      now: ref.watch(clockProvider)(),
      budgets: budgets.requireValue,
      entries: [for (final day in view.days) ...day.entries],
      recurrings: recurrings.requireValue,
    ),
  );
});

/// Les récurrences du profil ouvert, avec leurs échéances réglées ou passées.
final recurringsProvider = StreamProvider<List<Recurring>>((ref) async* {
  final profileId = ref.watch(activeProfileIdProvider);
  if (profileId == null) {
    yield const [];
    return;
  }
  await ref.watch(expensesSetupProvider(profileId).future);
  yield* ref.watch(expensesRepositoryProvider).watchRecurrings(profileId);
});

/// Les échéances arrivées et pas encore réglées, la plus ancienne d'abord.
final duesProvider = Provider<List<Due>>((ref) {
  final recurrings = ref.watch(recurringsProvider).value ?? const <Recurring>[];
  return duesUntil(recurrings, ref.watch(clockProvider)());
});

/// Ce que les échéances encore en attente d'ici la fin du mois changeront aux
/// comptes ; `null` s'il n'y en a pas.
final pendingNetProvider = Provider<int?>((ref) {
  final recurrings = ref.watch(recurringsProvider).value ?? const <Recurring>[];
  return pendingNetUntilMonthEnd(recurrings, ref.watch(clockProvider)());
});

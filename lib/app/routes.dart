import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/profiles/domain/profile.dart';
import 'providers.dart';

/// Chemins de l'application.
abstract final class Routes {
  static const loading = '/chargement';
  static const welcome = '/bienvenue';
  static const welcomeProfile = '/bienvenue/profil';
  static const picker = '/profils';
  static const pickerNew = '/profils/nouveau';
  static String unlock(String profileId) => '/profils/$profileId/code';

  static const home = '/accueil';
  static const expenses = '/depenses';
  static const expensesNew = '/depenses/noter';
  static String expensesOperation(String id) => '/depenses/operations/$id';
  static const expensesAccounts = '/depenses/comptes';
  static const expensesAccountNew = '/depenses/comptes/nouveau';
  static String expensesAccount(String id) => '/depenses/comptes/$id';
  static const expensesCategories = '/depenses/categories';
  static const expensesCategoryNew = '/depenses/categories/nouvelle';
  static String expensesCategory(String id) => '/depenses/categories/$id';
  static const expensesBudgets = '/depenses/budgets';
  static String expensesBudget(String categoryId) => '/depenses/budgets/$categoryId';
  static const expensesRecurrings = '/depenses/recurrentes';
  static const expensesRecurringNew = '/depenses/recurrentes/nouvelle';
  static String expensesRecurring(String id) => '/depenses/recurrentes/$id';
  static const expensesTontines = '/depenses/tontines';
  static const expensesTontineNew = '/depenses/tontines/nouvelle';
  static String expensesTontine(String id) => '/depenses/tontines/$id';
  static const expensesLoans = '/depenses/prets';
  static const expensesLoanNew = '/depenses/prets/nouveau';
  static String expensesLoan(String id) => '/depenses/prets/$id';

  /// Régler l'échéance [day] (« 2026-11-05 ») d'une récurrence.
  static String expensesDue(String recurringId, String day) => '/depenses/echeances/$recurringId/$day';
  static const sport = '/sport';
  static const settings = '/reglages';
  static const settingsProfile = '/reglages/profil';
  static const settingsLock = '/reglages/verrou';
  static const settingsLockCode = '/reglages/verrou/code';
  static const settingsBackup = '/reglages/sauvegarde';
  static const settingsNewMember = '/reglages/nouveau-membre';
}

/// Où envoyer la personne, selon les profils et la session ; `null` = rester.
///
/// Fonction pure, testée seule : toute la logique d'accès est ici, pas dans
/// les écrans.
String? resolveRedirect({
  required AsyncValue<List<Profile>> profiles,
  required Session session,
  required String location,
}) {
  String? goTo(String target) => location == target ? null : target;

  if (!profiles.hasValue) return goTo(Routes.loading);
  final list = profiles.requireValue;

  if (list.isEmpty) {
    return location == Routes.welcome || location == Routes.welcomeProfile ? null : Routes.welcome;
  }

  Profile? byId(String? id) {
    for (final profile in list) {
      if (profile.id == id) return profile;
    }
    return null;
  }

  final active = byId(session.activeProfileId);
  if (active == null) {
    if (location.startsWith(Routes.picker)) return null;
    final last = byId(session.lastProfileId);
    return last != null && last.hasPin ? Routes.unlock(last.id) : Routes.picker;
  }

  final outsideApp =
      location == Routes.loading || location.startsWith(Routes.welcome) || location.startsWith(Routes.picker);
  if (outsideApp) return Routes.home;
  if (location.startsWith(Routes.expenses) && !active.expensesEnabled) return Routes.home;
  if (location.startsWith(Routes.sport) && !active.sportEnabled) return Routes.home;
  return null;
}

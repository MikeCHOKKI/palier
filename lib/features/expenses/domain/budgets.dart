import 'package:flutter/foundation.dart';

import 'expense_kinds.dart';
import 'expenses.dart';
import 'recurring.dart';

/// Le plafond mensuel d'une catégorie de dépenses.
@immutable
class Budget {
  const Budget({
    required this.categoryId,
    required this.categoryName,
    required this.categoryIcon,
    required this.amount,
  });

  final String categoryId;
  final String categoryName;
  final String categoryIcon;

  /// Par mois, en unités mineures.
  final int amount;

  @override
  bool operator ==(Object other) =>
      other is Budget &&
      other.categoryId == categoryId &&
      other.categoryName == categoryName &&
      other.categoryIcon == categoryIcon &&
      other.amount == amount;

  @override
  int get hashCode => Object.hash(categoryId, categoryName, categoryIcon, amount);
}

/// Le rythme des dépenses du mois en cours, et où il mène.
///
/// La prévision suit le rythme depuis le 1er du mois (choix validé par Mike le
/// 10/11) plutôt que la moyenne des mois passés : il n'y a encore qu'un mois de
/// données. [BudgetMonth] en retire les opérations récurrentes, connues
/// d'avance : un loyer payé le 1er ne se prolonge pas au rythme du mois.
abstract final class Pace {
  /// Avant ce jour du mois, deux ou trois achats suffiraient à fausser la
  /// prévision : on n'en donne pas.
  static const int firstDay = 5;

  /// Dépense attendue à la fin du mois, ou `null` si [month] n'est pas le mois
  /// de [now] ou s'il est trop tôt.
  static int? project({required int spent, required DateTime month, required DateTime now}) {
    final day = _dayOf(month, now);
    if (day == null) return null;
    return (spent * _daysIn(month) / day).round();
  }

  /// Jour du mois où [limit] sera atteint à ce rythme ; `null` s'il est déjà
  /// atteint, s'il ne le sera pas ce mois-ci ou s'il est trop tôt pour le dire.
  static int? reachDay({required int spent, required int limit, required DateTime month, required DateTime now}) {
    final day = _dayOf(month, now);
    if (day == null || spent <= 0 || spent >= limit) return null;
    final reach = (limit * day / spent).ceil();
    return reach <= _daysIn(month) ? reach : null;
  }

  static int? _dayOf(DateTime month, DateTime now) {
    if (now.year != month.year || now.month != month.month || now.day < firstDay) return null;
    return now.day;
  }

  static int _daysIn(DateTime month) => DateTime(month.year, month.month + 1, 0).day;
}

/// Un plafond et ce qu'il a coûté dans le mois.
@immutable
class BudgetLine {
  const BudgetLine({required this.budget, required this.spent, this.projected, this.reachDay});

  final Budget budget;
  final int spent;

  /// Voir [Pace.project] ; `null` hors du mois en cours.
  final int? projected;

  /// Voir [Pace.reachDay].
  final int? reachDay;

  double get ratio => spent / budget.amount;
}

/// Une catégorie sans plafond qui a coûté quelque chose ce mois-ci.
@immutable
class UnbudgetedSpend {
  const UnbudgetedSpend({required this.categoryId, required this.categoryName, this.categoryIcon, required this.spent});

  final String? categoryId;
  final String categoryName;
  final String? categoryIcon;
  final int spent;
}

/// Les budgets d'un mois : chaque plafond face à ses dépenses, les plus
/// entamés d'abord, puis ce qui a été dépensé hors plafond.
///
/// Les totaux ([limit], [spent], [projected]) ne portent que sur les catégories
/// plafonnées : comparer toutes les dépenses à quelques plafonds annoncerait
/// un dépassement qui n'en est pas un.
@immutable
class BudgetMonth {
  ///
  /// La prévision d'une catégorie prolonge seulement ses dépenses libres, puis
  /// ajoute ses dépenses récurrentes : celles déjà réglées et celles encore
  /// attendues dans le mois ([recurrings]).
  factory BudgetMonth({
    required DateTime month,
    required DateTime now,
    required List<Budget> budgets,
    required List<OperationEntry> entries,
    List<Recurring> recurrings = const [],
  }) {
    final spentBy = <String?, int>{};
    final fixedBy = <String?, int>{};
    final names = <String?, (String, String?)>{};
    for (final e in entries.where((e) => e.kind == OperationKind.expense)) {
      spentBy.update(e.categoryId, (sum) => sum + e.amount, ifAbsent: () => e.amount);
      if (e.recurrenceId != null) fixedBy.update(e.categoryId, (sum) => sum + e.amount, ifAbsent: () => e.amount);
      names[e.categoryId] ??= (e.categoryName ?? '', e.categoryIcon);
    }

    final budgeted = {for (final b in budgets) b.categoryId};
    var freeTotal = 0;
    var knownTotal = 0;
    final lines = [
      for (final b in budgets)
        () {
          final spent = spentBy[b.categoryId] ?? 0;
          final fixed = fixedBy[b.categoryId] ?? 0;
          final known = fixed + pendingExpenseIn(recurrings, b.categoryId, month);
          freeTotal += spent - fixed;
          knownTotal += known;
          final free = Pace.project(spent: spent - fixed, month: month, now: now);
          return BudgetLine(
            budget: b,
            spent: spent,
            projected: free == null ? null : free + known,
            reachDay: Pace.reachDay(spent: spent - fixed, limit: b.amount - known, month: month, now: now),
          );
        }(),
    ]..sort((a, b) => b.ratio.compareTo(a.ratio));

    final outside = [
      for (final MapEntry(key: id, value: spent) in spentBy.entries)
        if (!budgeted.contains(id))
          UnbudgetedSpend(categoryId: id, categoryName: names[id]!.$1, categoryIcon: names[id]!.$2, spent: spent),
    ]..sort((a, b) => b.spent.compareTo(a.spent));

    final free = Pace.project(spent: freeTotal, month: month, now: now);
    return BudgetMonth._(
      month: month,
      lines: List.unmodifiable(lines),
      outside: List.unmodifiable(outside),
      projected: free == null ? null : free + knownTotal,
    );
  }

  const BudgetMonth._({required this.month, required this.lines, required this.outside, required this.projected});

  final DateTime month;
  final List<BudgetLine> lines;
  final List<UnbudgetedSpend> outside;

  /// Dépense attendue en fin de mois dans les catégories plafonnées.
  final int? projected;

  bool get isEmpty => lines.isEmpty;
  int get limit => lines.fold(0, (sum, l) => sum + l.budget.amount);
  int get spent => lines.fold(0, (sum, l) => sum + l.spent);
  int get outsideSpent => outside.fold(0, (sum, o) => sum + o.spent);
}

/// Ce qu'il faut signaler après une dépense dans une catégorie plafonnée.
enum BudgetAlert {
  /// 80 % du plafond franchis.
  nearing,

  /// Plafond atteint ou dépassé.
  reached,
}

/// Part du plafond qui déclenche [BudgetAlert.nearing].
const double budgetNearingAt = 0.8;

/// L'alerte à donner quand une catégorie passe de [before] à [after] ; `null`
/// si aucun seuil n'a été franchi par cette dépense (on ne répète pas).
BudgetAlert? budgetAlert({required int before, required int after, required int limit}) {
  if (before < limit && after >= limit) return BudgetAlert.reached;
  final nearing = limit * budgetNearingAt;
  if (before < nearing && after >= nearing) return BudgetAlert.nearing;
  return null;
}

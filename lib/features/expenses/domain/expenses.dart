import 'package:flutter/foundation.dart';

import 'expense_kinds.dart';

/// L'argent dont on dispose : la somme des comptes, sans les tontines ni les
/// prêts. Leur solde est une créance ou une dette (ce qu'on a avancé au groupe,
/// ce qu'on nous doit, ce qu'on doit), pas de l'argent en main : l'ajouter
/// gonflait le total.
int availableBalance(Iterable<Account> accounts) => accounts
    .where((a) => a.kind != AccountKind.tontine && a.kind != AccountKind.loan)
    .fold(0, (sum, a) => sum + a.balance);

/// Un compte et son solde du moment, en unités mineures.
@immutable
class Account {
  const Account({
    required this.id,
    required this.name,
    required this.kind,
    required this.openingBalance,
    required this.balance,
    this.goal,
  });

  final String id;
  final String name;
  final AccountKind kind;
  final int openingBalance;
  final int balance;

  /// Somme visée par un compte d'épargne ; `null` sans objectif chiffré.
  final int? goal;

  /// Part de l'objectif atteinte, de 0 à 1 (au-delà quand on l'a dépassé) ;
  /// `null` sans objectif. Un solde négatif compte pour zéro.
  double? get goalProgress {
    final target = goal;
    if (target == null) return null;
    return (balance < 0 ? 0 : balance) / target;
  }

  @override
  bool operator ==(Object other) =>
      other is Account &&
      other.id == id &&
      other.name == name &&
      other.kind == kind &&
      other.openingBalance == openingBalance &&
      other.balance == balance &&
      other.goal == goal;

  @override
  int get hashCode => Object.hash(id, name, kind, openingBalance, balance, goal);
}

@immutable
class AccountDraft {
  /// L'objectif ne se garde que pour un compte d'épargne : passer un compte
  /// d'épargne en compte courant efface son objectif.
  const AccountDraft({required this.name, this.kind = AccountKind.cash, this.openingBalance = 0, int? goal})
    : goal = kind == AccountKind.savings ? goal : null;

  final String name;
  final AccountKind kind;
  final int openingBalance;
  final int? goal;

  static const int maxNameLength = 40;
}

@immutable
class Category {
  const Category({required this.id, required this.name, required this.kind, required this.icon});

  final String id;
  final String name;
  final CategoryKind kind;

  /// Clé d'icône (voir `category_icons.dart`).
  final String icon;

  @override
  bool operator ==(Object other) =>
      other is Category && other.id == id && other.name == name && other.kind == kind && other.icon == icon;

  @override
  int get hashCode => Object.hash(id, name, kind, icon);
}

@immutable
class CategoryDraft {
  const CategoryDraft({required this.name, required this.kind, required this.icon});

  final String name;
  final CategoryKind kind;
  final String icon;

  static const int maxNameLength = 32;
}

/// Une opération telle que la liste l'affiche : noms du compte et de la
/// catégorie compris, même s'ils ont été supprimés depuis.
@immutable
class OperationEntry {
  const OperationEntry({
    required this.id,
    required this.kind,
    required this.amount,
    required this.occurredAt,
    required this.accountId,
    required this.accountName,
    this.toAccountId,
    this.toAccountName,
    this.categoryId,
    this.categoryName,
    this.categoryIcon,
    this.note,
    this.recurrenceId,
    this.dueOn,
  });

  final String id;
  final OperationKind kind;

  /// Toujours positif ; voir [signedAmount].
  final int amount;
  final DateTime occurredAt;
  final String accountId;
  final String accountName;
  final String? toAccountId;
  final String? toAccountName;
  final String? categoryId;
  final String? categoryName;
  final String? categoryIcon;
  final String? note;

  /// La récurrence dont l'opération règle une échéance, et cette échéance.
  final String? recurrenceId;
  final DateTime? dueOn;

  /// Effet sur l'argent du foyer : négatif pour une dépense, nul pour un
  /// virement (l'argent change seulement de compte).
  int get signedAmount => switch (kind) {
    OperationKind.expense => -amount,
    OperationKind.income => amount,
    OperationKind.transfer => 0,
  };

  OperationDraft toDraft() => OperationDraft(
    kind: kind,
    amount: amount,
    accountId: accountId,
    toAccountId: toAccountId,
    categoryId: categoryId,
    note: note,
    occurredAt: occurredAt,
  );
}

/// Pourquoi une opération ne peut pas encore être enregistrée.
enum OperationProblem { noAmount, noAccount, noCategory, noTargetAccount, sameAccount }

@immutable
class OperationDraft {
  const OperationDraft({
    required this.kind,
    required this.amount,
    required this.accountId,
    required this.occurredAt,
    this.toAccountId,
    this.categoryId,
    this.note,
  });

  final OperationKind kind;
  final int amount;
  final String? accountId;
  final String? toAccountId;
  final String? categoryId;
  final String? note;
  final DateTime occurredAt;

  static const int maxNoteLength = 120;

  /// Le premier problème à corriger, ou `null` si tout est prêt.
  OperationProblem? get problem {
    if (amount <= 0) return OperationProblem.noAmount;
    if (accountId == null) return OperationProblem.noAccount;
    if (kind == OperationKind.transfer) {
      if (toAccountId == null) return OperationProblem.noTargetAccount;
      if (toAccountId == accountId) return OperationProblem.sameAccount;
      return null;
    }
    return categoryId == null ? OperationProblem.noCategory : null;
  }

  /// Note nettoyée : `null` si elle est vide.
  String? get cleanNote {
    final trimmed = note?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }
}

/// Les opérations d'un même jour, et ce qu'elles ont fait sortir et entrer.
@immutable
class DayGroup {
  const DayGroup({required this.day, required this.entries});

  /// Le jour, à minuit, en heure locale.
  final DateTime day;
  final List<OperationEntry> entries;

  int get spent => entries.where((e) => e.kind == OperationKind.expense).fold(0, (sum, e) => sum + e.amount);
  int get received => entries.where((e) => e.kind == OperationKind.income).fold(0, (sum, e) => sum + e.amount);
}

/// Un mois : ses opérations groupées par jour (le plus récent d'abord) et ses totaux.
@immutable
class MonthView {
  MonthView({required this.month, required List<OperationEntry> entries}) : days = groupByDay(entries);

  /// Premier jour du mois, en heure locale.
  final DateTime month;
  final List<DayGroup> days;

  int get spent => days.fold(0, (sum, d) => sum + d.spent);
  int get received => days.fold(0, (sum, d) => sum + d.received);
  bool get isEmpty => days.isEmpty;

  /// Bornes du mois en UTC, [début ; fin[, pour la requête.
  static (DateTime, DateTime) bounds(DateTime month) {
    final start = DateTime(month.year, month.month);
    final end = DateTime(month.year, month.month + 1);
    return (start.toUtc(), end.toUtc());
  }
}

/// Groupe des opérations par jour local, en gardant leur ordre (le plus récent d'abord).
List<DayGroup> groupByDay(List<OperationEntry> entries) {
  final groups = <DayGroup>[];
  DateTime? current;
  var bucket = <OperationEntry>[];
  for (final entry in entries) {
    final local = entry.occurredAt.toLocal();
    final day = DateTime(local.year, local.month, local.day);
    if (current != day) {
      if (current != null) groups.add(DayGroup(day: current, entries: List.unmodifiable(bucket)));
      current = day;
      bucket = [];
    }
    bucket.add(entry);
  }
  if (current != null) groups.add(DayGroup(day: current, entries: List.unmodifiable(bucket)));
  return List.unmodifiable(groups);
}

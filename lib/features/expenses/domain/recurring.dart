import 'package:flutter/foundation.dart';
import 'package:lucid_core_flutter/lucid_core_flutter.dart' show LucidRecurrence, LucidRecurrenceUnit;

import 'expense_kinds.dart';
import 'expenses.dart';

/// Un jour du calendrier en texte, tel qu'en base : « 2026-11-05 ».
String dayKey(DateTime day) =>
    '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';

/// L'inverse de [dayKey] : le jour à minuit, heure locale.
DateTime parseDayKey(String key) {
  final parts = key.split('-');
  return DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
}

/// Le jour local d'un instant, à minuit.
DateTime localDay(DateTime moment) {
  final local = moment.toLocal();
  return DateTime(local.year, local.month, local.day);
}

extension RepeatUnitRule on RepeatUnit {
  LucidRecurrenceUnit get lucid => LucidRecurrenceUnit.values.byName(name);
}

extension LucidUnitRepeat on LucidRecurrenceUnit {
  RepeatUnit get repeat => RepeatUnit.values.byName(name);
}

/// Une opération qui revient, avec les noms de ses comptes et de sa catégorie,
/// et les échéances déjà réglées ou passées.
@immutable
class Recurring {
  const Recurring({
    required this.id,
    required this.kind,
    required this.amount,
    required this.accountId,
    required this.accountName,
    required this.rule,
    required this.dueFrom,
    this.toAccountId,
    this.toAccountName,
    this.categoryId,
    this.categoryName,
    this.categoryIcon,
    this.note,
    this.settled = const {},
  });

  final String id;
  final OperationKind kind;
  final int amount;
  final String accountId;
  final String accountName;
  final String? toAccountId;
  final String? toAccountName;
  final String? categoryId;
  final String? categoryName;
  final String? categoryIcon;
  final String? note;
  final LucidRecurrence rule;

  /// Les échéances comptent à partir de ce jour (voir la table `recurrences`).
  final DateTime dueFrom;

  /// Les échéances déjà réglées par une opération, ou passées.
  final Set<DateTime> settled;

  /// Ce qui la nomme dans une liste : la note, sinon la catégorie, sinon le virement.
  String title(String transferLabel) => note ?? categoryName ?? transferLabel;

  /// Effet sur l'argent du foyer, comme [OperationEntry.signedAmount].
  int get signedAmount => switch (kind) {
    OperationKind.expense => -amount,
    OperationKind.income => amount,
    OperationKind.transfer => 0,
  };

  /// Les échéances de [from] à [to] qui attendent encore d'être réglées ou passées.
  List<DateTime> pendingBetween(DateTime from, DateTime to) {
    final start = from.isAfter(dueFrom) ? from : dueFrom;
    return [
      for (final day in rule.between(start, to))
        if (!settled.contains(day)) day,
    ];
  }

  /// La prochaine échéance à venir, le jour [today] compris ; `null` si elle est finie.
  DateTime? nextFrom(DateTime today) {
    for (var day = rule.nextOnOrAfter(today); day != null; day = rule.nextOnOrAfter(day.add(const Duration(days: 1)))) {
      if (!settled.contains(day)) return day;
    }
    return null;
  }

  OperationDraft draftFor(DateTime occurredAt) => OperationDraft(
    kind: kind,
    amount: amount,
    accountId: accountId,
    toAccountId: toAccountId,
    categoryId: categoryId,
    note: note,
    occurredAt: occurredAt,
  );

  RecurringDraft toDraft() => RecurringDraft(
    kind: kind,
    amount: amount,
    accountId: accountId,
    toAccountId: toAccountId,
    categoryId: categoryId,
    note: note,
    rule: rule,
  );
}

/// Une récurrence à créer ou modifier : les champs d'une opération, sans date,
/// et sa règle.
@immutable
class RecurringDraft {
  const RecurringDraft({
    required this.kind,
    required this.amount,
    required this.accountId,
    required this.rule,
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
  final LucidRecurrence rule;

  /// Les mêmes exigences qu'une opération.
  OperationProblem? get problem => asOperation.problem;

  String? get cleanNote => asOperation.cleanNote;

  OperationDraft get asOperation => OperationDraft(
    kind: kind,
    amount: amount,
    accountId: accountId,
    toAccountId: toAccountId,
    categoryId: categoryId,
    note: note,
    occurredAt: rule.start,
  );

  /// Une opération notée avec « Répéter » : elle devient la première échéance.
  factory RecurringDraft.fromOperation(OperationDraft draft, LucidRecurrence rule) => RecurringDraft(
    kind: draft.kind,
    amount: draft.amount,
    accountId: draft.accountId,
    toAccountId: draft.toAccountId,
    categoryId: draft.categoryId,
    note: draft.note,
    rule: rule.copyWith(start: localDay(draft.occurredAt)),
  );
}

/// Une échéance à régler ou passer.
@immutable
class Due {
  const Due({required this.recurring, required this.day});

  final Recurring recurring;
  final DateTime day;

  @override
  bool operator ==(Object other) => other is Due && other.recurring.id == recurring.id && other.day == day;

  @override
  int get hashCode => Object.hash(recurring.id, day);
}

/// Les échéances arrivées jusqu'à [today] compris et pas encore réglées, la plus
/// ancienne d'abord.
List<Due> duesUntil(List<Recurring> recurrings, DateTime today) {
  final day = localDay(today);
  final dues = [
    for (final r in recurrings)
      for (final d in r.pendingBetween(r.dueFrom, day)) Due(recurring: r, day: d),
  ];
  dues.sort((a, b) => a.day.compareTo(b.day));
  return dues;
}

/// Ce que les échéances encore en attente jusqu'à la fin du mois de [today]
/// (retards compris) changeront à l'argent du foyer ; `null` s'il n'y en a pas.
int? pendingNetUntilMonthEnd(List<Recurring> recurrings, DateTime today) {
  final day = localDay(today);
  final monthEnd = DateTime(day.year, day.month + 1, 0);
  var any = false;
  var net = 0;
  for (final r in recurrings) {
    if (r.kind == OperationKind.transfer) continue;
    final count = r.pendingBetween(r.dueFrom, monthEnd).length;
    if (count == 0) continue;
    any = true;
    net += r.signedAmount * count;
  }
  return any ? net : null;
}

/// Ce que les dépenses récurrentes d'une catégorie doivent encore coûter dans
/// le mois [month] : les échéances du mois non réglées, retards du mois compris.
int pendingExpenseIn(List<Recurring> recurrings, String categoryId, DateTime month) {
  final from = DateTime(month.year, month.month);
  final to = DateTime(month.year, month.month + 1, 0);
  var total = 0;
  for (final r in recurrings) {
    if (r.kind != OperationKind.expense || r.categoryId != categoryId) continue;
    total += r.amount * r.pendingBetween(from, to).length;
  }
  return total;
}

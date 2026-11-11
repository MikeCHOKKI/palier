import 'package:flutter_test/flutter_test.dart';
import 'package:lucid_core_flutter/lucid_core_flutter.dart' show LucidRecurrence, LucidRecurrenceUnit;
import 'package:palier/features/expenses/domain/budgets.dart';
import 'package:palier/features/expenses/domain/expense_kinds.dart';
import 'package:palier/features/expenses/domain/expenses.dart';
import 'package:palier/features/expenses/domain/recurring.dart';

Recurring _recurring(
  String id, {
  int amount = 45000,
  OperationKind kind = OperationKind.expense,
  String? category = 'loyer',
  required DateTime start,
  DateTime? dueFrom,
  LucidRecurrenceUnit unit = LucidRecurrenceUnit.month,
  Set<DateTime> settled = const {},
}) => Recurring(
  id: id,
  kind: kind,
  amount: amount,
  accountId: 'wave',
  accountName: 'Wave',
  categoryId: category,
  categoryName: category,
  rule: LucidRecurrence(unit: unit, start: start),
  dueFrom: dueFrom ?? start,
  settled: settled,
);

OperationEntry _op(int amount, {String category = 'loyer', String? recurrenceId, int day = 3}) => OperationEntry(
  id: '$category-$amount-$day',
  kind: OperationKind.expense,
  amount: amount,
  occurredAt: DateTime(2026, 11, day, 12).toUtc(),
  accountId: 'wave',
  accountName: 'Wave',
  categoryId: category,
  categoryName: category,
  recurrenceId: recurrenceId,
);

void main() {
  test('dayKey et parseDayKey', () {
    expect(dayKey(DateTime(2026, 3, 5, 23, 59)), '2026-03-05');
    expect(parseDayKey('2026-03-05'), DateTime(2026, 3, 5));
  });

  group('échéances', () {
    final loyer = _recurring('loyer', start: DateTime(2026, 9, 5), settled: {DateTime(2026, 9, 5)});

    test('celles arrivées et pas réglées, la plus ancienne d’abord', () {
      final transport = _recurring(
        'moto',
        amount: 2000,
        category: 'transport',
        unit: LucidRecurrenceUnit.week,
        start: DateTime(2026, 11, 2),
      );
      final dues = duesUntil([transport, loyer], DateTime(2026, 11, 11, 20));
      expect(
        [for (final d in dues) (d.recurring.id, d.day)],
        [
          ('loyer', DateTime(2026, 10, 5)),
          ('moto', DateTime(2026, 11, 2)),
          ('loyer', DateTime(2026, 11, 5)),
          ('moto', DateTime(2026, 11, 9)),
        ],
      );
    });

    test('rien avant dueFrom : changer la règle n’exhume pas le passé', () {
      final changed = _recurring('loyer', start: DateTime(2026, 1, 5), dueFrom: DateTime(2026, 11, 1));
      expect(duesUntil([changed], DateTime(2026, 11, 11)).map((d) => d.day), [DateTime(2026, 11, 5)]);
    });

    test('la prochaine échéance saute celles déjà réglées', () {
      final paidAhead = _recurring('loyer', start: DateTime(2026, 11, 5), settled: {DateTime(2026, 12, 5)});
      expect(paidAhead.nextFrom(DateTime(2026, 11, 6)), DateTime(2027, 1, 5));
    });

    test('ce qui reste à passer d’ici la fin du mois, retards compris', () {
      final salaire = _recurring('salaire', amount: 150000, kind: OperationKind.income, start: DateTime(2026, 11, 28));
      final epargne = _recurring('coffre', kind: OperationKind.transfer, category: null, start: DateTime(2026, 11, 20));
      // Loyer d'octobre et de novembre en attente : -90 000 ; salaire du 28 : +150 000.
      expect(pendingNetUntilMonthEnd([loyer, salaire, epargne], DateTime(2026, 11, 11)), 60000);
      expect(pendingNetUntilMonthEnd([epargne], DateTime(2026, 11, 11)), isNull);
    });

    test('une opération notée avec « Répéter » est la première échéance', () {
      final draft = RecurringDraft.fromOperation(
        OperationDraft(
          kind: OperationKind.expense,
          amount: 45000,
          accountId: 'wave',
          categoryId: 'loyer',
          occurredAt: DateTime(2026, 11, 5, 18, 30),
        ),
        LucidRecurrence(unit: LucidRecurrenceUnit.month, start: DateTime(2026, 1, 1)),
      );
      expect(draft.rule.start, DateTime(2026, 11, 5));
      expect(draft.problem, isNull);
    });
  });

  group('prévision des budgets avec des récurrentes', () {
    const loyerBudget = Budget(categoryId: 'loyer', categoryName: 'Loyer', categoryIcon: 'home', amount: 50000);
    const courses = Budget(categoryId: 'courses', categoryName: 'Courses', categoryIcon: 'basket', amount: 60000);
    final november = DateTime(2026, 11);
    final now = DateTime(2026, 11, 10, 12);

    test('un loyer payé le 3 ne se prolonge pas au rythme du mois', () {
      final month = BudgetMonth(
        month: november,
        now: now,
        budgets: const [loyerBudget],
        entries: [_op(45000, recurrenceId: 'loyer')],
        recurrings: [
          _recurring('loyer', start: DateTime(2026, 11, 3), settled: {DateTime(2026, 11, 3)}),
        ],
      );
      // Sans récurrence, 45 000 en 10 jours feraient 135 000 d'ici le 30.
      expect(month.lines.single.projected, 45000);
      expect(month.projected, 45000);
    });

    test('une échéance à venir dans le mois compte déjà', () {
      final month = BudgetMonth(
        month: november,
        now: now,
        budgets: const [courses],
        entries: [_op(10000, category: 'courses')],
        recurrings: [_recurring('marche', amount: 5000, category: 'courses', start: DateTime(2026, 11, 25))],
      );
      // 10 000 libres en 10 jours : 30 000, plus le marché du 25.
      expect(month.lines.single.projected, 35000);
      // Il reste 55 000 pour les dépenses libres : atteints le 55e jour, pas ce mois-ci.
      expect(month.lines.single.reachDay, isNull);
    });

    test('sans récurrente, la prévision ne change pas', () {
      final month = BudgetMonth(
        month: november,
        now: now,
        budgets: const [courses],
        entries: [_op(21000, category: 'courses')],
      );
      expect(month.projected, Pace.project(spent: 21000, month: november, now: now));
    });
  });
}

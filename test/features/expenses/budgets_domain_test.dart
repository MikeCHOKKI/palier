import 'package:flutter_test/flutter_test.dart';
import 'package:palier/features/expenses/domain/budgets.dart';
import 'package:palier/features/expenses/domain/expense_kinds.dart';
import 'package:palier/features/expenses/domain/expenses.dart';

OperationEntry _op(
  int amount, {
  String? category = 'courses',
  OperationKind kind = OperationKind.expense,
  DateTime? at,
}) => OperationEntry(
  id: '$category-$amount-${at ?? ''}',
  kind: kind,
  amount: amount,
  occurredAt: (at ?? DateTime(2026, 11, 3, 12)).toUtc(),
  accountId: 'especes',
  accountName: 'Espèces',
  categoryId: category,
  categoryName: switch (category) {
    'courses' => 'Courses',
    'transport' => 'Transport',
    _ => 'Divers',
  },
  categoryIcon: 'basket',
);

const _courses = Budget(categoryId: 'courses', categoryName: 'Courses', categoryIcon: 'basket', amount: 60000);
const _transport = Budget(categoryId: 'transport', categoryName: 'Transport', categoryIcon: 'moto', amount: 20000);

void main() {
  final november = DateTime(2026, 11);

  group('Pace.project', () {
    test('suit le rythme depuis le 1er, jusqu’au dernier jour du mois', () {
      // 21 000 en 7 jours : 3 000 par jour, 30 jours en novembre.
      expect(Pace.project(spent: 21000, month: november, now: DateTime(2026, 11, 7, 20)), 90000);
    });

    test('rien avant le 5 : deux ou trois achats fausseraient tout', () {
      expect(Pace.project(spent: 21000, month: november, now: DateTime(2026, 11, 4, 23)), isNull);
      expect(Pace.project(spent: 21000, month: november, now: DateTime(2026, 11, 5)), isNotNull);
    });

    test('rien pour un mois passé : seul le réel compte', () {
      expect(Pace.project(spent: 21000, month: DateTime(2026, 10), now: DateTime(2026, 11, 7)), isNull);
    });

    test('le jour où le plafond sera atteint à ce rythme', () {
      // 3 000 par jour : 60 000 atteints le 20.
      expect(Pace.reachDay(spent: 21000, limit: 60000, month: november, now: DateTime(2026, 11, 7)), 20);
      // Pas atteint ce mois-ci.
      expect(Pace.reachDay(spent: 7000, limit: 60000, month: november, now: DateTime(2026, 11, 7)), isNull);
      // Déjà atteint : rien à annoncer, la jauge le dit.
      expect(Pace.reachDay(spent: 60000, limit: 60000, month: november, now: DateTime(2026, 11, 7)), isNull);
      // Rien dépensé : pas de rythme.
      expect(Pace.reachDay(spent: 0, limit: 60000, month: november, now: DateTime(2026, 11, 7)), isNull);
    });
  });

  group('BudgetMonth', () {
    test('ce que chaque plafond a coûté, et les dépenses hors plafond', () {
      final month = BudgetMonth(
        month: november,
        now: DateTime(2026, 11, 7, 20),
        budgets: const [_courses, _transport],
        entries: [
          _op(12000),
          _op(9000),
          _op(4000, category: 'transport'),
          _op(5000, category: 'divers'),
          _op(150000, category: 'salaire', kind: OperationKind.income),
          _op(20000, category: null, kind: OperationKind.transfer),
        ],
      );

      expect(month.lines.map((l) => (l.budget.categoryName, l.spent)), [('Courses', 21000), ('Transport', 4000)]);
      expect(month.limit, 80000);
      expect(month.spent, 25000);
      expect(month.outside.map((o) => (o.categoryName, o.spent)), [('Divers', 5000)]);
      expect(month.outsideSpent, 5000);

      final courses = month.lines.first;
      expect(courses.projected, 90000);
      expect(courses.reachDay, 20);
      expect(month.projected, Pace.project(spent: 25000, month: november, now: DateTime(2026, 11, 7, 20)));
    });

    test('un plafond sans dépense apparaît à zéro ; les plus entamés d’abord', () {
      final month = BudgetMonth(
        month: november,
        now: DateTime(2026, 11, 7),
        budgets: const [_courses, _transport],
        entries: [_op(18000, category: 'transport')],
      );
      expect(month.lines.map((l) => (l.budget.categoryId, l.spent)), [('transport', 18000), ('courses', 0)]);
    });

    test('sans plafond, le mois est vide', () {
      final month = BudgetMonth(month: november, now: DateTime(2026, 11, 7), budgets: const [], entries: [_op(5000)]);
      expect(month.isEmpty, isTrue);
      expect(month.outsideSpent, 5000);
    });
  });

  group('budgetAlert', () {
    test('prévient en passant 80 %, puis en atteignant le plafond', () {
      expect(budgetAlert(before: 40000, after: 47000, limit: 60000), isNull);
      expect(budgetAlert(before: 40000, after: 48000, limit: 60000), BudgetAlert.nearing);
      expect(budgetAlert(before: 50000, after: 60000, limit: 60000), BudgetAlert.reached);
      // D'un coup de 0 à plus du plafond : on annonce le plus grave.
      expect(budgetAlert(before: 0, after: 70000, limit: 60000), BudgetAlert.reached);
      // Déjà au-delà : on ne répète pas l’alerte à chaque dépense.
      expect(budgetAlert(before: 61000, after: 65000, limit: 60000), isNull);
      expect(budgetAlert(before: 50000, after: 55000, limit: 60000), isNull);
    });
  });
}

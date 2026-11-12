import 'package:flutter_test/flutter_test.dart';
import 'package:palier/features/expenses/domain/expense_kinds.dart';
import 'package:palier/features/expenses/domain/expenses.dart';

OperationEntry entry(String id, OperationKind kind, int amount, DateTime at) =>
    OperationEntry(id: id, kind: kind, amount: amount, occurredAt: at, accountId: 'a', accountName: 'Espèces');

void main() {
  group('OperationDraft.problem', () {
    final at = DateTime(2026, 11, 9);
    OperationDraft draft({
      OperationKind kind = OperationKind.expense,
      int amount = 500,
      String? account = 'a',
      String? to,
      String? category = 'c',
    }) => OperationDraft(
      kind: kind,
      amount: amount,
      accountId: account,
      toAccountId: to,
      categoryId: category,
      occurredAt: at,
    );

    test('une dépense complète est prête', () => expect(draft().problem, isNull));

    test('demande un montant, un compte, puis une catégorie', () {
      expect(draft(amount: 0).problem, OperationProblem.noAmount);
      expect(draft(account: null).problem, OperationProblem.noAccount);
      expect(draft(category: null).problem, OperationProblem.noCategory);
    });

    test('un virement va d’un compte à un autre, sans catégorie', () {
      final transfer = draft(kind: OperationKind.transfer, category: null);
      expect(transfer.problem, OperationProblem.noTargetAccount);
      expect(draft(kind: OperationKind.transfer, to: 'a').problem, OperationProblem.sameAccount);
      expect(draft(kind: OperationKind.transfer, to: 'b', category: null).problem, isNull);
    });

    test('une note vide ne s’enregistre pas', () {
      expect(
        OperationDraft(kind: OperationKind.expense, amount: 1, accountId: 'a', occurredAt: at, note: '  ').cleanNote,
        isNull,
      );
      expect(
        OperationDraft(kind: OperationKind.expense, amount: 1, accountId: 'a', occurredAt: at, note: ' zem ').cleanNote,
        'zem',
      );
    });
  });

  test('un virement ne change pas l’argent du foyer', () {
    final at = DateTime(2026, 11, 9);
    expect(entry('1', OperationKind.expense, 500, at).signedAmount, -500);
    expect(entry('2', OperationKind.income, 500, at).signedAmount, 500);
    expect(entry('3', OperationKind.transfer, 500, at).signedAmount, 0);
  });

  test('groupe par jour local, dans l’ordre, avec les totaux du jour', () {
    final entries = [
      entry('1', OperationKind.expense, 1500, DateTime(2026, 11, 9, 20)),
      entry('2', OperationKind.income, 10000, DateTime(2026, 11, 9, 8)),
      entry('3', OperationKind.transfer, 5000, DateTime(2026, 11, 9, 7)),
      entry('4', OperationKind.expense, 300, DateTime(2026, 11, 7, 12)),
    ];

    final days = groupByDay(entries);

    expect(days.map((d) => d.day), [DateTime(2026, 11, 9), DateTime(2026, 11, 7)]);
    expect(days.first.entries.map((e) => e.id), ['1', '2', '3']);
    expect(days.first.spent, 1500);
    expect(days.first.received, 10000);

    final month = MonthView(month: DateTime(2026, 11), entries: entries);
    expect(month.spent, 1800);
    expect(month.received, 10000);
  });

  test('les bornes d’un mois vont du 1er à minuit au 1er du mois suivant', () {
    final (from, to) = MonthView.bounds(DateTime(2026, 12, 15));
    expect(from, DateTime(2026, 12).toUtc());
    expect(to, DateTime(2027).toUtc());
  });

  test('l’argent disponible : ni les tontines ni les prêts, l’épargne si', () {
    Account account(AccountKind kind, int balance) =>
        Account(id: kind.name, name: kind.name, kind: kind, openingBalance: 0, balance: balance);
    final accounts = [
      account(AccountKind.cash, 10000),
      account(AccountKind.mobileMoney, 50000),
      account(AccountKind.savings, 20000),
      account(AccountKind.tontine, 15000),
      account(AccountKind.loan, -60000),
    ];
    expect(availableBalance(accounts), 80000);
  });
}

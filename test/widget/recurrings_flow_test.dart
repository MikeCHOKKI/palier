import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucid_core_flutter/lucid_core_flutter.dart' show LucidRecurrence, LucidRecurrenceUnit;
import 'package:palier/features/expenses/data/expenses_repository.dart';
import 'package:palier/features/expenses/domain/expense_kinds.dart';
import 'package:palier/features/expenses/domain/money.dart';
import 'package:palier/features/expenses/domain/recurring.dart';
import 'package:palier/features/expenses/ui/amount_pad.dart';
import 'package:palier/features/profiles/domain/profile.dart';

import '../helpers/pump_app.dart';

const _xof = PalierCurrency.xof;

/// Mardi 10 novembre 2026.
final _day = DateTime(2026, 11, 10, 12);

Future<void> _pad(WidgetTester tester, List<String> keys) async {
  for (final key in keys) {
    final inPad = RegExp(r'^\d$').hasMatch(key)
        ? find.descendant(of: find.byType(AmountPad), matching: find.text(key))
        : find.descendant(of: find.byType(AmountPad), matching: find.bySemanticsLabel(key));
    await tester.tap(inPad);
    await tester.pump();
  }
}

Future<TestApp> _openExpenses(WidgetTester tester) async {
  final app = await TestApp.pump(
    tester,
    now: _day,
    seed: (repo) => repo.create(const ProfileDraft(name: 'Ama')),
  );
  await tester.tap(find.text('Dépenses').last);
  await app.settle(tester);
  return app;
}

/// Un transport à 2 000 chaque lundi depuis le 2 : les échéances du 2 et du 9 attendent.
Future<void> _seedWeekly(WidgetTester tester, TestApp app) async {
  await tester.runAsync(() async {
    final repo = ExpensesRepository(app.db);
    final profileId = (await app.profiles.watchAll().first).single.id;
    final account = (await repo.watchAccounts(profileId).first).first;
    final category = (await repo.watchCategories(profileId, kind: CategoryKind.expense).first).first;
    await repo.createRecurring(
      profileId,
      RecurringDraft(
        kind: OperationKind.expense,
        amount: 2000,
        accountId: account.id,
        categoryId: category.id,
        note: 'Zém',
        rule: LucidRecurrence(unit: LucidRecurrenceUnit.week, start: DateTime(2026, 11, 2)),
      ),
    );
  });
  await app.settle(tester);
}

void main() {
  testWidgets('« Revient régulièrement » fait de la dépense une récurrence', (tester) async {
    final app = await _openExpenses(tester);
    await tester.tap(find.text('Noter'));
    await app.settle(tester);
    await _pad(tester, ['4', '5', 'Trois zéros']);
    await tester.tap(find.text('Alimentation'));
    await tester.pump();

    final repeat = find.text('Revient régulièrement');
    await tester.scrollUntilVisible(repeat, 200, scrollable: find.byType(Scrollable).first);
    await tester.tap(repeat);
    await tester.pump();
    expect(find.text('Le 10 de chaque mois'), findsOneWidget);
    expect(find.textContaining('Dès le'), findsNothing, reason: 'le début est la date de la dépense');

    await tester.tap(find.text('Enregistrer la dépense'));
    await app.settle(tester);

    await tester.tap(find.byTooltip('Gérer les dépenses'));
    await app.settle(tester);
    await tester.tap(find.text('Récurrentes').last);
    await app.settle(tester);
    expect(find.text('Le 10 de chaque mois'), findsOneWidget);
    expect(find.text('Espèces'), findsOneWidget);
    expect(find.text('Prochaine : 10 déc.'), findsOneWidget);
    expect(find.text(formatMoney(-45000, _xof, signed: true)), findsOneWidget);
  });

  testWidgets('les échéances se règlent ou se passent d’un geste, et s’annulent', (tester) async {
    final app = await _openExpenses(tester);
    await _seedWeekly(tester, app);

    expect(find.text('À valider'), findsOneWidget);
    expect(find.text('Prévu le 2 nov.'), findsOneWidget);
    expect(find.text('Prévu le 9 nov.'), findsOneWidget);
    expect(find.textContaining('Après les échéances du mois'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Payé : Zém, 2 nov.'));
    await app.settle(tester);
    expect(find.text('Échéance réglée.'), findsOneWidget);
    expect(find.text('Prévu le 2 nov.'), findsNothing);

    await tester.tap(find.bySemanticsLabel('Passer : Zém, 9 nov.'));
    await app.settle(tester);
    expect(find.text('Échéance passée.'), findsOneWidget);
    expect(find.text('À valider'), findsNothing);

    await tester.tap(find.text('Annuler'));
    await app.settle(tester);
    expect(find.text('Prévu le 9 nov.'), findsOneWidget);
  });

  testWidgets('toucher une échéance ouvre la saisie, montant modifiable', (tester) async {
    final app = await _openExpenses(tester);
    await _seedWeekly(tester, app);

    await tester.tap(find.text('Prévu le 2 nov.'));
    await app.settle(tester);
    expect(find.text('Régler l’échéance'), findsOneWidget);
    expect(find.text(AmountEntry.fromMinor(2000, _xof).display), findsOneWidget);

    await _pad(tester, ['Effacer', '5']);
    await tester.tap(find.text('Enregistrer la dépense'));
    await app.settle(tester);
    expect(find.text('Prévu le 2 nov.'), findsNothing);
    expect(find.text('Prévu le 9 nov.'), findsOneWidget);
  });
}

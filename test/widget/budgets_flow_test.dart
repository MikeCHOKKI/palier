import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palier/features/expenses/domain/money.dart';
import 'package:palier/features/expenses/ui/amount_pad.dart';
import 'package:palier/features/profiles/domain/profile.dart';

import '../helpers/pump_app.dart';

const _xof = PalierCurrency.xof;

/// Le 10 : la prévision s'affiche (pas avant le 5), et novembre compte 30 jours.
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

Future<void> _openBudgets(WidgetTester tester, TestApp app) async {
  await tester.tap(find.byTooltip('Comptes, catégories et budgets'));
  await app.settle(tester);
  await tester.tap(find.text('Budgets').last);
  await app.settle(tester);
}

/// Depuis l'écran Budgets : donne un plafond à une catégorie sans plafond.
Future<void> _setBudget(WidgetTester tester, TestApp app, String category, List<String> keys) async {
  await tester.scrollUntilVisible(find.text(category), 200, scrollable: find.byType(Scrollable).last);
  await tester.tap(find.text(category));
  await app.settle(tester);
  await _pad(tester, keys);
  await tester.tap(find.text('Enregistrer le plafond'));
  await app.settle(tester);
}

Future<void> _spend(WidgetTester tester, TestApp app, List<String> keys) async {
  await tester.tap(find.text('Noter'));
  await app.settle(tester);
  await _pad(tester, keys);
  await tester.tap(find.text('Alimentation'));
  await tester.pump();
  await tester.tap(find.text('Enregistrer la dépense'));
  await app.settle(tester);
}

void main() {
  testWidgets('poser un plafond depuis l’écran Budgets', (tester) async {
    final app = await _openExpenses(tester);
    await _openBudgets(tester, app);
    expect(find.text('Aucun plafond pour l’instant'), findsOneWidget);

    await _setBudget(tester, app, 'Alimentation', ['6', '0', 'Trois zéros']);

    expect(find.text('Plafond enregistré.'), findsOneWidget);
    expect(find.text('Aucun plafond pour l’instant'), findsNothing);
    expect(find.text('Reste ${formatMoney(60000, _xof)}'), findsOneWidget);

    // L'onglet Dépenses le résume, et y ramène.
    await tester.tap(find.byType(BackButton));
    await app.settle(tester);
    expect(find.text('Budgets'), findsOneWidget);
    expect(find.text('/ ${formatMoney(60000, _xof)}'), findsOneWidget);
  });

  testWidgets('une dépense prévient à 80 %, puis quand le plafond est dépassé', (tester) async {
    final app = await _openExpenses(tester);
    await _openBudgets(tester, app);
    await _setBudget(tester, app, 'Alimentation', ['1', '0', 'Trois zéros']);
    await tester.tap(find.byType(BackButton));
    await app.settle(tester);

    await _spend(tester, app, ['5', 'Trois zéros']);
    expect(find.text('Dépense enregistrée.'), findsOneWidget, reason: '50 % : rien à signaler');

    await _spend(tester, app, ['3', '5', '0', '0']);
    expect(find.text('Enregistrée · Alimentation à 85 % du plafond'), findsOneWidget);

    await _spend(tester, app, ['2', 'Trois zéros']);
    expect(find.text('Enregistrée · Alimentation : plafond dépassé'), findsOneWidget);

    // Le 10, 10 500 dépensés : 31 500 attendus d'ici le 30.
    expect(find.text('À ce rythme : ${formatMoney(31500, _xof)} d’ici le 30'), findsOneWidget);
    await tester.tap(find.text('Budgets'));
    await app.settle(tester);
    expect(find.text('Dépassé de ${formatMoney(500, _xof)}'), findsOneWidget);
  });

  testWidgets('retirer un plafond se rattrape avec « Annuler »', (tester) async {
    final app = await _openExpenses(tester);
    await _openBudgets(tester, app);
    await _setBudget(tester, app, 'Alimentation', ['6', '0', 'Trois zéros']);

    await tester.ensureVisible(find.text('Alimentation'));
    await app.settle(tester);
    await tester.tap(find.text('Alimentation'));
    await app.settle(tester);
    expect(find.text(AmountEntry.fromMinor(60000, _xof).display), findsOneWidget, reason: 'le pavé reprend le plafond');
    expect(find.text('Enregistrer le plafond').hitTestable(), findsOneWidget, reason: 'aucun message dessus');
    await tester.tap(find.byTooltip('Retirer le plafond'));
    await app.settle(tester);
    expect(find.text('Plafond retiré.'), findsOneWidget);
    expect(find.text('Reste ${formatMoney(60000, _xof)}'), findsNothing);

    await tester.tap(find.text('Annuler'));
    await app.settle(tester);
    expect(find.text('Reste ${formatMoney(60000, _xof)}'), findsOneWidget);
  });

  testWidgets('un plafond vide dit ce qui manque', (tester) async {
    final app = await _openExpenses(tester);
    await _openBudgets(tester, app);
    await tester.tap(find.text('Alimentation'));
    await app.settle(tester);
    await tester.tap(find.text('Enregistrer le plafond'));
    await tester.pump();
    expect(find.text('Indique un montant.'), findsOneWidget);
  });
}

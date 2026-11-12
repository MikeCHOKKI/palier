import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palier/features/expenses/domain/money.dart';
import 'package:palier/features/profiles/domain/profile.dart';

import '../helpers/pump_app.dart';

String _f(int amount) => formatMoney(amount, PalierCurrency.xof);

Finder _field(String key) => find.descendant(of: find.byKey(ValueKey(key)), matching: find.byType(TextFormField));

Future<TestApp> _openLoans(WidgetTester tester) async {
  final app = await TestApp.pump(
    tester,
    now: DateTime(2026, 11, 11, 10),
    seed: (repo) => repo.create(const ProfileDraft(name: 'Ama')),
  );
  await tester.tap(find.text('Dépenses').last);
  await app.settle(tester);
  await tester.tap(find.byTooltip('Gérer les dépenses'));
  await app.settle(tester);
  await tester.tap(find.text('Prêts').last);
  await app.settle(tester);
  return app;
}

Future<void> _tapVisible(WidgetTester tester, TestApp app, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await app.settle(tester);
}

void main() {
  testWidgets('emprunter puis rembourser en deux fois solde le prêt', (tester) async {
    final app = await _openLoans(tester);
    expect(find.text('Aucun prêt en cours'), findsOneWidget);
    await tester.tap(find.text('Noter un prêt'));
    await app.settle(tester);

    await tester.tap(find.text('J’ai emprunté'));
    await app.settle(tester);
    expect(find.text('De qui ?'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).first, 'Koffi');
    await tester.enterText(_field('montant'), '30000');
    await _tapVisible(tester, app, find.text('Enregistrer le prêt'));

    expect(find.text('Prêt enregistré.'), findsOneWidget);
    expect(find.text('Koffi'), findsOneWidget);
    expect(find.text(_f(30000)), findsOneWidget);
    expect(find.textContaining('Tu dois · depuis le 11 nov.'), findsOneWidget);

    await tester.tap(find.text('Koffi'));
    await app.settle(tester);
    expect(find.text('Reste ${_f(30000)}'), findsOneWidget);

    await tester.enterText(_field('remboursement'), '40000');
    await _tapVisible(tester, app, find.text('Noter le remboursement'));
    expect(find.text('C’est plus que ce qui reste dû.'), findsOneWidget);

    await tester.enterText(_field('remboursement'), '10000');
    await _tapVisible(tester, app, find.text('Noter le remboursement'));
    expect(find.text('Reste ${_f(20000)}'), findsOneWidget);
    expect(find.text('${_f(10000)} remboursés sur ${_f(30000)}'), findsOneWidget);

    await _tapVisible(tester, app, find.text('Tout le reste'));
    await _tapVisible(tester, app, find.text('Noter le remboursement'));
    expect(find.text('Soldé'), findsOneWidget);
    expect(find.text('Noter le remboursement'), findsNothing);
  });

  testWidgets('renommer puis annuler, ou valider : la fenêtre se ferme sans erreur', (tester) async {
    final app = await _openLoans(tester);
    await tester.tap(find.text('Noter un prêt'));
    await app.settle(tester);
    await tester.enterText(find.byType(TextFormField).first, 'Koffi');
    await tester.enterText(_field('montant'), '30000');
    await _tapVisible(tester, app, find.text('Enregistrer le prêt'));
    await tester.tap(find.text('Koffi'));
    await app.settle(tester);

    await tester.tap(find.byTooltip('Renommer'));
    await app.settle(tester);
    await tester.enterText(find.byType(TextField).last, 'Koffi A.');
    await tester.tap(find.text('Annuler'));
    await app.settle(tester);
    expect(find.text('Koffi'), findsWidgets);

    await tester.tap(find.byTooltip('Renommer'));
    await app.settle(tester);
    await tester.enterText(find.byType(TextField).last, 'Koffi A.');
    await tester.tap(find.widgetWithText(TextButton, 'Renommer'));
    await app.settle(tester);
    expect(find.text('Koffi A.'), findsWidgets);
  });
}

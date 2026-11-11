import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palier/features/expenses/domain/money.dart';
import 'package:palier/features/profiles/domain/profile.dart';

import '../helpers/pump_app.dart';

// Mercredi 11 novembre 2026, 10 h.
final _now = DateTime(2026, 11, 11, 10);

Future<TestApp> _openTontines(WidgetTester tester) async {
  final app = await TestApp.pump(
    tester,
    now: _now,
    seed: (repo) => repo.create(const ProfileDraft(name: 'Ama')),
  );
  await tester.tap(find.text('Dépenses').last);
  await app.settle(tester);
  await tester.tap(find.byTooltip('Gérer les dépenses'));
  await app.settle(tester);
  await tester.tap(find.text('Tontines').last);
  await app.settle(tester);
  return app;
}

Finder _field(String key) => find.descendant(of: find.byKey(ValueKey(key)), matching: find.byType(TextFormField));

void main() {
  testWidgets('créer une tontine : le résumé annonce la main, la liste suit le tour', (tester) async {
    final app = await _openTontines(tester);
    expect(find.text('Aucune tontine suivie'), findsOneWidget);
    await tester.tap(find.text('Ajouter une tontine'));
    await app.settle(tester);

    await tester.enterText(find.byType(TextFormField).first, 'Marché');
    await tester.enterText(_field('cotisation'), '5000');
    await tester.enterText(_field('membres'), '10');
    await tester.enterText(_field('rang'), '3');
    await app.settle(tester);
    // Chaque semaine depuis aujourd'hui : la main au 3e tour, le 25 novembre.
    expect(find.textContaining('Tu reçois ${formatMoney(50000, PalierCurrency.xof)}'), findsOneWidget);
    expect(find.textContaining('le 25 nov. 2026, au tour 3 sur 10'), findsOneWidget);

    final save = find.text('Enregistrer');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await app.settle(tester);

    expect(find.text('Tontine enregistrée.'), findsOneWidget);
    expect(find.text('Marché'), findsOneWidget);
    expect(find.textContaining('Tour 1 sur 10'), findsOneWidget);
    expect(find.textContaining('ta main le 25 nov.'), findsOneWidget);
  });

  testWidgets('un rang au-delà des membres est refusé', (tester) async {
    final app = await _openTontines(tester);
    await tester.tap(find.text('Ajouter une tontine'));
    await app.settle(tester);
    await tester.enterText(find.byType(TextFormField).first, 'Marché');
    await tester.enterText(_field('cotisation'), '5000');
    await tester.enterText(_field('membres'), '4');
    await tester.enterText(_field('rang'), '7');
    final save = find.text('Enregistrer');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await app.settle(tester);
    expect(find.text('Ton rang va de 1 au nombre de membres.'), findsOneWidget);
  });
}

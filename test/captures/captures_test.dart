@Tags(['captures'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palier/app/theme/palier_accent.dart';
import 'package:palier/features/profiles/data/profiles_repository.dart';
import 'package:palier/features/profiles/domain/profile.dart';

import '../helpers/pump_app.dart';

/// Captures d'écran de docs/captures, au format d'un téléphone (390 × 844).
/// Profils fictifs : aucune donnée réelle.
void main() {
  Future<void> capture(WidgetTester tester, String name) async {
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('../../docs/captures/$name.png'));
  }

  Future<void> family(ProfilesRepository repo) async {
    final ama = await repo.create(const ProfileDraft(name: 'Ama', accent: PalierAccent.cyan));
    await repo.setPin(ama.id, '2468');
    await repo.create(const ProfileDraft(name: 'Kofi', accent: PalierAccent.ambre));
    await repo.create(const ProfileDraft(name: 'Esi', accent: PalierAccent.lilas, isMinor: true));
  }

  testWidgets('bienvenue', (tester) async {
    await TestApp.pump(tester);
    await capture(tester, '01-bienvenue');
  });

  testWidgets('nouveau profil', (tester) async {
    final app = await TestApp.pump(tester);
    await tester.tap(find.text('Créer mon profil'));
    await app.settle(tester);
    await tester.enterText(find.byType(TextFormField), 'Ama');
    await tester.tap(find.bySemanticsLabel('Corail'));
    await app.settle(tester);
    FocusManager.instance.primaryFocus?.unfocus();
    await app.settle(tester);
    await capture(tester, '02-nouveau-profil');
  });

  testWidgets('qui es-tu', (tester) async {
    await TestApp.pump(tester, seed: family);
    await capture(tester, '03-qui-es-tu');
  });

  testWidgets('code', (tester) async {
    final app = await TestApp.pump(tester, seed: family);
    await tester.tap(find.text('Ama'));
    await app.settle(tester);
    for (final d in ['1', '3']) {
      await tester.tap(find.text(d).last);
    }
    await app.settle(tester);
    await capture(tester, '04-code');
  });

  testWidgets('accueil', (tester) async {
    final app = await TestApp.pump(tester, seed: family);
    await tester.tap(find.text('Kofi'));
    await app.settle(tester);
    await capture(tester, '05-accueil');
  });

  testWidgets('réglages, verrou, sauvegarde, dépenses', (tester) async {
    final app = await TestApp.pump(tester, seed: family);
    await tester.tap(find.text('Kofi'));
    await app.settle(tester);
    await tester.tap(find.text('Réglages'));
    await app.settle(tester);
    await capture(tester, '06-reglages');

    await tester.tap(find.text('Verrou'));
    await app.settle(tester);
    await capture(tester, '07-verrou');

    await tester.tap(find.text('Réglages'));
    await app.settle(tester);
    await tester.tap(find.text('Sauvegarde'));
    await app.settle(tester);
    await capture(tester, '08-sauvegarde');

    await tester.tap(find.text('Dépenses'));
    await app.settle(tester);
    await capture(tester, '09-depenses');
  });
}

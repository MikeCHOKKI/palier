import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palier/app/providers.dart';
import 'package:palier/core/security/pin_hasher.dart';
import 'package:palier/features/backup/data/backup_files.dart';
import 'package:palier/features/profiles/domain/profile.dart';

import '../helpers/pump_app.dart';

Future<void> _tapKeys(WidgetTester tester, String digits) async {
  for (final d in digits.split('')) {
    await tester.tap(find.text(d).last);
    await tester.pump();
  }
}

void main() {
  testWidgets('premier lancement : créer son profil ouvre l’accueil', (tester) async {
    final app = await TestApp.pump(tester);

    expect(find.text('Bienvenue sur Palier'), findsOneWidget);
    await tester.tap(find.text('Créer mon profil'));
    await app.settle(tester);

    await tester.enterText(find.byType(TextFormField), 'Ama');
    await tester.tap(find.bySemanticsLabel('Menthe'));
    await tester.pump();
    await tester.tap(find.text('Créer le profil'));
    await app.settle(tester);

    expect(find.text('Bonjour, Ama'), findsOneWidget);
    expect(find.text('Protège ton profil'), findsOneWidget);
    final profiles = await tester.runAsync(() => app.profiles.watchAll().first);
    expect(profiles!.single.accent.name, 'menthe');
  });

  testWidgets('le prénom est obligatoire', (tester) async {
    final app = await TestApp.pump(tester);
    await tester.tap(find.text('Créer mon profil'));
    await app.settle(tester);

    await tester.tap(find.text('Créer le profil'));
    await tester.pump();

    expect(find.text('Indique un prénom.'), findsOneWidget);
  });

  testWidgets('un profil unique sans code s’ouvre seul', (tester) async {
    await TestApp.pump(tester, seed: (repo) => repo.create(const ProfileDraft(name: 'Ama')));

    expect(find.text('Bonjour, Ama'), findsOneWidget);
  });

  testWidgets('choisir un membre sans code ouvre son profil', (tester) async {
    final app = await TestApp.pump(
      tester,
      seed: (repo) async {
        await repo.create(const ProfileDraft(name: 'Ama'));
        await repo.create(const ProfileDraft(name: 'Kofi', sportEnabled: false));
      },
    );

    expect(find.text('Qui es-tu ?'), findsOneWidget);
    await tester.tap(find.text('Kofi'));
    await app.settle(tester);

    expect(find.text('Bonjour, Kofi'), findsOneWidget);
    // Sport désactivé pour Kofi : pas d'onglet.
    expect(find.text('Dépenses'), findsOneWidget);
    expect(find.text('Sport'), findsNothing);
  });

  testWidgets('un membre protégé demande son code, refuse le mauvais, accepte le bon', (tester) async {
    late String amaId;
    final app = await TestApp.pump(
      tester,
      seed: (repo) async {
        amaId = (await repo.create(const ProfileDraft(name: 'Ama'))).id;
        await repo.setPin(amaId, '2468');
        await repo.create(const ProfileDraft(name: 'Kofi'));
      },
    );

    await tester.tap(find.text('Ama'));
    await app.settle(tester);
    expect(find.text('Bonjour Ama'), findsOneWidget);

    await _tapKeys(tester, '1111');
    await tester.tap(find.byTooltip('Valider'));
    await app.settle(tester);
    expect(find.text('Code incorrect. Encore 4 essais avant un blocage.'), findsOneWidget);

    await _tapKeys(tester, '2468');
    await tester.tap(find.byTooltip('Valider'));
    await app.settle(tester);
    expect(find.text('Bonjour, Ama'), findsOneWidget);
    expect(app.container.read(sessionProvider).activeProfileId, amaId);
  });

  testWidgets('choisir un code depuis les réglages protège le profil', (tester) async {
    final app = await TestApp.pump(tester, seed: (repo) => repo.create(const ProfileDraft(name: 'Ama')));

    await tester.tap(find.text('Réglages'));
    await app.settle(tester);
    await tester.tap(find.text('Verrou'));
    await app.settle(tester);
    await tester.tap(find.text('Choisir un code'));
    await app.settle(tester);

    await _tapKeys(tester, '135790');
    await app.settle(tester);
    expect(find.text('Confirme ton code'), findsOneWidget);
    await _tapKeys(tester, '135790');
    await app.settle(tester);

    expect(find.text('Code activé'), findsOneWidget);
    final profile = (await tester.runAsync(() => app.profiles.watchAll().first))!.single;
    expect(profile.hasPin, isTrue);
    expect(PinHasher.isValidPin('135790'), isTrue);
  });

  testWidgets('exporter son profil enregistre un fichier chiffré', (tester) async {
    final app = await TestApp.pump(tester, seed: (repo) => repo.create(const ProfileDraft(name: 'Ama')));

    await tester.tap(find.text('Réglages'));
    await app.settle(tester);
    await tester.tap(find.text('Sauvegarde'));
    await app.settle(tester);

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'lune-baobab-42');
    await tester.enterText(fields.at(1), 'lune-baobab-4');
    await tester.tap(find.text('Exporter'));
    await app.settle(tester);
    expect(find.text('Les mots de passe ne correspondent pas.'), findsOneWidget);
    expect(app.files.saved, isEmpty);

    await tester.enterText(fields.at(1), 'lune-baobab-42');
    await tester.tap(find.text('Exporter'));
    await app.settle(tester);

    expect(find.text('Profil exporté.'), findsOneWidget);
    expect(app.files.saved.keys.single, endsWith('.palier'));
    expect(String.fromCharCodes(app.files.saved.values.single), isNot(contains('Ama')));
  });

  testWidgets('un mauvais mot de passe d’import s’affiche sous son champ et part quand on corrige', (tester) async {
    final app = await TestApp.pump(tester, seed: (repo) => repo.create(const ProfileDraft(name: 'Ama')));
    await tester.tap(find.text('Réglages'));
    await app.settle(tester);
    await tester.tap(find.text('Sauvegarde'));
    await app.settle(tester);

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'lune-baobab-42');
    await tester.enterText(fields.at(1), 'lune-baobab-42');
    await tester.tap(find.text('Exporter'));
    await app.settle(tester);
    final saved = app.files.saved.entries.single;
    app.files.toPick = PickedFile(name: saved.key, bytes: saved.value);

    await tester.tap(find.text('Choisir un fichier'));
    await app.settle(tester);
    final importField = find.widgetWithText(TextFormField, 'Mot de passe du fichier');
    await tester.enterText(importField, 'soleil-iroko-7');
    await tester.tap(find.text('Importer'));
    await app.settle(tester);

    const wrong = 'Mot de passe incorrect, ou fichier abîmé.';
    expect(find.descendant(of: importField, matching: find.text(wrong)), findsOneWidget);

    await tester.enterText(importField, 'lune-baobab-4');
    await tester.pump();
    expect(find.text(wrong), findsNothing);
  });
}

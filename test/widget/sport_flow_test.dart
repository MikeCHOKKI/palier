import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:palier/app/providers.dart';
import 'package:palier/features/profiles/domain/profile.dart';
import 'package:palier/features/sport/data/sport_repository.dart';
import 'package:palier/features/sport/domain/sport.dart';

import '../helpers/pump_app.dart';

/// Un jeudi : la semaine a commencé lundi 9.
final _day = DateTime(2026, 11, 12, 18);

Future<TestApp> _openSport(WidgetTester tester) async {
  final app = await TestApp.pump(
    tester,
    now: _day,
    seed: (repo) => repo.create(const ProfileDraft(name: 'Ama')),
  );
  await tester.tap(find.text('Sport').last);
  await app.settle(tester);
  return app;
}

Future<void> _note(
  WidgetTester tester,
  TestApp app, {
  required String activity,
  required String minutes,
  String? km,
  String? effort,
}) async {
  await tester.tap(find.text('Noter une séance'));
  await app.settle(tester);
  await tester.tap(find.text(activity));
  await tester.pump();
  await tester.enterText(find.byKey(const ValueKey('duree')), minutes);
  if (km != null) await tester.enterText(find.byKey(const ValueKey('distance')), km);
  if (effort != null) await tester.tap(find.text(effort));
  await tester.pump();
  await tester.tap(find.text('Enregistrer la séance'));
  await app.settle(tester);
}

void main() {
  testWidgets('une course notée apparaît dans la semaine et la liste, avec distance et allure', (tester) async {
    final app = await _openSport(tester);
    expect(find.text('Règle ton sport'), findsOneWidget);
    expect(find.text('Aucune séance notée'), findsOneWidget);

    await _note(tester, app, activity: 'Course', minutes: '30', km: '5,2', effort: 'Correct');

    expect(find.text('Séance enregistrée.'), findsOneWidget);
    expect(find.text('Course'), findsOneWidget);
    expect(find.text('Aujourd’hui · 5,2 km · 5:46 /km · Correct'), findsOneWidget);
    // La semaine (grand chiffre) et la ligne de la séance.
    expect(find.text('30 min'), findsNWidgets(2));
    expect(find.textContaining('1 séance'), findsOneWidget);
    expect(find.bySemanticsLabel('jeudi : séance notée'), findsOneWidget);
  });

  testWidgets('le renforcement n’a pas de distance, et une durée vide est refusée', (tester) async {
    final app = await _openSport(tester);
    await tester.tap(find.text('Noter une séance'));
    await app.settle(tester);
    await tester.tap(find.text('Renforcement'));
    await tester.pump();
    expect(find.byKey(const ValueKey('distance')), findsNothing);

    await tester.tap(find.text('Enregistrer la séance'));
    await app.settle(tester);
    expect(find.text('Indique une durée en minutes, plus de 0.'), findsOneWidget);
    expect(find.text('Noter une séance'), findsWidgets);
  });

  testWidgets('les réglages fixent les jours et l’objectif, que la semaine suit', (tester) async {
    final app = await _openSport(tester);
    await tester.tap(find.byTooltip('Régler mon sport'));
    await app.settle(tester);
    // On ne garde que la marche et le renforcement.
    await tester.tap(find.text('Course'));
    await tester.tap(find.bySemanticsLabel('lundi'));
    await tester.tap(find.bySemanticsLabel('jeudi'));
    await tester.enterText(find.byKey(const ValueKey('objectif')), '60');
    await tester.pump();
    await tester.tap(find.text('Enregistrer mes réglages'));
    await app.settle(tester);

    expect(find.text('Réglages du sport enregistrés.'), findsOneWidget);
    expect(find.text('Règle ton sport'), findsNothing);
    expect(find.text('sur 1 h 00'), findsOneWidget);
    expect(find.bySemanticsLabel('lundi : jour prévu'), findsOneWidget);

    await tester.tap(find.text('Noter une séance'));
    await app.settle(tester);
    // La course n'est plus proposée.
    expect(find.text('Course'), findsNothing);
    await tester.tap(find.byTooltip('Fermer'));
    await app.settle(tester);

    await _note(tester, app, activity: 'Marche', minutes: '65');
    expect(find.text('Objectif de la semaine atteint'), findsOneWidget);
    expect(find.textContaining('1 sur 2 jours prévus'), findsOneWidget);
  });

  testWidgets('une séance se modifie, se supprime et revient avec « Annuler »', (tester) async {
    final app = await _openSport(tester);
    await tester.runAsync(
      () => SportRepository(app.db).createWorkout(
        app.container.read(activeProfileProvider)!.id,
        WorkoutDraft(
          activity: WorkoutActivity.walk,
          occurredAt: DateTime(2026, 11, 11, 7),
          durationSeconds: 40 * 60,
          note: 'avec Kofi',
        ),
      ),
    );
    await app.settle(tester);
    expect(find.text('avec Kofi'), findsOneWidget);

    await tester.tap(find.text('Marche'));
    await app.settle(tester);
    expect(find.text('Modifier la séance'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('duree')), '45');
    await tester.tap(find.text('Enregistrer la séance'));
    await app.settle(tester);
    expect(find.text('Séance modifiée.'), findsOneWidget);
    expect(find.text('45 min'), findsNWidgets(2));

    await tester.tap(find.text('Marche'));
    await app.settle(tester);
    await tester.tap(find.text('Supprimer la séance'));
    await app.settle(tester);
    expect(find.text('Séance supprimée.'), findsOneWidget);
    expect(find.text('Aucune séance notée'), findsOneWidget);

    await tester.tap(find.text('Annuler'));
    await app.settle(tester);
    expect(find.text('avec Kofi'), findsOneWidget);
  });
}

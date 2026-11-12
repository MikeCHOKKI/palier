import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:palier/app/providers.dart';
import 'package:palier/features/profiles/domain/profile.dart';
import 'package:palier/features/sport/data/sport_repository.dart';
import 'package:palier/features/sport/domain/circuits.dart';
import 'package:palier/features/sport/domain/sport.dart';

import '../helpers/pump_app.dart';

/// Deux tours : pompes (10, repos 20 s) puis gainage (30 s), sans repos entre les tours.
const _maison = CircuitDraft(
  name: 'Maison',
  rounds: 2,
  roundRestSeconds: 0,
  exercises: [
    CircuitExercise(name: 'Pompes', reps: 10, restSeconds: 20),
    CircuitExercise(name: 'Gainage', seconds: 30, restSeconds: 0),
  ],
);

void main() {
  late DateTime now;

  setUp(() => now = DateTime(2026, 11, 12, 18));

  Future<TestApp> openSport(WidgetTester tester, {bool withCircuit = false}) async {
    final app = await TestApp.pump(
      tester,
      clock: () => now,
      seed: (repo) => repo.create(const ProfileDraft(name: 'Ama')),
    );
    if (withCircuit) {
      await tester.runAsync(
        () => SportRepository(app.db).createCircuit(app.container.read(activeProfileProvider)!.id, _maison),
      );
    }
    await tester.tap(find.text('Sport').last);
    await app.settle(tester);
    return app;
  }

  /// Une séance tourne : son minuteur relance l'affichage sans fin, `settle` n'aboutirait pas.
  Future<void> tick(WidgetTester tester, {int seconds = 0}) async {
    now = now.add(Duration(seconds: seconds));
    await tester.pump(const Duration(milliseconds: 250));
  }

  testWidgets('composer un circuit : nom, tours, exercices en répétitions et en durée', (tester) async {
    final app = await openSport(tester);
    await tester.tap(find.text('Composer un circuit'));
    await app.settle(tester);

    await tester.tap(find.text('Enregistrer le circuit'));
    await app.settle(tester);
    expect(find.text('Donne un nom au circuit.'), findsOneWidget);
    expect(find.text('Ajoute au moins un exercice.'), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('nom-circuit')), 'Maison');
    await tester.tap(find.byTooltip('Un tour de moins'));
    await tester.pump();

    await tester.tap(find.text('Ajouter un exercice'));
    await app.settle(tester);
    await tester.enterText(find.byKey(const ValueKey('nom-exercice')), 'Pompes');
    await tester.enterText(find.byKey(const ValueKey('valeur-exercice')), '10');
    await tester.enterText(find.byKey(const ValueKey('repos-exercice')), '20');
    await tester.tap(find.text('Valider l’exercice'));
    await app.settle(tester);

    await tester.tap(find.text('Ajouter un exercice'));
    await app.settle(tester);
    await tester.enterText(find.byKey(const ValueKey('nom-exercice')), 'Gainage');
    await tester.tap(find.text('Durée'));
    await tester.pump();
    await tester.enterText(find.byKey(const ValueKey('valeur-exercice')), '30');
    await tester.enterText(find.byKey(const ValueKey('repos-exercice')), '0');
    await tester.tap(find.text('Valider l’exercice'));
    await app.settle(tester);

    expect(find.text('10 répétitions · repos 20 s'), findsOneWidget);
    expect(find.text('30 s · sans repos'), findsOneWidget);
    await tester.tap(find.text('Enregistrer le circuit'));
    await app.settle(tester);

    expect(find.text('Circuit enregistré.'), findsOneWidget);
    expect(find.text('Maison'), findsOneWidget);
    expect(find.text('2 tours · 2 exercices'), findsOneWidget);
  });

  testWidgets('une séance guidée se déroule, garde l’écran allumé et rejoint le journal', (tester) async {
    final app = await openSport(tester, withCircuit: true);
    await tester.tap(find.byTooltip('Lancer Maison'));
    await app.settle(tester);
    expect(find.text('Prêt ?'), findsOneWidget);

    await tester.tap(find.text('Commencer'));
    await tick(tester);
    expect(app.screen.on, isTrue);
    expect(find.text('Tour 1 sur 2'), findsOneWidget);
    expect(find.text('Pompes'), findsOneWidget);
    expect(find.text('10'), findsOneWidget);
    expect(find.text('Ensuite : Repos'), findsOneWidget);

    // Une étape en répétitions attend « Fait ».
    await tick(tester, seconds: 40);
    expect(find.text('Pompes'), findsOneWidget);
    await tester.tap(find.text('Fait'));
    await tick(tester);
    expect(find.text('Repos'), findsOneWidget);
    expect(find.text('0:20'), findsOneWidget);

    // Le repos passe tout seul, et le gainage commence à l'heure exacte.
    await tick(tester, seconds: 25);
    expect(find.text('Gainage'), findsOneWidget);
    expect(find.text('0:25'), findsOneWidget);

    // La pause arrête le décompte.
    await tester.tap(find.text('Pause'));
    await tick(tester, seconds: 60);
    expect(find.text('En pause'), findsOneWidget);
    expect(find.text('0:25'), findsOneWidget);
    await tester.tap(find.text('Reprendre'));
    await tick(tester, seconds: 25);
    expect(find.text('Tour 2 sur 2'), findsOneWidget);

    await tester.tap(find.text('Fait'));
    await tick(tester);
    await tester.tap(find.text('Passer'));
    await tick(tester);
    expect(find.text('Gainage'), findsOneWidget);
    await tick(tester, seconds: 30);

    expect(find.text('Circuit terminé'), findsOneWidget);
    expect(app.screen.on, isFalse);
    await tester.tap(find.text('Dur'));
    await tester.pump();
    await tester.tap(find.text('Enregistrer la séance'));
    await app.settle(tester);

    expect(find.text('Séance enregistrée.'), findsOneWidget);
    final workouts = await tester.runAsync(
      () => SportRepository(app.db).watchWorkouts(app.container.read(activeProfileProvider)!.id).first,
    );
    final workout = workouts!.single;
    expect(workout.activity, WorkoutActivity.strength);
    expect(workout.effort, WorkoutEffort.hard);
    expect(workout.note, 'Maison');
    expect(workout.circuitId, isNotNull);
    // Tour 1 : 40 s de pompes, 20 de repos, 30 de gainage ; tour 2 : « Fait » et « Passer »
    // aussitôt, puis 30 s de gainage. La minute de pause ne compte pas.
    expect(workout.durationSeconds, 120);
  });

  testWidgets('arrêter en cours de route : garder ce qui est fait, ou abandonner', (tester) async {
    final app = await openSport(tester, withCircuit: true);
    await tester.tap(find.byTooltip('Lancer Maison'));
    await app.settle(tester);
    await tester.tap(find.text('Commencer'));
    await tick(tester, seconds: 50);

    await tester.tap(find.byTooltip('Arrêter la séance'));
    await tick(tester);
    expect(find.text('Arrêter la séance ?'), findsOneWidget);
    await tester.tap(find.text('Continuer'));
    await tick(tester);
    expect(find.text('Pompes'), findsOneWidget);

    await tester.tap(find.byTooltip('Arrêter la séance'));
    await tick(tester);
    await tester.tap(find.text('Enregistrer ce qui est fait'));
    await app.settle(tester);
    expect(find.text('Séance enregistrée.'), findsOneWidget);
    expect(app.screen.on, isFalse);
    expect(find.textContaining('Maison'), findsWidgets);
  });
}

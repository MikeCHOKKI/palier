import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:palier/app/providers.dart';
import 'package:palier/features/profiles/domain/profile.dart';
import 'package:palier/features/sport/data/sport_repository.dart';
import 'package:palier/features/sport/domain/circuits.dart';
import 'package:palier/features/sport/domain/program.dart';

import '../helpers/pump_app.dart';

/// Un jeudi.
final _day = DateTime(2026, 11, 12, 18);

Future<TestApp> _open(WidgetTester tester, {Future<void> Function(SportRepository repo, String id)? seed}) async {
  final app = await TestApp.pump(
    tester,
    now: _day,
    seed: (repo) => repo.create(const ProfileDraft(name: 'Ama')),
  );
  if (seed != null) {
    await tester.runAsync(() => seed(SportRepository(app.db), app.container.read(activeProfileProvider)!.id));
    await app.settle(tester);
  }
  return app;
}

void main() {
  testWidgets('une marche prévue aujourd’hui se note depuis le programme et se coche', (tester) async {
    final app = await _open(tester);
    await tester.tap(find.text('Sport').last);
    await app.settle(tester);
    expect(find.text('Au programme aujourd’hui'), findsNothing);

    await tester.tap(find.byTooltip('Mon programme'));
    await app.settle(tester);
    expect(find.text('Pas de séance prévue'), findsNWidgets(7));
    await tester.tap(find.byTooltip('Ajouter une séance le jeudi'));
    await app.settle(tester);
    await tester.tap(find.text('Ajouter au programme'));
    await tester.pump();
    expect(find.text('Choisis une activité ou un circuit.'), findsOneWidget);
    await tester.tap(find.text('Marche'));
    await tester.enterText(find.byKey(const ValueKey('duree-visee')), '30');
    await tester.tap(find.text('Ajouter au programme'));
    await app.settle(tester);
    expect(find.text('Marche · 30 min'), findsOneWidget);
    expect(find.text('Aujourd’hui'), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await app.settle(tester);
    expect(find.text('Au programme aujourd’hui'), findsOneWidget);
    expect(find.bySemanticsLabel('jeudi : jour prévu'), findsOneWidget);

    await tester.tap(find.byTooltip('Noter Marche'));
    await app.settle(tester);
    // Préremplie par le programme : la marche et ses 30 minutes.
    expect(find.text('30'), findsOneWidget);
    expect(find.byKey(const ValueKey('distance')), findsOneWidget);
    await tester.tap(find.text('Enregistrer la séance'));
    await app.settle(tester);

    expect(find.text('Fait'), findsOneWidget);
    expect(find.text('Tout est fait pour aujourd’hui.'), findsOneWidget);
    expect(find.bySemanticsLabel('jeudi : séance notée'), findsOneWidget);
  });

  testWidgets('l’accueil rappelle un circuit prévu et le lance ; le programme se retire et revient', (tester) async {
    final app = await _open(
      tester,
      seed: (repo, id) async {
        final circuit = await repo.createCircuit(
          id,
          const CircuitDraft(
            name: 'Maison',
            exercises: [CircuitExercise(name: 'Pompes', reps: 10)],
          ),
        );
        await repo.addPlanItem(id, PlanItemDraft.circuit(weekday: DateTime.thursday, circuitId: circuit.id));
      },
    );
    expect(find.text('Au programme aujourd’hui'), findsOneWidget);
    await tester.tap(find.byTooltip('Lancer Maison'));
    await app.settle(tester);
    expect(find.text('Prêt ?'), findsOneWidget);
    await tester.tap(find.byTooltip('Fermer'));
    await app.settle(tester);

    await tester.tap(find.text('Sport').last);
    await app.settle(tester);
    await tester.tap(find.byTooltip('Mon programme'));
    await app.settle(tester);
    await tester.tap(find.byTooltip('Retirer Maison du programme'));
    await app.settle(tester);
    expect(find.text('Retiré du programme.'), findsOneWidget);
    expect(find.text('Pas de séance prévue'), findsNWidgets(7));
    await tester.tap(find.text('Annuler'));
    await app.settle(tester);
    expect(find.text('Maison'), findsOneWidget);
  });
}

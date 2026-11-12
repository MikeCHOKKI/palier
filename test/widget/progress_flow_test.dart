import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:palier/features/profiles/domain/profile.dart';
import 'package:palier/features/sport/data/sport_repository.dart';
import 'package:palier/features/sport/domain/sport.dart';

import '../helpers/pump_app.dart';

/// La page qui défile de haut en bas (les filtres défilent aussi, de côté).
final _page = find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down);

/// Un jeudi.
final _day = DateTime(2026, 11, 12, 18);

Future<TestApp> _open(WidgetTester tester, {Future<void> Function(SportRepository repo, String id)? seed}) =>
    TestApp.pump(
      tester,
      now: _day,
      seed: (repo) => repo.create(const ProfileDraft(name: 'Ama')),
      prepare: seed == null
          ? null
          : (app) async => seed(SportRepository(app.db), (await app.profiles.watchAll().first).single.id),
    );

WorkoutDraft _session(WorkoutActivity activity, DateTime day, {int minutes = 30, int? meters}) => WorkoutDraft(
  activity: activity,
  occurredAt: DateTime(day.year, day.month, day.day, 7).toUtc(),
  durationSeconds: minutes * 60,
  distanceMeters: meters,
);

void main() {
  testWidgets('sans séance, les progrès invitent à noter', (tester) async {
    final app = await _open(tester);
    await tester.tap(find.text('Sport').last);
    await app.settle(tester);
    await tester.tap(find.byTooltip('Mes progrès'));
    await app.settle(tester);
    expect(find.text('Rien à montrer pour l’instant'), findsOneWidget);
  });

  testWidgets('les progrès additionnent les semaines, montrent les records et filtrent par activité', (tester) async {
    final app = await _open(
      tester,
      seed: (repo, id) async {
        await repo.createWorkout(id, _session(WorkoutActivity.walk, DateTime(2026, 11, 2), minutes: 50, meters: 4000));
        await repo.createWorkout(id, _session(WorkoutActivity.run, DateTime(2026, 11, 10), minutes: 30, meters: 5000));
        await repo.createWorkout(id, _session(WorkoutActivity.strength, DateTime(2026, 11, 11), minutes: 25));
      },
    );
    await tester.tap(find.text('Sport').last);
    await app.settle(tester);
    await tester.tap(find.byTooltip('Mes progrès'));
    await app.settle(tester);

    // 50 + 30 + 25 minutes en deux semaines actives d'affilée.
    expect(find.text('1 h 45'), findsOneWidget);
    expect(find.text('2 semaines actives d’affilée'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('^Minutes, semaine par semaine')), findsOneWidget);
    await tester.scrollUntilVisible(find.text('6:00 /km'), 200, scrollable: _page);
    expect(find.text('Meilleure allure, 1 km ou plus'), findsWidgets);

    await tester.scrollUntilVisible(find.text('Distance'), -200, scrollable: _page);
    await tester.tap(find.text('Distance'));
    await app.settle(tester);
    expect(find.text('9 km'), findsOneWidget);

    await tester.tap(find.text('Régularité'));
    await app.settle(tester);
    expect(find.text('3 jours actifs'), findsOneWidget);

    // Le renforcement n'a pas de distance : la mesure revient aux minutes.
    await tester.tap(find.text('Distance'));
    await app.settle(tester);
    // Le dernier filtre dépasse à droite : la rangée défile de côté.
    await tester.scrollUntilVisible(find.text('Tout'), -200, scrollable: _page);
    await tester.ensureVisible(find.text('Renforcement').first);
    await tester.pump();
    await tester.tap(find.text('Renforcement').first);
    await app.settle(tester);
    expect(find.text('Distance'), findsNothing);
    expect(find.text('25 min'), findsWidgets);
    expect(find.text('Meilleure allure, 1 km ou plus'), findsNothing);
    expect(find.text('Plus longue séance'), findsOneWidget);

    // Un record ouvre la séance qui le détient.
    await tester.scrollUntilVisible(find.text('Plus longue séance'), 200, scrollable: _page);
    await tester.tap(find.text('Plus longue séance'));
    await app.settle(tester);
    expect(find.text('Modifier la séance'), findsOneWidget);
  });
}

@Tags(['captures'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:lucid_core_flutter/lucid_core_flutter.dart' show LucidRecurrence, LucidRecurrenceUnit;
import 'package:material_ui/material_ui.dart';
import 'package:palier/app/theme/palier_accent.dart';
import 'package:palier/features/expenses/data/expenses_repository.dart';
import 'package:palier/features/expenses/domain/expense_kinds.dart';
import 'package:palier/features/expenses/domain/expenses.dart';
import 'package:palier/features/expenses/domain/loans.dart';
import 'package:palier/features/expenses/domain/recurring.dart';
import 'package:palier/features/expenses/domain/tontines.dart';
import 'package:palier/features/expenses/ui/amount_pad.dart';
import 'package:palier/features/profiles/data/profiles_repository.dart';
import 'package:palier/features/profiles/domain/profile.dart';
import 'package:palier/features/sport/data/sport_repository.dart';
import 'package:palier/features/sport/domain/sport.dart';

import '../helpers/pump_app.dart';

/// Jour figé des captures : la date de l'accueil et le mois des dépenses ne
/// changent plus d'une génération à l'autre.
final _day = DateTime(2026, 11, 7, 10);

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
    await TestApp.pump(tester, now: _day);
    await capture(tester, '01-bienvenue');
  });

  testWidgets('nouveau profil', (tester) async {
    final app = await TestApp.pump(tester, now: _day);
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
    await TestApp.pump(tester, now: _day, seed: family);
    await capture(tester, '03-qui-es-tu');
  });

  testWidgets('code', (tester) async {
    final app = await TestApp.pump(tester, now: _day, seed: family);
    await tester.tap(find.text('Ama'));
    await app.settle(tester);
    for (final d in ['1', '3']) {
      await tester.tap(find.text(d).last);
    }
    await app.settle(tester);
    await capture(tester, '04-code');
  });

  testWidgets('accueil', (tester) async {
    final app = await TestApp.pump(tester, now: _day, seed: family);
    await tester.tap(find.text('Kofi'));
    await app.settle(tester);
    await capture(tester, '05-accueil');
  });

  testWidgets('réglages, verrou, sauvegarde, dépenses', (tester) async {
    final app = await TestApp.pump(tester, now: _day, seed: family);
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
  });

  testWidgets('dépenses, saisie, comptes', (tester) async {
    final app = await TestApp.pump(tester, now: _day, seed: family);
    await tester.tap(find.text('Kofi'));
    await app.settle(tester);
    await tester.runAsync(() => _kofiMonth(app));
    await tester.tap(find.text('Dépenses'));
    await app.settle(tester);
    await capture(tester, '09-depenses');

    await tester.tap(find.text('Noter'));
    await app.settle(tester);
    for (final key in ['3', '5']) {
      await tester.tap(find.descendant(of: find.byType(AmountPad), matching: find.text(key)));
      await tester.pump();
    }
    await tester.tap(find.descendant(of: find.byType(AmountPad), matching: find.bySemanticsLabel('Trois zéros')));
    await tester.tap(find.text('Alimentation'));
    await app.settle(tester);
    await capture(tester, '10-noter');

    await tester.tap(find.byTooltip('Fermer'));
    await app.settle(tester);
    await tester.tap(find.byTooltip('Gérer les dépenses'));
    await app.settle(tester);
    await tester.tap(find.text('Comptes').last);
    await app.settle(tester);
    await capture(tester, '11-comptes');

    await tester.tap(find.byType(BackButton));
    await app.settle(tester);
    await tester.tap(find.byTooltip('Gérer les dépenses'));
    await app.settle(tester);
    await tester.tap(find.text('Budgets').last);
    await app.settle(tester);
    await capture(tester, '12-budgets');

    await tester.tap(find.byType(BackButton));
    await app.settle(tester);
    await tester.tap(find.byTooltip('Gérer les dépenses'));
    await app.settle(tester);
    await tester.tap(find.text('Récurrentes').last);
    await app.settle(tester);
    await capture(tester, '13-recurrentes');

    await tester.tap(find.byType(BackButton));
    await app.settle(tester);
    await tester.tap(find.byTooltip('Gérer les dépenses'));
    await app.settle(tester);
    await tester.tap(find.text('Tontines').last);
    await app.settle(tester);
    await capture(tester, '15-tontines');

    await tester.tap(find.text('Tontine du marché'));
    await app.settle(tester);
    await capture(tester, '16-tontine');
    await tester.tap(find.byType(BackButton));
    await app.settle(tester);
    await tester.tap(find.byType(BackButton));
    await app.settle(tester);
    await tester.tap(find.byTooltip('Gérer les dépenses'));
    await app.settle(tester);
    await tester.tap(find.text('Prêts').last);
    await app.settle(tester);
    await capture(tester, '17-prets');

    await tester.tap(find.text('Yao'));
    await app.settle(tester);
    await capture(tester, '18-pret');
    await tester.tap(find.byType(BackButton));
    await app.settle(tester);

    await tester.tap(find.byType(BackButton));
    await app.settle(tester);
    await tester.tap(find.text('Noter'));
    await app.settle(tester);
    for (final key in ['5', '0', '0', '0']) {
      await tester.tap(find.descendant(of: find.byType(AmountPad), matching: find.text(key)));
      await tester.pump();
    }
    await tester.tap(find.text('Alimentation'));
    await tester.pump();
    final repeat = find.text('Revient régulièrement');
    await tester.scrollUntilVisible(repeat, 200, scrollable: find.byType(Scrollable).first);
    await tester.tap(repeat);
    await app.settle(tester);
    await tester.scrollUntilVisible(find.text('Sans fin'), 200, scrollable: find.byType(Scrollable).first);
    await app.settle(tester);
    await capture(tester, '14-repeter');
  });

  testWidgets('sport, séance, réglages', (tester) async {
    final app = await TestApp.pump(tester, now: _day, seed: family);
    await tester.tap(find.text('Kofi'));
    await app.settle(tester);
    await tester.runAsync(() => _kofiSport(app));
    await tester.tap(find.text('Sport'));
    await app.settle(tester);
    await capture(tester, '19-sport');

    await tester.tap(find.text('Noter une séance'));
    await app.settle(tester);
    await tester.tap(find.text('Course'));
    await tester.enterText(find.byKey(const ValueKey('duree')), '30');
    await tester.enterText(find.byKey(const ValueKey('distance')), '5,2');
    await tester.tap(find.text('Correct'));
    await app.settle(tester);
    FocusManager.instance.primaryFocus?.unfocus();
    await app.settle(tester);
    await capture(tester, '20-seance');

    await tester.tap(find.byTooltip('Fermer'));
    await app.settle(tester);
    await tester.tap(find.byTooltip('Régler mon sport'));
    await app.settle(tester);
    await capture(tester, '21-sport-reglages');
  });
}

/// Une semaine fictive de Kofi : ses réglages (trois jours, 150 minutes) et quatre séances,
/// dont une la semaine d'avant.
Future<void> _kofiSport(TestApp app) async {
  final repo = SportRepository(app.db, clock: () => DateTime.utc(2026, 11, 1, 8));
  final kofi = (await app.profiles.watchAll().first).firstWhere((p) => p.name == 'Kofi').id;
  await repo.saveSettings(
    kofi,
    const SportSettings(
      activities: {WorkoutActivity.walk, WorkoutActivity.run, WorkoutActivity.strength},
      trainingDays: {1, 3, 5},
      weeklyGoalMinutes: 150,
    ),
  );
  DateTime at(int daysAgo, int hour) => DateTime(_day.year, _day.month, _day.day - daysAgo, hour);
  for (final draft in [
    WorkoutDraft(
      activity: WorkoutActivity.run,
      occurredAt: at(9, 6),
      durationSeconds: 28 * 60,
      distanceMeters: 5000,
      effort: WorkoutEffort.hard,
    ),
    WorkoutDraft(
      activity: WorkoutActivity.run,
      occurredAt: at(5, 6),
      durationSeconds: 32 * 60,
      distanceMeters: 5400,
      effort: WorkoutEffort.easy,
      note: 'Bord de mer',
    ),
    WorkoutDraft(
      activity: WorkoutActivity.strength,
      occurredAt: at(3, 19),
      durationSeconds: 25 * 60,
      effort: WorkoutEffort.ok,
      note: 'Pompes, squats, gainage',
    ),
    WorkoutDraft(activity: WorkoutActivity.walk, occurredAt: at(1, 18), durationSeconds: 45 * 60, distanceMeters: 3800),
  ]) {
    await repo.createWorkout(kofi, draft);
  }
}

/// Un mois fictif de Kofi : deux comptes et une épargne, un salaire, quelques dépenses, un
/// virement, trois plafonds, ce qui revient (salaire, loyer, abonnement), une tontine et deux prêts.
Future<void> _kofiMonth(TestApp app) async {
  // Tout est créé le 1er du mois : la date réelle du jour ne change rien aux captures.
  final repo = ExpensesRepository(app.db, clock: () => DateTime.utc(2026, 11, 1, 8));
  final kofi = (await app.profiles.watchAll().first).firstWhere((p) => p.name == 'Kofi').id;
  await repo.ensureStarterKit(kofi);
  final cash = (await repo.watchAccounts(kofi).first).single;
  await repo.updateAccount(cash.id, const AccountDraft(name: 'Espèces', openingBalance: 18000));
  final momo = await repo.createAccount(
    kofi,
    const AccountDraft(name: 'MTN MoMo', kind: AccountKind.mobileMoney, openingBalance: 42500),
  );
  final tabaski = await repo.createAccount(
    kofi,
    const AccountDraft(name: 'Tabaski', kind: AccountKind.savings, openingBalance: 40000, goal: 150000),
  );
  final categories = {for (final c in await repo.watchCategories(kofi).first) c.name: c.id};
  final now = _day;
  DateTime at(int daysAgo, int hour) => DateTime(now.year, now.month, now.day - daysAgo, hour);

  Future<void> add(
    OperationKind kind,
    int amount,
    String account,
    DateTime when, {
    String? category,
    String? to,
    String? note,
    LucidRecurrence? repeat,
  }) => repo.addOperation(
    kofi,
    repeat: repeat,
    OperationDraft(
      kind: kind,
      amount: amount,
      accountId: account,
      toAccountId: to,
      categoryId: category == null ? null : categories[category],
      note: note,
      occurredAt: when,
    ),
  );

  final monthly = LucidRecurrence(unit: LucidRecurrenceUnit.month, start: now);
  await add(OperationKind.income, 150000, momo.id, at(1, 9), category: 'Salaire', repeat: monthly);
  await add(OperationKind.transfer, 20000, momo.id, at(1, 12), to: cash.id, note: 'retrait');
  await add(OperationKind.transfer, 15000, momo.id, at(1, 13), to: tabaski.id, note: 'épargne');
  await add(OperationKind.expense, 12500, cash.id, at(1, 18), category: 'Alimentation', note: 'marché');
  await add(OperationKind.expense, 1000, momo.id, at(0, 8), category: 'Crédit et data');
  await add(OperationKind.expense, 700, cash.id, at(0, 9), category: 'Transport', note: 'zem');
  await repo.setBudget(kofi, categories['Alimentation']!, 60000);
  await repo.setBudget(kofi, categories['Transport']!, 15000);
  await repo.setBudget(kofi, categories['Crédit et data']!, 5000);
  Future<void> recurring(int amount, String category, int day, String note) => repo.createRecurring(
    kofi,
    RecurringDraft(
      kind: OperationKind.expense,
      amount: amount,
      accountId: momo.id,
      categoryId: categories[category],
      note: note,
      rule: LucidRecurrence(unit: LucidRecurrenceUnit.month, start: DateTime(now.year, now.month, day)),
    ),
  );
  // Le loyer du 5 attend d'être réglé ; l'abonnement tombe le 15.
  await recurring(35000, 'Loyer', 5, 'Loyer');
  await recurring(5000, 'Loisirs', 15, 'Canal+');
  // Un prêt à Yao, à moitié remboursé, et une dette d'avant Palier.
  final notes = (
    lent: (String n) => 'Prêt · $n',
    borrowed: (String n) => 'Emprunt · $n',
    repayment: (String n) => 'Remboursement · $n',
  );
  await repo.createLoan(
    kofi,
    LoanDraft(name: 'Yao', direction: LoanDirection.lent, amount: 20000, accountId: cash.id, day: at(4, 0)),
    notes: notes,
  );
  final yao = (await repo.watchLoans(kofi).first).single;
  await repo.repayLoan(kofi, yao, amount: 10000, accountId: cash.id, day: at(1, 0), notes: notes);
  await repo.createLoan(
    kofi,
    LoanDraft(
      name: 'Tante Afi',
      direction: LoanDirection.borrowed,
      amount: 60000,
      accountId: momo.id,
      day: DateTime(2026, 9, 2),
      beforePalier: true,
    ),
    notes: notes,
  );
  // Une tontine suivie en cours de route : trois vendredis déjà passés, la main au 6e tour.
  await repo.createTontine(
    kofi,
    TontineDraft(
      name: 'Tontine du marché',
      accountId: momo.id,
      terms: TontineTerms(
        contribution: 5000,
        members: 10,
        rank: 6,
        unit: LucidRecurrenceUnit.week,
        firstRound: DateTime(2026, 10, 16),
      ),
    ),
    notes: (contribution: (name) => 'Cotisation · $name', hand: (name) => 'Main · $name'),
  );
}

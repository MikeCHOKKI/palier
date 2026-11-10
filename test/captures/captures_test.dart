@Tags(['captures'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palier/app/providers.dart';
import 'package:palier/app/theme/palier_accent.dart';
import 'package:palier/features/expenses/domain/expense_kinds.dart';
import 'package:palier/features/expenses/domain/expenses.dart';
import 'package:palier/features/expenses/ui/amount_pad.dart';
import 'package:palier/features/profiles/data/profiles_repository.dart';
import 'package:palier/features/profiles/domain/profile.dart';

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
    await tester.tap(find.byTooltip('Comptes, catégories et budgets'));
    await app.settle(tester);
    await tester.tap(find.text('Comptes').last);
    await app.settle(tester);
    await capture(tester, '11-comptes');

    await tester.tap(find.byType(BackButton));
    await app.settle(tester);
    await tester.tap(find.byTooltip('Comptes, catégories et budgets'));
    await app.settle(tester);
    await tester.tap(find.text('Budgets').last);
    await app.settle(tester);
    await capture(tester, '12-budgets');
  });
}

/// Un mois fictif de Kofi : deux comptes, un salaire, quelques dépenses, un
/// virement, trois plafonds.
Future<void> _kofiMonth(TestApp app) async {
  final repo = app.container.read(expensesRepositoryProvider);
  final kofi = (await app.profiles.watchAll().first).firstWhere((p) => p.name == 'Kofi').id;
  await repo.ensureStarterKit(kofi);
  final cash = (await repo.watchAccounts(kofi).first).single;
  await repo.updateAccount(cash.id, const AccountDraft(name: 'Espèces', openingBalance: 18000));
  final momo = await repo.createAccount(
    kofi,
    const AccountDraft(name: 'MTN MoMo', kind: AccountKind.mobileMoney, openingBalance: 42500),
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
  }) => repo.addOperation(
    kofi,
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

  await add(OperationKind.income, 150000, momo.id, at(1, 9), category: 'Salaire');
  await add(OperationKind.transfer, 20000, momo.id, at(1, 12), to: cash.id, note: 'retrait');
  await add(OperationKind.expense, 12500, cash.id, at(1, 18), category: 'Alimentation', note: 'marché');
  await add(OperationKind.expense, 1000, momo.id, at(0, 8), category: 'Crédit et data');
  await add(OperationKind.expense, 700, cash.id, at(0, 9), category: 'Transport', note: 'zem');
  await repo.setBudget(kofi, categories['Alimentation']!, 60000);
  await repo.setBudget(kofi, categories['Transport']!, 15000);
  await repo.setBudget(kofi, categories['Crédit et data']!, 5000);
}

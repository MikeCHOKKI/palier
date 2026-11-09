import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palier/app/providers.dart';
import 'package:palier/features/expenses/domain/expense_kinds.dart';
import 'package:palier/features/expenses/domain/expenses.dart';
import 'package:palier/features/expenses/domain/money.dart';
import 'package:palier/features/expenses/ui/amount_pad.dart';
import 'package:palier/features/profiles/domain/profile.dart';

import '../helpers/pump_app.dart';

const _xof = PalierCurrency.xof;

/// Touches du pavé de montant, par chiffre ou par libellé (« Trois zéros »).
Future<void> _pad(WidgetTester tester, List<String> keys) async {
  for (final key in keys) {
    final inPad = RegExp(r'^\d$').hasMatch(key)
        ? find.descendant(of: find.byType(AmountPad), matching: find.text(key))
        : find.descendant(of: find.byType(AmountPad), matching: find.bySemanticsLabel(key));
    await tester.tap(inPad);
    await tester.pump();
  }
}

Future<TestApp> _openExpenses(WidgetTester tester) async {
  final app = await TestApp.pump(tester, seed: (repo) => repo.create(const ProfileDraft(name: 'Ama')));
  await tester.tap(find.text('Dépenses').last);
  await app.settle(tester);
  return app;
}

void main() {
  testWidgets('noter une dépense en trois gestes met à jour le mois et le solde', (tester) async {
    final app = await _openExpenses(tester);
    expect(find.text('Rien de noté ce mois-ci'), findsOneWidget);
    expect(find.text(formatMoney(0, _xof)), findsWidgets);

    await tester.tap(find.text('Noter'));
    await app.settle(tester);
    await _pad(tester, ['2', '5', 'Trois zéros']);
    expect(find.text('25 000'), findsOneWidget);
    await tester.tap(find.text('Alimentation'));
    await tester.pump();
    await tester.tap(find.text('Enregistrer la dépense'));
    await app.settle(tester);

    expect(find.text('Dépense enregistrée.'), findsOneWidget);
    expect(find.text('Aujourd’hui'), findsOneWidget);
    expect(find.text('Alimentation'), findsOneWidget);
    expect(find.text(formatMoney(-25000, _xof, signed: true)), findsWidgets);
    expect(find.text(formatMoney(-25000, _xof)), findsWidgets, reason: 'solde total et compte Espèces');
  });

  testWidgets('une dépense sans catégorie dit ce qui manque', (tester) async {
    final app = await _openExpenses(tester);
    await tester.tap(find.text('Noter'));
    await app.settle(tester);

    await tester.tap(find.text('Enregistrer la dépense'));
    await tester.pump();
    expect(find.text('Tape un montant.'), findsOneWidget);

    await _pad(tester, ['5', '0', '0']);
    expect(find.text('Tape un montant.'), findsNothing, reason: 'le message part dès que l’on corrige');
    await tester.tap(find.text('Enregistrer la dépense'));
    await tester.pump();
    expect(find.text('Choisis une catégorie.'), findsOneWidget);
  });

  testWidgets('supprimer une opération s’annule d’un geste', (tester) async {
    final app = await _openExpenses(tester);
    final repo = app.container.read(expensesRepositoryProvider);
    await tester.runAsync(() async {
      final profileId = (await app.profiles.watchAll().first).single.id;
      final cash = (await repo.watchAccounts(profileId).first).single;
      final transport = (await repo.watchCategories(profileId).first).firstWhere((c) => c.name == 'Transport');
      await repo.addOperation(
        profileId,
        OperationDraft(
          kind: OperationKind.expense,
          amount: 500,
          accountId: cash.id,
          categoryId: transport.id,
          note: 'zem',
          occurredAt: DateTime.now(),
        ),
      );
    });
    await app.settle(tester);
    expect(find.text('Transport'), findsOneWidget);

    await tester.tap(find.text('Transport'));
    await app.settle(tester);
    expect(find.text('Modifier'), findsOneWidget);
    expect(find.text('500'), findsOneWidget, reason: 'le montant est repris dans le pavé');
    await tester.tap(find.byTooltip('Supprimer l’opération'));
    await app.settle(tester);

    expect(find.text('Transport'), findsNothing);
    await tester.tap(find.text('Annuler'));
    await app.settle(tester);
    expect(find.text('Transport'), findsOneWidget);
  });

  testWidgets('un virement propose d’ajouter un second compte, qui s’ouvre par-dessus', (tester) async {
    final app = await _openExpenses(tester);
    await tester.tap(find.text('Noter'));
    await app.settle(tester);

    await tester.tap(find.text('Virement'));
    await app.settle(tester);
    expect(find.textContaining('ajoute d’abord un deuxième compte'), findsOneWidget);

    await tester.tap(find.text('Ajouter un compte'));
    await app.settle(tester);
    expect(find.text('Nouveau compte'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).first, 'MTN MoMo');
    await tester.tap(find.text('Enregistrer'));
    await app.settle(tester);

    expect(find.text('Noter'), findsOneWidget, reason: 'retour à la saisie');
    expect(find.text('De'), findsOneWidget);
    expect(find.text('Vers'), findsOneWidget);
    await _pad(tester, ['1', '0', 'Trois zéros']);
    await tester.tap(find.text('Enregistrer le virement'));
    await app.settle(tester);

    expect(find.text('Virement enregistré.'), findsOneWidget);
    expect(find.text('Espèces → MTN MoMo'), findsOneWidget);
    expect(find.text(formatMoney(10000, _xof)), findsWidgets, reason: 'solde du compte MoMo');
  });
}

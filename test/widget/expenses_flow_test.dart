import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucid_core_flutter/lucid_core_flutter.dart' show LucidSnack;
import 'package:palier/app/providers.dart';
import 'package:palier/app/theme/palier_tokens.dart';
import 'package:palier/features/expenses/domain/expense_kinds.dart';
import 'package:palier/features/expenses/domain/expenses.dart';
import 'package:palier/features/expenses/domain/money.dart';
import 'package:palier/features/expenses/ui/amount_pad.dart';
import 'package:palier/features/profiles/domain/profile.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  testWidgets('le message après l’enregistrement laisse « Noter » visible et touchable', (tester) async {
    final app = await _openExpenses(tester);
    await tester.tap(find.text('Noter'));
    await app.settle(tester);
    await _pad(tester, ['5', 'Trois zéros']);
    await tester.tap(find.text('Alimentation'));
    await tester.pump();
    await tester.tap(find.text('Enregistrer la dépense'));
    await app.settle(tester);

    final pill = tester.getRect(find.byKey(LucidSnack.pillKey));
    final fab = tester.getRect(find.byType(FloatingActionButton));
    expect(pill.bottom, lessThanOrEqualTo(fab.top), reason: 'la pastille monte au-dessus du bouton');

    // Le bouton répond encore pendant que le message est affiché.
    await tester.tap(find.text('Noter'));
    await app.settle(tester);
    expect(find.text('Enregistrer la dépense'), findsOneWidget);
  });

  testWidgets('ouvrir « Noter » retire le message en cours, qui couvrirait « Enregistrer »', (tester) async {
    final app = await _openExpenses(tester);
    await tester.tap(find.text('Noter'));
    await app.settle(tester);
    await _pad(tester, ['5', 'Trois zéros']);
    await tester.tap(find.text('Alimentation'));
    await tester.pump();
    await tester.tap(find.text('Enregistrer la dépense'));
    await app.settle(tester);
    expect(find.byKey(LucidSnack.pillKey), findsOneWidget);

    await tester.tap(find.text('Noter'));
    await app.settle(tester);
    expect(find.byKey(LucidSnack.pillKey), findsNothing);
    expect(find.text('Enregistrer la dépense').hitTestable(), findsOneWidget);
  });

  testWidgets('l’œil masque tous les montants, et le téléphone s’en souvient', (tester) async {
    final app = await _openExpenses(tester);
    await tester.tap(find.text('Noter'));
    await app.settle(tester);
    await _pad(tester, ['2', '5', 'Trois zéros']);
    await tester.tap(find.text('Alimentation'));
    await tester.pump();
    await tester.tap(find.text('Enregistrer la dépense'));
    await app.settle(tester);
    expect(find.text(formatMoney(-25000, _xof)), findsWidgets);

    await tester.tap(find.byTooltip('Masquer les montants'));
    await app.settle(tester);
    expect(find.text(formatMoney(-25000, _xof)), findsNothing, reason: 'solde, compte');
    expect(find.text(formatMoney(-25000, _xof, signed: true)), findsNothing, reason: 'opération, jour');
    expect(find.text(formatMoney(25000, _xof)), findsNothing, reason: 'sorties du mois');
    expect(find.text(maskedMoney(_xof)), findsWidgets);
    final total = tester.widget<Text>(find.text(maskedMoney(_xof)).first);
    expect(total.style?.color, isNot(PalierColors.danger), reason: 'le rouge trahirait un solde négatif');

    final prefs = await SharedPreferences.getInstance();
    final profileId = app.container.read(activeProfileProvider)!.id;
    expect(prefs.getBool('palier.amountsHidden.$profileId'), isTrue);

    await tester.tap(find.byTooltip('Afficher les montants'));
    await app.settle(tester);
    expect(find.text(formatMoney(-25000, _xof)), findsWidgets);
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

  testWidgets('glisser une opération : à droite la supprime, à gauche l’ouvre', (tester) async {
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

    await tester.fling(find.text('Transport'), const Offset(-300, 0), 1000);
    await app.settle(tester);
    expect(find.text('Modifier'), findsOneWidget, reason: 'vers la gauche : l’écran de modification');
    expect(find.text('500'), findsOneWidget);
    await tester.tap(find.byTooltip('Fermer'));
    await app.settle(tester);
    expect(find.text('Transport'), findsOneWidget, reason: 'l’opération reste dans la liste');

    await tester.fling(find.text('Transport'), const Offset(300, 0), 1000);
    await app.settle(tester);
    expect(find.text('Transport'), findsNothing, reason: 'vers la droite : supprimée');
    expect(find.text('Opération supprimée.'), findsOneWidget);
    await tester.tap(find.text('Annuler'));
    await app.settle(tester);
    expect(find.text('Transport'), findsOneWidget);
  });

  testWidgets('le message « Annuler » part seul, ou d’un glissement', (tester) async {
    final app = await _openExpenses(tester);
    final repo = app.container.read(expensesRepositoryProvider);
    Future<void> addAndDelete() async {
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
            note: null,
            occurredAt: DateTime.now(),
          ),
        );
      });
      await app.settle(tester);
      await tester.tap(find.text('Transport'));
      await app.settle(tester);
      await tester.tap(find.byTooltip('Supprimer l’opération'));
      await app.settle(tester);
    }

    await addAndDelete();
    expect(find.text('Annuler'), findsOneWidget);
    await tester.pump(const Duration(seconds: 7));
    await app.settle(tester);
    expect(find.text('Annuler'), findsNothing, reason: 'le message ne reste pas indéfiniment');

    await addAndDelete();
    await tester.fling(find.byKey(LucidSnack.pillKey), const Offset(300, 0), 1000);
    await app.settle(tester);
    expect(find.text('Annuler'), findsNothing, reason: 'un glissement de côté ferme le message');
  });

  testWidgets('l’aide du solde de départ se lit en entier sur un téléphone', (tester) async {
    final app = await _openExpenses(tester);
    await tester.tap(find.bySemanticsLabel('Ajouter un compte'));
    await app.settle(tester);

    final help = find.textContaining('au moment où tu commences à le suivre');
    expect(help, findsOneWidget);
    final paragraph = tester.renderObject<RenderParagraph>(find.descendant(of: help, matching: find.byType(RichText)));
    expect(paragraph.didExceedMaxLines, isFalse, reason: 'le texte d’aide ne doit pas finir en « … »');
  });

  testWidgets('passer entre ses comptes propose d’ajouter un second compte, qui s’ouvre par-dessus', (tester) async {
    final app = await _openExpenses(tester);
    await tester.tap(find.text('Noter'));
    await app.settle(tester);

    await tester.tap(find.text('Entre comptes'));
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
    await tester.tap(find.text('Enregistrer le mouvement'));
    await app.settle(tester);

    expect(find.text('Mouvement enregistré.'), findsOneWidget);
    expect(find.text('Espèces → MTN MoMo'), findsOneWidget);
    expect(find.text(formatMoney(10000, _xof)), findsWidgets, reason: 'solde du compte MoMo');
  });
}

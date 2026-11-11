import 'package:flutter_test/flutter_test.dart';
import 'package:lucid_core_flutter/lucid_core_flutter.dart' show LucidRecurrenceUnit;
import 'package:palier/features/expenses/domain/tontines.dart';

void main() {
  // Dix membres, 5 000 F chaque vendredi à partir du 6 novembre 2026, main au 3e tour.
  final weekly = TontineTerms(
    contribution: 5000,
    members: 10,
    rank: 3,
    unit: LucidRecurrenceUnit.week,
    firstRound: DateTime(2026, 11, 6),
  );

  group('calendrier', () {
    test('un tour par membre, la main au tour de son rang', () {
      expect(weekly.roundDay(1), DateTime(2026, 11, 13));
      expect(weekly.handDay, DateTime(2026, 11, 20));
      expect(weekly.lastRound, DateTime(2027, 1, 8));
      expect(weekly.pot, 50000);
    });

    test('les cotisations courent du premier au dernier tour ; la main ne tombe qu’une fois', () {
      final contributions = weekly.contributionRule.between(DateTime(2026, 1, 1), DateTime(2028, 1, 1));
      expect(contributions, hasLength(10));
      expect(contributions.last, DateTime(2027, 1, 8));
      expect(weekly.handRule.between(DateTime(2026, 1, 1), DateTime(2028, 1, 1)), [DateTime(2026, 11, 20)]);
    });

    test('compte les tours arrivés, celui du jour compris', () {
      expect(weekly.roundsUntil(DateTime(2026, 11, 5)), 0);
      expect(weekly.roundsUntil(DateTime(2026, 11, 13, 18)), 2);
      expect(weekly.roundsUntil(DateTime(2027, 6, 1)), 10);
    });

    test('un mois de 31 jours : le tour tombe au dernier jour des mois plus courts', () {
      final monthly = TontineTerms(
        contribution: 20000,
        members: 4,
        rank: 2,
        unit: LucidRecurrenceUnit.month,
        firstRound: DateTime(2026, 10, 31),
      );
      expect(monthly.handDay, DateTime(2026, 11, 30));
      expect(monthly.lastRound, DateTime(2027, 1, 31));
    });
  });

  group('solde de départ d’une tontine déjà commencée', () {
    test('rien avant le premier tour, ni le jour même (il sera demandé)', () {
      expect(weekly.openingBalance(DateTime(2026, 11, 6)), 0);
    });

    test('les cotisations des tours passés, avant la main', () {
      expect(weekly.openingBalance(DateTime(2026, 11, 14)), 10000);
    });

    test('moins la main une fois son jour passé : on doit alors au groupe', () {
      // Trois cotisations (15 000) moins la main (50 000).
      expect(weekly.openingBalance(DateTime(2026, 11, 21)), -35000);
    });

    test('revient à zéro une fois tous les tours passés', () {
      expect(weekly.openingBalance(DateTime(2027, 2, 1)), 0);
    });
  });

  group('ce qui manque', () {
    TontineDraft draft({String name = 'Tontine du marché', int contribution = 5000, int members = 10, int rank = 3}) =>
        TontineDraft(
          name: name,
          accountId: 'momo',
          terms: TontineTerms(
            contribution: contribution,
            members: members,
            rank: rank,
            unit: LucidRecurrenceUnit.week,
            firstRound: DateTime(2026, 11, 6),
          ),
        );

    test('une tontine complète passe', () => expect(draft().problem, isNull));
    test('un nom', () => expect(draft(name: '  ').problem, TontineProblem.noName));
    test('une cotisation', () => expect(draft(contribution: 0).problem, TontineProblem.noContribution));
    test('au moins deux membres', () => expect(draft(members: 1, rank: 1).problem, TontineProblem.tooFewMembers));
    test('pas plus de cent', () => expect(draft(members: 101).problem, TontineProblem.tooManyMembers));
    test('un rang dans le tour', () => expect(draft(rank: 11).problem, TontineProblem.badRank));
    test('un compte', () {
      final noAccount = TontineDraft(name: 'T', terms: draft().terms, accountId: null);
      expect(noAccount.problem, TontineProblem.noAccount);
    });
  });
}

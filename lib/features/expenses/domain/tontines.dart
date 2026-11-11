import 'package:flutter/foundation.dart';
import 'package:lucid_core_flutter/lucid_core_flutter.dart' show LucidRecurrence, LucidRecurrenceUnit;

import 'recurring.dart';

/// Ce qui manque à une tontine pour être enregistrée.
enum TontineProblem { noName, noContribution, tooFewMembers, tooManyMembers, badRank, noAccount }

/// Le calendrier d'une tontine : un tour par échéance, autant de tours que de
/// membres. À chaque tour, chacun cotise ; la main (cotisation × membres) va
/// au membre dont c'est le rang.
@immutable
class TontineTerms {
  const TontineTerms({
    required this.contribution,
    required this.members,
    required this.rank,
    required this.unit,
    required this.firstRound,
    this.interval = 1,
  });

  /// Cotisation de chaque tour, en unités mineures.
  final int contribution;
  final int members;

  /// Son tour de recevoir la main, de 1 à [members].
  final int rank;
  final LucidRecurrenceUnit unit;
  final int interval;
  final DateTime firstRound;

  static const int minMembers = 2;
  static const int maxMembers = 100;

  /// Le tour numéro [index], le premier étant 0.
  DateTime roundDay(int index) => LucidRecurrence(unit: unit, interval: interval, start: firstRound).occurrence(index)!;

  DateTime get lastRound => roundDay(members - 1);

  /// Le jour où l'on reçoit la main.
  DateTime get handDay => roundDay(rank - 1);

  /// La main : la cotisation de chaque membre, la sienne comprise.
  int get pot => contribution * members;

  /// Les cotisations : une par tour, du premier au dernier.
  LucidRecurrence get contributionRule =>
      LucidRecurrence(unit: unit, interval: interval, start: firstRound, until: lastRound);

  /// La main : une seule échéance, le jour de son rang.
  LucidRecurrence get handRule => LucidRecurrence(unit: unit, interval: interval, start: handDay, until: handDay);

  /// Les tours arrivés jusqu'à [today] compris.
  int roundsUntil(DateTime today) {
    final day = localDay(today);
    var count = 0;
    while (count < members && !roundDay(count).isAfter(day)) {
      count++;
    }
    return count;
  }

  /// Ce que la tontine a déjà fait avant [today], quand on commence à la suivre
  /// en cours de route : les cotisations des tours passés, moins la main si son
  /// jour est passé. Ces tours-là ne seront pas demandés dans « À valider »
  /// (une récurrence ne réclame rien d'avant sa création) : ils deviennent le
  /// solde de départ du compte de la tontine.
  int openingBalance(DateTime today) {
    final day = localDay(today);
    var balance = 0;
    for (var i = 0; i < members; i++) {
      final round = roundDay(i);
      if (!round.isBefore(day)) break;
      balance += contribution;
      if (i == rank - 1) balance -= pot;
    }
    return balance;
  }

  @override
  bool operator ==(Object other) =>
      other is TontineTerms &&
      other.contribution == contribution &&
      other.members == members &&
      other.rank == rank &&
      other.unit == unit &&
      other.interval == interval &&
      other.firstRound == firstRound;

  @override
  int get hashCode => Object.hash(contribution, members, rank, unit, interval, firstRound);
}

/// Une tontine à créer ou modifier.
@immutable
class TontineDraft {
  const TontineDraft({required this.name, required this.terms, required this.accountId});

  final String name;
  final TontineTerms terms;

  /// Le compte d'où partent les cotisations et où arrive la main.
  final String? accountId;

  static const int maxNameLength = 40;

  TontineProblem? get problem {
    if (name.trim().isEmpty) return TontineProblem.noName;
    if (terms.contribution <= 0) return TontineProblem.noContribution;
    if (terms.members < TontineTerms.minMembers) return TontineProblem.tooFewMembers;
    if (terms.members > TontineTerms.maxMembers) return TontineProblem.tooManyMembers;
    if (terms.rank < 1 || terms.rank > terms.members) return TontineProblem.badRank;
    if (accountId == null) return TontineProblem.noAccount;
    return null;
  }
}

/// Une tontine telle que les écrans l'affichent.
@immutable
class Tontine {
  const Tontine({
    required this.id,
    required this.name,
    required this.accountId,
    required this.balance,
    required this.terms,
    required this.payAccountId,
    required this.payAccountName,
    required this.contributionId,
    required this.handId,
  });

  final String id;
  final String name;

  /// Le compte de la tontine, et son solde : ce qu'on y a mis, moins la main.
  final String accountId;
  final int balance;
  final TontineTerms terms;
  final String payAccountId;
  final String payAccountName;

  /// Les deux récurrences : la cotisation et la main.
  final String contributionId;
  final String handId;

  TontineDraft toDraft() => TontineDraft(name: name, terms: terms, accountId: payAccountId);

  @override
  bool operator ==(Object other) =>
      other is Tontine &&
      other.id == id &&
      other.name == name &&
      other.accountId == accountId &&
      other.balance == balance &&
      other.terms == terms &&
      other.payAccountId == payAccountId &&
      other.payAccountName == payAccountName;

  @override
  int get hashCode => Object.hash(id, name, accountId, balance, terms, payAccountId, payAccountName);
}

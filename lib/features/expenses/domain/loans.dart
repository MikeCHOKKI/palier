import 'package:flutter/foundation.dart';

import 'expense_kinds.dart';

/// Ce qui manque à un prêt, ou à un remboursement.
enum LoanProblem { noName, noAmount, noAccount, tooMuch }

/// Les notes des opérations d'un prêt, à partir de son nom : fournies par
/// l'écran, qui connaît la langue.
typedef LoanNotes = ({
  String Function(String name) lent,
  String Function(String name) borrowed,
  String Function(String name) repayment,
});

/// Un prêt à noter.
@immutable
class LoanDraft {
  const LoanDraft({
    required this.name,
    required this.direction,
    required this.amount,
    required this.accountId,
    required this.day,
    this.beforePalier = false,
  });

  /// À qui l'on a prêté, ou de qui l'on a emprunté.
  final String name;
  final LoanDirection direction;
  final int amount;

  /// D'où l'argent part (prêté) ou où il arrive (emprunté).
  final String? accountId;
  final DateTime day;

  /// L'argent a bougé avant qu'on suive ses comptes dans Palier : ses comptes
  /// ne changent pas, seul ce qui reste dû est noté.
  final bool beforePalier;

  static const int maxNameLength = 40;

  /// Le solde de départ du compte du prêt : ce qu'on nous doit, en positif ;
  /// ce qu'on doit, en négatif.
  int get signedAmount => direction == LoanDirection.lent ? amount : -amount;

  LoanProblem? get problem {
    if (name.trim().isEmpty) return LoanProblem.noName;
    if (amount <= 0) return LoanProblem.noAmount;
    if (accountId == null) return LoanProblem.noAccount;
    return null;
  }
}

/// Un prêt tel que les écrans l'affichent.
@immutable
class Loan {
  const Loan({
    required this.id,
    required this.name,
    required this.direction,
    required this.amount,
    required this.accountId,
    required this.balance,
    required this.payAccountId,
    required this.payAccountName,
    required this.startedOn,
  });

  final String id;
  final String name;
  final LoanDirection direction;

  /// Le montant d'origine.
  final int amount;

  /// Le compte du prêt et son solde.
  final String accountId;
  final int balance;
  final String payAccountId;
  final String payAccountName;
  final DateTime startedOn;

  /// Ce qui reste dû, jamais négatif.
  int get remaining {
    final due = direction == LoanDirection.lent ? balance : -balance;
    return due < 0 ? 0 : due;
  }

  /// Ce qui est déjà remboursé, de 0 au montant d'origine.
  int get repaid => (amount - remaining).clamp(0, amount);

  bool get settled => remaining == 0;

  /// Ce qui manque à un remboursement de [value] : rien, ou plus que le reste dû.
  LoanProblem? repaymentProblem(int value, String? account) {
    if (value <= 0) return LoanProblem.noAmount;
    if (account == null) return LoanProblem.noAccount;
    if (value > remaining) return LoanProblem.tooMuch;
    return null;
  }

  @override
  bool operator ==(Object other) =>
      other is Loan &&
      other.id == id &&
      other.name == name &&
      other.direction == direction &&
      other.amount == amount &&
      other.accountId == accountId &&
      other.balance == balance &&
      other.payAccountId == payAccountId &&
      other.payAccountName == payAccountName &&
      other.startedOn == startedOn;

  @override
  int get hashCode =>
      Object.hash(id, name, direction, amount, accountId, balance, payAccountId, payAccountName, startedOn);
}

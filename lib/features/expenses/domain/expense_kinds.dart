/// Types enregistrés en base par leur nom (`textEnum`) : ne jamais renommer une
/// valeur, sinon les lignes déjà écrites ne se relisent plus.
library;

/// Où se trouve l'argent. Un compte d'épargne est un compte comme les autres :
/// on y verse par un virement « Entre comptes », et il peut viser un objectif.
enum AccountKind { cash, mobileMoney, bank, savings }

/// Une catégorie classe soit des dépenses, soit des revenus.
enum CategoryKind { expense, income }

/// Une opération sort de l'argent d'un compte, en fait entrer, ou le déplace
/// d'un compte à un autre (retrait au guichet, dépôt Mobile Money…).
enum OperationKind {
  expense,
  income,
  transfer;

  /// La catégorie qui convient, ou `null` pour un virement (il n'en a pas).
  CategoryKind? get categoryKind => switch (this) {
    OperationKind.expense => CategoryKind.expense,
    OperationKind.income => CategoryKind.income,
    OperationKind.transfer => null,
  };
}

/// L'unité d'une opération récurrente, telle qu'enregistrée en base. Une copie
/// de `LucidRecurrenceUnit` (lucid_core) : les outils de migration de drift ne
/// lisent pas un type venu d'un autre paquet, et le nom en base ne doit pas
/// dépendre d'un renommage dans le paquet.
enum RepeatUnit { week, month, year }

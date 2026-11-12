import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../features/expenses/domain/expense_kinds.dart';
import '../features/sport/domain/sport.dart';
import 'database.steps.dart';

part 'database.g.dart';

/// Conventions de toutes les tables, pensées pour la synchronisation de la
/// phase 2 : identifiant UUID en texte (créé sur le téléphone, sans collision
/// entre appareils), dates en UTC, et suppression douce par [deletedAt] pour
/// qu'une suppression puisse, elle aussi, se propager.
mixin SyncColumns on Table {
  TextColumn get id => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Un membre de la famille et ses réglages.
@DataClassName('ProfileRow')
class Profiles extends Table with SyncColumns {
  TextColumn get name => text().withLength(min: 1, max: 40)();
  TextColumn get accent => text()();
  TextColumn get currency => text().withDefault(const Constant('XOF'))();

  /// Profil d'enfant : pas d'objectif de poids, de calories ni de mensurations.
  BoolColumn get isMinor => boolean().withDefault(const Constant(false))();

  BoolColumn get expensesEnabled => boolean().withDefault(const Constant(true))();
  BoolColumn get sportEnabled => boolean().withDefault(const Constant(true))();

  /// Code du profil : empreinte PBKDF2, jamais le code lui-même.
  TextColumn get pinHash => text().nullable()();
  TextColumn get pinSalt => text().nullable()();
  IntColumn get pinIterations => integer().nullable()();

  BoolColumn get biometricEnabled => boolean().withDefault(const Constant(false))();

  /// Essais de code manqués d'affilée, et fin du blocage qui en découle.
  IntColumn get failedPinAttempts => integer().withDefault(const Constant(0))();
  DateTimeColumn get lockedUntil => dateTime().nullable()();
}

/// Un compte d'un profil : espèces, Mobile Money ou banque.
@DataClassName('AccountRow')
class Accounts extends Table with SyncColumns {
  TextColumn get profileId => text().references(Profiles, #id)();
  TextColumn get name => text().withLength(min: 1, max: 40)();
  TextColumn get kind => textEnum<AccountKind>()();

  /// Ce qu'il y avait sur le compte quand on a commencé à le suivre, en unités
  /// mineures de la devise du profil (le franc pour le F CFA, le centime pour l'euro).
  IntColumn get openingBalance => integer().withDefault(const Constant(0))();

  /// Ordre d'affichage, du plus petit au plus grand.
  IntColumn get position => integer().withDefault(const Constant(0))();

  /// Somme visée par un compte d'épargne, en unités mineures ; `null` sans
  /// objectif chiffré, et toujours pour les autres types de compte.
  // ignore: recursive_getters
  IntColumn get goal => integer().nullable().check(goal.isBiggerThanValue(0))();
}

/// Une catégorie de dépenses ou de revenus d'un profil.
@DataClassName('CategoryRow')
class Categories extends Table with SyncColumns {
  TextColumn get profileId => text().references(Profiles, #id)();
  TextColumn get name => text().withLength(min: 1, max: 32)();
  TextColumn get kind => textEnum<CategoryKind>()();

  /// Clé d'icône (voir `category_icons.dart`), pas un code de police.
  TextColumn get icon => text()();
  IntColumn get position => integer().withDefault(const Constant(0))();
}

/// Une dépense, un revenu ou un virement entre deux comptes.
@DataClassName('OperationRow')
@TableIndex(name: 'operations_profile_date', columns: {#profileId, #occurredAt})
class Operations extends Table with SyncColumns {
  TextColumn get profileId => text().references(Profiles, #id)();
  TextColumn get kind => textEnum<OperationKind>()();

  /// Montant positif en unités mineures ; le sens vient de [kind]. Un entier,
  /// jamais un nombre à virgule : pas d'erreur d'arrondi sur les totaux.
  // La contrainte cite la colonne elle-même : c'est la syntaxe de drift, pas une récursion.
  // ignore: recursive_getters
  IntColumn get amount => integer().check(amount.isBiggerThanValue(0))();

  /// Compte débité (dépense, virement) ou crédité (revenu).
  @ReferenceName('outgoingOperations')
  TextColumn get accountId => text().references(Accounts, #id)();

  /// Compte crédité par un virement ; `null` sinon.
  @ReferenceName('incomingTransfers')
  TextColumn get toAccountId => text().nullable().references(Accounts, #id)();

  /// `null` pour un virement.
  TextColumn get categoryId => text().nullable().references(Categories, #id)();
  TextColumn get note => text().withLength(max: 120).nullable()();

  /// Moment de l'opération (UTC), que l'on peut dater d'un autre jour que la saisie.
  DateTimeColumn get occurredAt => dateTime()();

  /// La récurrence dont l'opération règle une échéance ; `null` sinon.
  TextColumn get recurrenceId => text().nullable().references(Recurrences, #id)();

  /// L'échéance réglée, en jour du calendrier (« 2026-11-05 ») : l'opération peut
  /// être datée d'un autre jour que son échéance.
  TextColumn get dueOn => text().nullable()();
}

/// Le plafond mensuel d'une catégorie de dépenses. Il vaut pour tous les mois
/// tant qu'on ne le change pas ; le retirer le supprime en douceur, le remettre
/// réutilise la même ligne.
@DataClassName('BudgetRow')
class Budgets extends Table with SyncColumns {
  TextColumn get profileId => text().references(Profiles, #id)();

  /// Une seule ligne par catégorie, même supprimée : c'est elle qu'on réactive.
  TextColumn get categoryId => text().unique().references(Categories, #id)();

  /// Plafond par mois, en unités mineures, comme les opérations.
  // ignore: recursive_getters
  IntColumn get amount => integer().check(amount.isBiggerThanValue(0))();
}

/// Une opération qui revient (loyer, abonnement, salaire…). Chaque échéance
/// attend qu'on la règle (une opération liée) ou qu'on la passe ([RecurrenceSkips]) :
/// rien ne s'enregistre tout seul.
///
/// Les jours (début, fin, échéances) sont des textes « 2026-11-05 » : un jour du
/// calendrier n'a pas d'heure, et un instant UTC le décalerait d'un fuseau à l'autre.
@DataClassName('RecurrenceRow')
class Recurrences extends Table with SyncColumns {
  TextColumn get profileId => text().references(Profiles, #id)();
  TextColumn get kind => textEnum<OperationKind>()();
  // ignore: recursive_getters
  IntColumn get amount => integer().check(amount.isBiggerThanValue(0))();
  @ReferenceName('outgoingRecurrences')
  TextColumn get accountId => text().references(Accounts, #id)();
  @ReferenceName('incomingRecurrences')
  TextColumn get toAccountId => text().nullable().references(Accounts, #id)();
  TextColumn get categoryId => text().nullable().references(Categories, #id)();
  TextColumn get note => text().withLength(max: 120).nullable()();

  TextColumn get unit => textEnum<RepeatUnit>()();

  /// Toutes les combien d'unités : 1 chaque mois, 3 chaque trimestre.
  // ignore: recursive_getters
  IntColumn get every => integer().withDefault(const Constant(1)).check(every.isBiggerOrEqualValue(1))();
  TextColumn get startsOn => text()();
  TextColumn get endsOn => text().nullable()();

  /// Les échéances comptent à partir de ce jour : changer la règle ne fait pas
  /// réapparaître celles d'avant.
  TextColumn get dueFrom => text()();
}

/// Une échéance passée sans opération (« Passer »).
@DataClassName('RecurrenceSkipRow')
class RecurrenceSkips extends Table with SyncColumns {
  TextColumn get profileId => text().references(Profiles, #id)();
  TextColumn get recurrenceId => text().references(Recurrences, #id)();
  TextColumn get dueOn => text()();

  /// Une ligne par échéance, même annulée : c'est elle qu'on réactive.
  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {recurrenceId, dueOn},
  ];
}

/// Une tontine dont on suit sa propre part : ses cotisations et son tour.
/// L'argent passe par son compte ([accountId]) grâce à deux récurrences de
/// virement : la cotisation (de son compte vers la tontine, à chaque tour) et
/// la main (de la tontine vers son compte, le jour de son rang). Ni l'une ni
/// l'autre ne compte dans les dépenses ou les revenus du mois.
@DataClassName('TontineRow')
class Tontines extends Table with SyncColumns {
  TextColumn get profileId => text().references(Profiles, #id)();
  TextColumn get accountId => text().unique().references(Accounts, #id)();
  @ReferenceName('contributionTontines')
  TextColumn get contributionId => text().references(Recurrences, #id)();
  @ReferenceName('handTontines')
  TextColumn get handId => text().references(Recurrences, #id)();

  /// Nombre de membres, soit aussi le nombre de tours.
  // ignore: recursive_getters
  IntColumn get members => integer().check(members.isBiggerOrEqualValue(2))();

  /// Son tour de recevoir la main, de 1 à [members].
  // ignore: recursive_getters
  IntColumn get rank => integer().check(rank.isBiggerOrEqualValue(1))();

  @override
  List<String> get customConstraints => ['CHECK (rank <= members)'];
}

/// Un prêt, dans un sens ou dans l'autre. L'argent passe par son compte
/// ([accountId]) en virements : le prêt lui-même, puis les remboursements en
/// sens inverse. Rien ne compte dans les dépenses, les revenus ni les budgets.
@DataClassName('LoanRow')
class Loans extends Table with SyncColumns {
  TextColumn get profileId => text().references(Profiles, #id)();
  TextColumn get accountId => text().unique().references(Accounts, #id)();
  TextColumn get direction => textEnum<LoanDirection>()();

  /// Le montant prêté ou emprunté, en unités mineures : la base de « remboursé ».
  // ignore: recursive_getters
  IntColumn get amount => integer().check(amount.isBiggerThanValue(0))();

  /// Le compte d'où l'argent est parti (prêté) ou où il est arrivé (emprunté),
  /// proposé pour les remboursements.
  @ReferenceName('payingLoans')
  TextColumn get payAccountId => text().references(Accounts, #id)();

  /// Le jour du prêt (« 2026-11-05 »).
  TextColumn get startedOn => text()();
}

/// Les réglages de sport d'un profil : une ligne au plus, créée quand la
/// personne les enregistre pour la première fois.
@DataClassName('SportSettingsRow')
class SportSettingsTable extends Table with SyncColumns {
  @override
  String get tableName => 'sport_settings';

  TextColumn get profileId => text().unique().references(Profiles, #id)();

  /// Activités suivies, séparées par des virgules (« walk,run »).
  TextColumn get activities => text()();

  /// Jours d'entraînement, de 1 (lundi) à 7, séparés par des virgules ; vide sans jour choisi.
  TextColumn get trainingDays => text().withDefault(const Constant(''))();

  /// Objectif de la semaine en minutes, choisi par la personne ; `null` sans objectif.
  // ignore: recursive_getters
  IntColumn get weeklyGoalMinutes => integer().nullable().check(weeklyGoalMinutes.isBiggerThanValue(0))();
}

/// Une séance de sport notée.
@DataClassName('WorkoutRow')
@TableIndex(name: 'workouts_profile_date', columns: {#profileId, #occurredAt})
class Workouts extends Table with SyncColumns {
  TextColumn get profileId => text().references(Profiles, #id)();
  TextColumn get activity => textEnum<WorkoutActivity>()();

  /// Moment de la séance (UTC).
  DateTimeColumn get occurredAt => dateTime()();

  /// En secondes : la saisie se fait en minutes, les séances guidées comptent à la seconde.
  // ignore: recursive_getters
  IntColumn get durationSeconds => integer().check(durationSeconds.isBiggerThanValue(0))();

  /// En mètres, pour la marche et la course ; `null` si non notée.
  // ignore: recursive_getters
  IntColumn get distanceMeters => integer().nullable().check(distanceMeters.isBiggerThanValue(0))();
  TextColumn get effort => textEnum<WorkoutEffort>().nullable()();
  TextColumn get note => text().withLength(max: 120).nullable()();
}

@DriftDatabase(
  tables: [
    Profiles,
    Accounts,
    Categories,
    Operations,
    Budgets,
    Recurrences,
    RecurrenceSkips,
    Tontines,
    Loans,
    SportSettingsTable,
    Workouts,
  ],
)
class PalierDatabase extends _$PalierDatabase {
  PalierDatabase(super.executor);

  /// Base du téléphone, dans le dossier privé de l'application.
  factory PalierDatabase.device() => PalierDatabase(driftDatabase(name: 'palier'));

  @override
  int get schemaVersion => 8;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: stepByStep(
      from1To2: (m, schema) async {
        await m.createTable(schema.accounts);
        await m.createTable(schema.categories);
        await m.createTable(schema.operations);
        await m.createIndex(schema.operationsProfileDate);
      },
      from2To3: (m, schema) async {
        await m.createTable(schema.budgets);
      },
      from3To4: (m, schema) async {
        await m.createTable(schema.recurrences);
        await m.createTable(schema.recurrenceSkips);
        await m.addColumn(schema.operations, schema.operations.recurrenceId);
        await m.addColumn(schema.operations, schema.operations.dueOn);
      },
      from4To5: (m, schema) async {
        await m.addColumn(schema.accounts, schema.accounts.goal);
      },
      from5To6: (m, schema) async {
        await m.createTable(schema.tontines);
      },
      from6To7: (m, schema) async {
        await m.createTable(schema.loans);
      },
      from7To8: (m, schema) async {
        await m.createTable(schema.sportSettings);
        await m.createTable(schema.workouts);
        await m.createIndex(schema.workoutsProfileDate);
      },
    ),
    // SQLite n'applique les clés étrangères que si on le lui demande, à chaque ouverture.
    beforeOpen: (details) => customStatement('PRAGMA foreign_keys = ON'),
  );
}

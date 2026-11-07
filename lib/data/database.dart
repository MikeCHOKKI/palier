import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

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

@DriftDatabase(tables: [Profiles])
class PalierDatabase extends _$PalierDatabase {
  PalierDatabase(super.executor);

  /// Base du téléphone, dans le dossier privé de l'application.
  factory PalierDatabase.device() => PalierDatabase(driftDatabase(name: 'palier'));

  @override
  int get schemaVersion => 1;
}

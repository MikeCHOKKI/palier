import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:palier/data/database.dart';

/// Base SQLite en mémoire, neuve pour chaque test.
PalierDatabase openTestDatabase() {
  // Plusieurs bases en mémoire coexistent pendant les tests : c'est voulu.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  return PalierDatabase(NativeDatabase.memory());
}

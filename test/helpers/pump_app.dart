import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucid_core_flutter/lucid_core_flutter.dart';
import 'package:palier/app/palier_app.dart';
import 'package:palier/app/providers.dart';
import 'package:palier/core/security/pin_hasher.dart';
import 'package:palier/data/database.dart';
import 'package:palier/features/backup/data/backup_service.dart';
import 'package:palier/features/backup/domain/backup_codec.dart';
import 'package:palier/features/profiles/data/profiles_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes.dart';
import 'test_database.dart';

/// L'application complète sur une base en mémoire, avec empreinte et fichiers simulés.
class TestApp {
  TestApp._(this.db, this.container, this.biometric, this.files);

  final PalierDatabase db;
  final ProviderContainer container;
  final FakeBiometricGate biometric;
  final FakeBackupFiles files;

  /// Peu d'itérations : on teste le comportement, pas la résistance.
  static const hasher = PinHasher(iterations: 1000);

  ProfilesRepository get profiles => container.read(profilesRepositoryProvider);

  static Future<TestApp> pump(
    WidgetTester tester, {
    Size size = const Size(390, 844),
    Future<void> Function(ProfilesRepository repo)? seed,
    DateTime? now,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    tester.view
      ..physicalSize = size * 3
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final db = openTestDatabase();
    final biometric = FakeBiometricGate();
    final files = FakeBackupFiles();
    final container = ProviderContainer(
      overrides: [
        preferencesProvider.overrideWithValue(preferences),
        databaseProvider.overrideWithValue(db),
        profilesRepositoryProvider.overrideWith((ref) => ProfilesRepository(db, hasher: hasher)),
        backupServiceProvider.overrideWith(
          (ref) => BackupService(db, codec: const BackupCodec(iterations: 1000), sections: backupSections(db)),
        ),
        biometricGateProvider.overrideWithValue(biometric),
        backupFilesProvider.overrideWithValue(files),
        if (now != null) clockProvider.overrideWithValue(() => now),
      ],
    );
    final app = TestApp._(db, container, biometric, files);

    if (seed != null) await tester.runAsync(() => seed(app.profiles));

    final notifier = LucidThemeNotifier();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: PalierApp(themeNotifier: notifier),
      ),
    );
    await app.settle(tester);

    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
      await tester.runAsync(db.close);
      notifier.dispose();
    });
    return app;
  }

  /// Laisse la base et les isolats répondre, puis termine les animations.
  ///
  /// Un calcul en cours (code, chiffrement) affiche un indicateur qui tourne sans fin :
  /// `pumpAndSettle` expirerait. On avance donc image par image tant qu'il est là, avec
  /// un délai réel pour l'isolat, au lieu d'un nombre fixe de tours qui échouait quand la
  /// machine était chargée.
  Future<void> settle(WidgetTester tester, {Duration timeout = const Duration(seconds: 15)}) async {
    final deadline = DateTime.now().add(timeout);
    final busy = find.byWidgetPredicate((widget) => widget is ProgressIndicator);
    for (var calm = 0; calm < 3;) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      // Une image d'abord : l'indicateur posé par un setState n'existe qu'après elle.
      await tester.pump();
      if (busy.evaluate().isNotEmpty) {
        if (DateTime.now().isAfter(deadline)) fail('Un calcul tourne encore après $timeout.');
        await tester.pump(const Duration(milliseconds: 50));
        calm = 0;
        continue;
      }
      await tester.pumpAndSettle();
      calm++;
    }
  }
}

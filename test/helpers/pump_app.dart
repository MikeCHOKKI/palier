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
  }) async {
    SharedPreferences.setMockInitialValues({});
    tester.view
      ..physicalSize = size * 3
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final db = openTestDatabase();
    final biometric = FakeBiometricGate();
    final files = FakeBackupFiles();
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        profilesRepositoryProvider.overrideWith((ref) => ProfilesRepository(db, hasher: hasher)),
        backupServiceProvider.overrideWith((ref) => BackupService(db, codec: const BackupCodec(iterations: 1000))),
        biometricGateProvider.overrideWithValue(biometric),
        backupFilesProvider.overrideWithValue(files),
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
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pumpAndSettle();
    }
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucid_core_flutter/lucid_core_flutter.dart';

import '../features/expenses/ui/expenses_providers.dart';
import '../l10n/app_localizations.dart';
import 'providers.dart';
import 'router.dart';
import 'theme/palier_accent.dart';
import 'theme/palier_theme.dart';

/// Durée en arrière-plan au-delà de laquelle un profil protégé se reverrouille.
const Duration kRelockAfter = Duration(minutes: 1);

class PalierApp extends ConsumerStatefulWidget {
  const PalierApp({super.key, this.themeNotifier});

  /// Notifieur du socle (widgets d'état) ; fourni par les tests.
  final LucidThemeNotifier? themeNotifier;

  @override
  ConsumerState<PalierApp> createState() => _PalierAppState();
}

class _PalierAppState extends ConsumerState<PalierApp> {
  late final LucidThemeNotifier _lucidTheme = widget.themeNotifier ?? LucidThemeNotifier();
  late final AppLifecycleListener _lifecycle;
  DateTime? _hiddenAt;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onHide: _onHide, onShow: _onShow);
    _applyLucidTheme(PalierAccent.cyan);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    if (widget.themeNotifier == null) _lucidTheme.dispose();
    super.dispose();
  }

  void _onHide() => _hiddenAt = DateTime.now();

  void _onShow() {
    final hiddenAt = _hiddenAt;
    _hiddenAt = null;
    final profile = ref.read(activeProfileProvider);
    if (hiddenAt == null || profile == null || !profile.hasPin) return;
    if (DateTime.now().difference(hiddenAt) >= kRelockAfter) {
      ref.read(sessionProvider.notifier).lock();
    }
  }

  void _applyLucidTheme(PalierAccent accent) {
    _lucidTheme.setCustomTheme(palierLucidTheme(accent));
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final accent = ref.watch(activeProfileProvider.select((p) => p?.accent)) ?? PalierAccent.cyan;

    ref
      ..listen(activeProfileProvider.select((p) => p?.accent), (_, next) {
        _applyLucidTheme(next ?? PalierAccent.cyan);
      })
      // Au premier chargement, un profil unique et sans code s'ouvre directement.
      ..listen(profilesProvider, (previous, next) {
        final firstLoad = previous == null || !previous.hasValue;
        final profiles = next.value;
        if (firstLoad && profiles != null && profiles.length == 1 && !profiles.single.hasPin) {
          ref.read(sessionProvider.notifier).open(profiles.single.id);
        }
      });

    // Palier n'a qu'un thème, sombre : il sert dans les deux modes, pour que le
    // passage clair/sombre du téléphone ne ramène pas le thème par défaut du socle.
    final theme = palierTheme(accent);
    final profileId = ref.watch(activeProfileIdProvider);
    return LucidApp.router(
      title: 'Palier',
      themeNotifier: _lucidTheme,
      lightTheme: theme,
      darkTheme: theme,
      routerConfig: router,
      locale: const Locale('fr'),
      additionalLocalizationsDelegates: const [AppLocalizations.delegate],
      additionalSupportedLocales: AppLocalizations.supportedLocales,
      // L'œil des montants vaut pour tous les écrans du profil ouvert.
      builder: (context, child) => profileId == null
          ? child!
          : LucidPrivacyScope(controller: ref.watch(amountsPrivacyProvider(profileId)), child: child!),
    );
  }
}

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/providers.dart';
import '../../../app/routes.dart';
import '../../../app/theme/palier_theme.dart';
import '../../../app/theme/palier_tokens.dart';
import '../../../core/ui/pin_pad.dart';
import '../../../core/ui/profile_avatar.dart';
import '../../../l10n/app_localizations.dart';
import '../data/profiles_repository.dart';
import '../domain/profile.dart';

/// Saisie du code d'un profil, ou de son empreinte.
class UnlockScreen extends ConsumerStatefulWidget {
  const UnlockScreen({super.key, required this.profileId});

  final String profileId;

  @override
  ConsumerState<UnlockScreen> createState() => _UnlockScreenState();
}

class _UnlockScreenState extends ConsumerState<UnlockScreen> {
  String? _message;
  DateTime? _lockedUntil;
  Timer? _ticker;
  bool _biometricTried = false;

  ProfilesRepository get _repo => ref.read(profilesRepositoryProvider);

  @override
  void initState() {
    super.initState();
    _repo.lockedUntil(widget.profileId).then((until) {
      if (mounted && until != null) _startLock(until);
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Profile? _profile() {
    for (final p in ref.watch(profilesProvider).value ?? const <Profile>[]) {
      if (p.id == widget.profileId) return p;
    }
    return null;
  }

  void _startLock(DateTime until) {
    _ticker?.cancel();
    setState(() => _lockedUntil = until);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (DateTime.now().toUtc().isAfter(until)) {
        _ticker?.cancel();
        setState(() {
          _lockedUntil = null;
          _message = null;
        });
      } else {
        setState(() {});
      }
    });
  }

  Future<void> _check(String pin) async {
    final result = await _repo.checkPin(widget.profileId, pin);
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    switch (result) {
      case PinAccepted():
        ref.read(sessionProvider.notifier).open(widget.profileId);
      case PinRejected(:final lockedUntil?):
        _startLock(lockedUntil);
      case final PinRejected rejected:
        setState(() => _message = l10n.unlockWrong(rejected.remainingBeforeLock));
      case PinLocked(:final until):
        _startLock(until);
    }
  }

  Future<void> _biometric(Profile profile) async {
    final l10n = AppLocalizations.of(context);
    final ok = await ref.read(biometricGateProvider).authenticate(l10n.biometricReason(profile.name));
    if (!ok || !mounted) return;
    await _repo.recordBiometricUnlock(profile.id);
    ref.read(sessionProvider.notifier).open(profile.id);
  }

  String _remaining(DateTime until) {
    final left = until.difference(DateTime.now().toUtc());
    final seconds = left.inSeconds.clamp(1, 24 * 3600);
    if (seconds < 60) return '$seconds s';
    return '${(seconds / 60).ceil()} min';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final profile = _profile();
    if (profile == null) return const Scaffold();

    // L'empreinte est proposée d'elle-même une fois, à l'ouverture.
    if (profile.biometricEnabled && !_biometricTried && _lockedUntil == null) {
      _biometricTried = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _biometric(profile));
    }

    final lockedUntil = _lockedUntil;
    final status = lockedUntil != null ? l10n.unlockLocked(_remaining(lockedUntil)) : _message;

    return Theme(
      data: palierTheme(profile.accent),
      child: Builder(
        builder: (context) {
          final text = Theme.of(context).textTheme;
          return Scaffold(
            body: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: PalierSpace.page, vertical: PalierSpace.lg),
                  child: Column(
                    children: [
                      ProfileAvatar(profile: profile, size: 64),
                      const SizedBox(height: PalierSpace.md),
                      Text(l10n.unlockTitle(profile.name), style: text.headlineSmall, textAlign: TextAlign.center),
                      const SizedBox(height: PalierSpace.xs),
                      Text(l10n.unlockPrompt, style: text.bodyMedium),
                      const SizedBox(height: PalierSpace.xl),
                      PinPad(enabled: lockedUntil == null, onSubmit: _check),
                      const SizedBox(height: PalierSpace.md),
                      SizedBox(
                        height: 44,
                        child: status == null
                            ? null
                            : Text(
                                status,
                                textAlign: TextAlign.center,
                                style: text.bodyMedium?.copyWith(color: PalierColors.danger),
                              ),
                      ),
                      if (profile.biometricEnabled)
                        TextButton.icon(
                          onPressed: lockedUntil == null ? () => _biometric(profile) : null,
                          icon: const Icon(Icons.fingerprint_rounded),
                          label: Text(l10n.unlockBiometric),
                        ),
                      TextButton(
                        style: TextButton.styleFrom(foregroundColor: PalierColors.textMid),
                        onPressed: () {
                          ref.read(sessionProvider.notifier).signOut();
                          context.go(Routes.picker);
                        },
                        child: Text(l10n.unlockOtherProfile),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

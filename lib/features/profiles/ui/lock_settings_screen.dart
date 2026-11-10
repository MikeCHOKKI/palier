import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucid_core_flutter/lucid_core_flutter.dart';

import '../../../app/palier_snack.dart';
import '../../../app/providers.dart';
import '../../../app/routes.dart';
import '../../../app/theme/palier_tokens.dart';
import '../../../l10n/app_localizations.dart';

/// L'empreinte est-elle disponible sur ce téléphone ?
final _biometricAvailableProvider = FutureProvider.autoDispose<bool>(
  (ref) => ref.watch(biometricGateProvider).isAvailable(),
);

/// Code et empreinte du profil ouvert.
class LockSettingsScreen extends ConsumerWidget {
  const LockSettingsScreen({super.key});

  Future<void> _toggleBiometric(BuildContext context, WidgetRef ref, {required bool enable}) async {
    final l10n = AppLocalizations.of(context);
    final profile = ref.read(activeProfileProvider)!;
    // On demande l'empreinte avant de l'activer : la personne prouve qu'elle en a une.
    if (enable && !await ref.read(biometricGateProvider).authenticate(l10n.biometricReason(profile.name))) return;
    await ref.read(profilesRepositoryProvider).setBiometric(profile.id, enabled: enable);
  }

  Future<void> _removePin(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    await ref.read(profilesRepositoryProvider).clearPin(ref.read(activeProfileProvider)!.id);
    if (context.mounted) {
      PalierSnack.done(ScaffoldMessenger.of(context), l10n.lockRemoved);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final profile = ref.watch(activeProfileProvider);
    if (profile == null) return const Scaffold();
    final biometricAvailable = ref.watch(_biometricAvailableProvider).value ?? false;

    final String? biometricNote;
    if (!profile.hasPin) {
      biometricNote = l10n.lockBiometricNeedsCode;
    } else if (!biometricAvailable) {
      biometricNote = l10n.lockBiometricUnavailable;
    } else {
      biometricNote = null;
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.lockTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(PalierSpace.page, PalierSpace.sm, PalierSpace.page, PalierSpace.xl),
          children: [
            LucidCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(profile.hasPin ? Icons.lock_rounded : Icons.lock_open_rounded),
                    title: Text(profile.hasPin ? l10n.lockCodeOn : l10n.lockCodeOff),
                  ),
                  const Divider(indent: 56),
                  ListTile(
                    leading: const Icon(Icons.pin_outlined),
                    title: Text(profile.hasPin ? l10n.lockChangeCode : l10n.lockSetCode),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => context.go(Routes.settingsLockCode),
                  ),
                  if (profile.hasPin) ...[
                    const Divider(indent: 56),
                    ListTile(
                      leading: const Icon(Icons.no_encryption_gmailerrorred_outlined, color: PalierColors.danger),
                      title: Text(l10n.lockRemoveCode, style: const TextStyle(color: PalierColors.danger)),
                      onTap: () => _removePin(context, ref),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: PalierSpace.md),
            LucidCard(
              padding: EdgeInsets.zero,
              // ListTile + Switch plutôt que SwitchListTile : quand l'empreinte est
              // indisponible, l'interrupteur est grisé mais l'explication reste lisible.
              child: ListTile(
                leading: const Icon(Icons.fingerprint_rounded),
                title: Text(l10n.lockBiometricLabel),
                subtitle: Text(biometricNote ?? l10n.lockBiometricWarning),
                isThreeLine: true,
                trailing: Switch(
                  value: profile.biometricEnabled,
                  onChanged: biometricNote != null ? null : (enable) => _toggleBiometric(context, ref, enable: enable),
                ),
                onTap: biometricNote != null
                    ? null
                    : () => _toggleBiometric(context, ref, enable: !profile.biometricEnabled),
              ),
            ),
            const SizedBox(height: PalierSpace.lg),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.timer_outlined, size: 18, color: PalierColors.textLow),
                const SizedBox(width: PalierSpace.sm),
                Expanded(child: Text(l10n.lockAutoNote, style: text.bodySmall)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

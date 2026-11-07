import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucid_core_flutter/lucid_core_flutter.dart';

import '../../../app/providers.dart';
import '../../../app/routes.dart';
import '../../../app/theme/palier_tokens.dart';
import '../../../core/ui/palier_mark.dart';
import '../../../core/ui/profile_avatar.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/profile.dart';

/// « Qui es-tu ? » : chaque membre ouvre son profil.
class ProfilePickerScreen extends ConsumerWidget {
  const ProfilePickerScreen({super.key});

  void _open(BuildContext context, WidgetRef ref, Profile profile) {
    if (profile.hasPin) {
      context.go(Routes.unlock(profile.id));
    } else {
      ref.read(sessionProvider.notifier).open(profile.id);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final profiles = ref.watch(profilesProvider).value ?? const <Profile>[];

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(PalierSpace.page, PalierSpace.xxl, PalierSpace.page, PalierSpace.xl),
          children: [
            const Align(alignment: Alignment.centerLeft, child: PalierMark(height: 40)),
            const SizedBox(height: PalierSpace.lg),
            Text(l10n.pickerTitle, style: text.headlineLarge),
            const SizedBox(height: PalierSpace.xl),
            for (final profile in profiles) ...[
              LucidCard.interactive(
                semanticLabel: l10n.openProfile(profile.name),
                onTap: () => _open(context, ref, profile),
                padding: const EdgeInsets.symmetric(horizontal: PalierSpace.md, vertical: PalierSpace.md - 2),
                child: Row(
                  children: [
                    ProfileAvatar(profile: profile),
                    const SizedBox(width: PalierSpace.md),
                    Expanded(child: Text(profile.name, style: text.titleMedium)),
                    if (profile.hasPin)
                      Tooltip(
                        message: l10n.pickerLocked,
                        child: const Icon(Icons.lock_outline_rounded, size: 20, color: PalierColors.textLow),
                      ),
                    const SizedBox(width: PalierSpace.xs),
                    const Icon(Icons.chevron_right_rounded, color: PalierColors.textLow),
                  ],
                ),
              ),
              const SizedBox(height: PalierSpace.sm + 4),
            ],
            const SizedBox(height: PalierSpace.md),
            LucidButton(
              label: l10n.pickerAdd,
              icon: Icons.person_add_alt_rounded,
              variant: LucidButtonVariant.outlined,
              expand: true,
              onPressed: () => context.go(Routes.pickerNew),
            ),
          ],
        ),
      ),
    );
  }
}

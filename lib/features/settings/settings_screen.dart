import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucid_core_flutter/lucid_core_flutter.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/providers.dart';
import '../../app/routes.dart';
import '../../app/theme/palier_tokens.dart';
import '../../core/ui/palier_mark.dart';
import '../../core/ui/profile_avatar.dart';
import '../../l10n/app_localizations.dart';

/// Version affichée dans « À propos » ; suit `version` de pubspec.yaml.
const String palierVersion = '0.1.0';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final profile = ref.watch(activeProfileProvider);
    if (profile == null) return const SizedBox.shrink();

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(PalierSpace.page, PalierSpace.sm, PalierSpace.page, PalierSpace.xl),
        children: [
          LucidCard.interactive(
            onTap: () => context.go(Routes.settingsProfile),
            child: Row(
              children: [
                ProfileAvatar(profile: profile, size: 52),
                const SizedBox(width: PalierSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(profile.name, style: text.titleMedium),
                      const SizedBox(height: 2),
                      Text(l10n.settingsProfileHint, style: text.bodyMedium),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: PalierColors.textLow),
              ],
            ),
          ),
          const SizedBox(height: PalierSpace.md),
          _Group(
            children: [
              _Row(
                icon: profile.hasPin ? Icons.lock_rounded : Icons.lock_open_rounded,
                title: l10n.lockTitle,
                subtitle: profile.hasPin ? l10n.lockCodeOn : l10n.lockCodeOff,
                onTap: () => context.go(Routes.settingsLock),
              ),
              _Row(
                icon: Icons.shield_outlined,
                title: l10n.settingsBackup,
                subtitle: l10n.settingsBackupHint,
                onTap: () => context.go(Routes.settingsBackup),
              ),
            ],
          ),
          _Heading(l10n.settingsFamily),
          _Group(
            children: [
              _Row(
                icon: Icons.switch_account_outlined,
                title: l10n.settingsSwitchProfile,
                onTap: () => ref.read(sessionProvider.notifier).signOut(),
              ),
              _Row(
                icon: Icons.person_add_alt_rounded,
                title: l10n.pickerAdd,
                onTap: () => context.go(Routes.settingsNewMember),
              ),
            ],
          ),
          _Heading(l10n.settingsAbout),
          _Group(
            children: [
              _Row(
                icon: Icons.description_outlined,
                title: l10n.settingsLicenses,
                onTap: () => showLicensePage(
                  context: context,
                  applicationName: l10n.appTitle,
                  applicationVersion: palierVersion,
                  applicationIcon: const Padding(
                    padding: EdgeInsets.all(PalierSpace.md),
                    child: PalierMark(height: 48),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: PalierSpace.lg),
          Center(child: Text(l10n.settingsVersion(palierVersion), style: text.bodySmall)),
        ],
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(PalierSpace.xs, PalierSpace.lg, 0, PalierSpace.sm),
      child: Text(label, style: Theme.of(context).textTheme.titleSmall),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LucidCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[if (i > 0) const Divider(indent: 56), children[i]],
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.title, required this.onTap, this.subtitle});

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: const Icon(Icons.chevron_right_rounded, color: PalierColors.textLow),
      onTap: onTap,
    );
  }
}

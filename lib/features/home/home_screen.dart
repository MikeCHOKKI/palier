import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucid_core_flutter/lucid_core_flutter.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/providers.dart';
import '../../app/routes.dart';
import '../../app/theme/palier_tokens.dart';
import '../../core/ui/palier_mark.dart';
import '../../core/ui/profile_avatar.dart';
import '../../l10n/app_localizations.dart';
import '../sport/ui/sport_providers.dart';
import '../sport/ui/today_plan.dart';

/// Accueil du profil : salutation, conseils utiles, puis (lot 4) le bilan.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final profile = ref.watch(activeProfileProvider);
    if (profile == null) return const SizedBox.shrink();

    final today = DateFormat.MMMMEEEEd('fr').format(ref.watch(clockProvider)());

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(PalierSpace.page, PalierSpace.lg, PalierSpace.page, PalierSpace.xl),
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(today[0].toUpperCase() + today.substring(1), style: text.labelMedium),
                    const SizedBox(height: PalierSpace.xs),
                    Text(l10n.homeGreeting(profile.name), style: text.headlineMedium),
                  ],
                ),
              ),
              ProfileAvatar(profile: profile, size: 44),
            ],
          ),
          const SizedBox(height: PalierSpace.xl),
          if (profile.sportEnabled && ref.watch(todayPlanProvider).isNotEmpty) ...[
            const TodayPlanCard(),
            const SizedBox(height: PalierSpace.lg),
          ],
          if (!profile.hasPin) ...[
            _Tip(
              icon: Icons.lock_outline_rounded,
              title: l10n.homeTipPinTitle,
              body: l10n.homeTipPinBody,
              onTap: () => context.go(Routes.settingsLock),
            ),
            const SizedBox(height: PalierSpace.sm + 4),
          ],
          _Tip(
            icon: Icons.shield_outlined,
            title: l10n.homeTipBackupTitle,
            body: l10n.homeTipBackupBody,
            onTap: () => context.go(Routes.settingsBackup),
          ),
          const SizedBox(height: PalierSpace.xl),
          LucidCard(
            padding: const EdgeInsets.all(PalierSpace.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const PalierMark(height: 44),
                const SizedBox(height: PalierSpace.md),
                Text(l10n.homeSoonTitle, style: text.titleLarge),
                const SizedBox(height: PalierSpace.sm),
                Text(l10n.homeSoonBody, style: text.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Un conseil qui mène à l'écran où l'appliquer.
class _Tip extends StatelessWidget {
  const _Tip({required this.icon, required this.title, required this.body, required this.onTap});

  final IconData icon;
  final String title;
  final String body;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final accent = Theme.of(context).colorScheme.primary;
    return LucidCard.interactive(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: accent.withValues(alpha: 0.14), shape: BoxShape.circle),
            child: Icon(icon, size: 20, color: accent),
          ),
          const SizedBox(width: PalierSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: text.titleSmall),
                const SizedBox(height: 2),
                Text(body, style: text.bodyMedium),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: PalierColors.textLow),
        ],
      ),
    );
  }
}

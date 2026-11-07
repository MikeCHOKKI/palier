import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucid_core_flutter/lucid_core_flutter.dart';

import '../../../app/routes.dart';
import '../../../app/theme/palier_tokens.dart';
import '../../../core/ui/palier_mark.dart';
import '../../../l10n/app_localizations.dart';

/// Premier lancement : présenter Palier et créer le premier profil.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.45),
            radius: 0.9,
            colors: [Color(0x2602D1E8), Color(0x00111827)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(PalierSpace.page, PalierSpace.xxl, PalierSpace.page, PalierSpace.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Spacer(),
                const PalierMark(height: 112),
                const SizedBox(height: PalierSpace.xl),
                Text(l10n.welcomeTitle, style: text.headlineLarge),
                const SizedBox(height: PalierSpace.md),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Text(l10n.welcomeBody, style: text.bodyLarge?.copyWith(color: PalierColors.textMid)),
                ),
                const Spacer(flex: 2),
                LucidButton(label: l10n.welcomeStart, expand: true, onPressed: () => context.go(Routes.welcomeProfile)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/palier_snack.dart';
import '../../../app/providers.dart';
import '../../../app/routes.dart';
import '../../../app/theme/palier_tokens.dart';
import '../../../core/ui/pin_pad.dart';
import '../../../l10n/app_localizations.dart';

/// Choisir (ou changer) le code du profil ouvert : saisie puis confirmation.
class SetPinScreen extends ConsumerStatefulWidget {
  const SetPinScreen({super.key});

  @override
  ConsumerState<SetPinScreen> createState() => _SetPinScreenState();
}

class _SetPinScreenState extends ConsumerState<SetPinScreen> {
  String? _first;
  String? _error;

  Future<void> _onPin(String pin) async {
    final l10n = AppLocalizations.of(context);
    final first = _first;
    if (first == null) {
      setState(() {
        _first = pin;
        _error = null;
      });
      return;
    }
    if (pin != first) {
      setState(() {
        _first = null;
        _error = l10n.pinMismatch;
      });
      return;
    }

    final profile = ref.read(activeProfileProvider)!;
    await ref.read(profilesRepositoryProvider).setPin(profile.id, pin);
    if (!mounted) return;
    PalierSnack.done(ScaffoldMessenger.of(context), l10n.pinSaved);
    context.go(Routes.settingsLock);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final confirming = _first != null;

    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: PalierSpace.page, vertical: PalierSpace.md),
            child: Column(
              children: [
                Text(confirming ? l10n.pinConfirmTitle : l10n.pinSetTitle, style: text.headlineSmall),
                const SizedBox(height: PalierSpace.xs),
                Text(confirming ? l10n.pinConfirmPrompt : l10n.pinSetPrompt, style: text.bodyMedium),
                const SizedBox(height: PalierSpace.xl),
                // Une clé par étape : le pavé repart vide pour la confirmation.
                PinPad(key: ValueKey(confirming), onSubmit: _onPin),
                const SizedBox(height: PalierSpace.md),
                SizedBox(
                  height: 44,
                  child: _error == null
                      ? null
                      : Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: text.bodyMedium?.copyWith(color: PalierColors.danger),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

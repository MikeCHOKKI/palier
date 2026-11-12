import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/theme/palier_theme.dart';
import '../../app/theme/palier_tokens.dart';
import '../../l10n/app_localizations.dart';
import '../security/pin_hasher.dart';

/// Saisie d'un code de 4 à 6 chiffres : points de progression et pavé.
///
/// Le code part seul au 6ᵉ chiffre, ou avec « Valider » dès 4 chiffres. Après
/// [onSubmit], la saisie est vidée : c'est l'écran parent qui affiche le
/// résultat. Le clavier physique fonctionne aussi (chiffres, retour, entrée).
class PinPad extends StatefulWidget {
  const PinPad({super.key, required this.onSubmit, this.enabled = true});

  final Future<void> Function(String pin) onSubmit;

  /// Faux pendant un blocage : le pavé reste visible mais inactif.
  final bool enabled;

  @override
  State<PinPad> createState() => _PinPadState();
}

class _PinPadState extends State<PinPad> {
  String _pin = '';
  bool _busy = false;
  final _focus = FocusNode(debugLabel: 'PinPad');

  bool get _active => widget.enabled && !_busy;

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  void _add(String digit) {
    if (!_active || _pin.length >= PinHasher.maxLength) return;
    setState(() => _pin += digit);
    if (_pin.length == PinHasher.maxLength) _submit();
  }

  void _removeLast() {
    if (!_active || _pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Future<void> _submit() async {
    if (!_active || _pin.length < PinHasher.minLength) return;
    final pin = _pin;
    setState(() => _busy = true);
    try {
      await widget.onSubmit(pin);
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _pin = '';
        });
      }
    }
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final char = event.character;
    if (char != null && RegExp(r'^\d$').hasMatch(char)) {
      _add(char);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.backspace) {
      _removeLast();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.enter || event.logicalKey == LogicalKeyboardKey.numpadEnter) {
      _submit();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final accent = Theme.of(context).colorScheme.primary;

    return Focus(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: _onKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            liveRegion: true,
            label: l10n.pinDigitsEntered(_pin.length),
            child: ExcludeSemantics(
              child: SizedBox(
                height: 24,
                child: _busy
                    ? SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2, color: accent))
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (var i = 0; i < PinHasher.maxLength; i++)
                            _Dot(filled: i < _pin.length, optional: i >= PinHasher.minLength, color: accent),
                        ],
                      ),
              ),
            ),
          ),
          const SizedBox(height: PalierSpace.xl),
          AnimatedOpacity(
            opacity: widget.enabled ? 1 : 0.4,
            duration: const Duration(milliseconds: 200),
            child: Column(
              children: [
                for (final row in const [
                  ['1', '2', '3'],
                  ['4', '5', '6'],
                  ['7', '8', '9'],
                ])
                  _KeyRow(
                    children: [for (final d in row) _DigitKey(digit: d, onTap: _active ? () => _add(d) : null)],
                  ),
                _KeyRow(
                  children: [
                    _IconKey(
                      icon: Icons.backspace_outlined,
                      label: l10n.keypadDelete,
                      onTap: _active && _pin.isNotEmpty ? _removeLast : null,
                    ),
                    _DigitKey(digit: '0', onTap: _active ? () => _add('0') : null),
                    _IconKey(
                      icon: Icons.arrow_forward_rounded,
                      label: l10n.keypadSubmit,
                      emphasized: true,
                      onTap: _active && _pin.length >= PinHasher.minLength ? _submit : null,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.filled, required this.optional, required this.color});

  final bool filled;

  /// Les deux derniers points sont facultatifs (code de 4 ou 5 chiffres).
  final bool optional;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOutCubic,
      margin: const EdgeInsets.symmetric(horizontal: 7),
      width: filled ? 14 : 12,
      height: filled ? 14 : 12,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: filled ? color : Colors.transparent,
        border: filled ? null : Border.all(color: optional ? PalierColors.line : PalierColors.textLow, width: 1.5),
      ),
    );
  }
}

class _KeyRow extends StatelessWidget {
  const _KeyRow({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: PalierSpace.xs),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: children),
    );
  }
}

const double _keySize = 72;

class _DigitKey extends StatelessWidget {
  const _DigitKey({required this.digit, required this.onTap});

  final String digit;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return _KeyShell(
      onTap: onTap,
      background: PalierColors.surface,
      child: Text(
        digit,
        style: const TextStyle(
          fontFamily: PalierFonts.display,
          fontSize: 24,
          fontWeight: FontWeight.w500,
          color: PalierColors.textHigh,
        ),
      ),
    );
  }
}

class _IconKey extends StatelessWidget {
  const _IconKey({required this.icon, required this.label, required this.onTap, this.emphasized = false});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final on = Theme.of(context).colorScheme.onPrimary;
    final active = onTap != null;
    return Tooltip(
      message: label,
      child: Semantics(
        label: label,
        button: true,
        enabled: active,
        excludeSemantics: true,
        child: _KeyShell(
          onTap: onTap,
          background: emphasized && active ? accent : Colors.transparent,
          child: Icon(
            icon,
            size: 26,
            color: emphasized && active ? on : (active ? PalierColors.textMid : PalierColors.line),
          ),
        ),
      ),
    );
  }
}

class _KeyShell extends StatelessWidget {
  const _KeyShell({required this.onTap, required this.background, required this.child});

  final VoidCallback? onTap;
  final Color background;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Material(
        color: background,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap == null
              ? null
              : () {
                  HapticFeedback.selectionClick();
                  onTap!();
                },
          canRequestFocus: false,
          child: SizedBox.square(
            dimension: _keySize,
            child: Center(child: child),
          ),
        ),
      ),
    );
  }
}

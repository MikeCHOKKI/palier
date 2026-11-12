import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme/palier_theme.dart';
import '../../../app/theme/palier_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/money.dart';

/// Pavé de saisie d'un montant, toujours à portée de pouce.
///
/// En bas à gauche, « 000 » pour le F CFA (les prix se comptent en milliers),
/// ou la virgule pour une devise à centimes. Un appui long sur l'effacement vide
/// la saisie. Le clavier physique fonctionne aussi (chiffres, virgule, retour).
class AmountPad extends StatefulWidget {
  const AmountPad({super.key, required this.value, required this.onChanged});

  final AmountEntry value;
  final ValueChanged<AmountEntry> onChanged;

  @override
  State<AmountPad> createState() => _AmountPadState();
}

class _AmountPadState extends State<AmountPad> {
  final _focus = FocusNode(debugLabel: 'AmountPad');

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  AmountEntry get _value => widget.value;

  void _emit(AmountEntry next) {
    if (next != _value) widget.onChanged(next);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final char = event.character;
    if (char != null && RegExp(r'^\d$').hasMatch(char)) {
      _emit(_value.digit(char));
      return KeyEventResult.handled;
    }
    if (char == ',' || char == '.') {
      _emit(_value.separator());
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.backspace) {
      _emit(_value.backspace());
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final decimals = _value.allowsDecimals;

    Widget digit(String d) => _PadKey(
      label: d,
      onTap: () => _emit(_value.digit(d)),
      child: Text(d, style: _digitStyle),
    );

    return Focus(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: _onKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final row in const [
            ['1', '2', '3'],
            ['4', '5', '6'],
            ['7', '8', '9'],
          ])
            _PadRow(children: [for (final d in row) digit(d)]),
          _PadRow(
            children: [
              if (decimals)
                _PadKey(
                  label: l10n.amountPadSeparator,
                  onTap: _value.hasSeparator ? null : () => _emit(_value.separator()),
                  child: Text(',', style: _digitStyle.copyWith(color: _value.hasSeparator ? PalierColors.line : null)),
                )
              else
                _PadKey(
                  label: l10n.amountPadThousands,
                  onTap: _value.isZero ? null : () => _emit(_value.thousands()),
                  child: Text(
                    '000',
                    style: _digitStyle.copyWith(fontSize: 18, color: _value.isZero ? PalierColors.line : null),
                  ),
                ),
              digit('0'),
              _PadKey(
                label: l10n.keypadDelete,
                quiet: true,
                onTap: _value.isZero && !_value.hasSeparator ? null : () => _emit(_value.backspace()),
                onLongPress: () => _emit(AmountEntry.empty(_value.currency)),
                child: const Icon(Icons.backspace_outlined, size: 24),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

const _digitStyle = TextStyle(
  fontFamily: PalierFonts.display,
  fontSize: 22,
  fontWeight: FontWeight.w500,
  color: PalierColors.textHigh,
);

class _PadRow extends StatelessWidget {
  const _PadRow({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: PalierSpace.sm),
      child: Row(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(width: PalierSpace.sm),
            Expanded(child: children[i]),
          ],
        ],
      ),
    );
  }
}

class _PadKey extends StatelessWidget {
  const _PadKey({required this.label, required this.onTap, required this.child, this.onLongPress, this.quiet = false});

  final String label;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Widget child;

  /// Touche d'action (effacer) : sans fond, pour que les chiffres dominent.
  final bool quiet;

  @override
  Widget build(BuildContext context) {
    final active = onTap != null;
    return Semantics(
      label: label,
      button: true,
      enabled: active,
      excludeSemantics: true,
      child: Material(
        color: quiet ? Colors.transparent : PalierColors.surface,
        borderRadius: BorderRadius.circular(PalierRadius.sm),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          canRequestFocus: false,
          onTap: active
              ? () {
                  HapticFeedback.selectionClick();
                  onTap!();
                }
              : null,
          onLongPress: active ? onLongPress : null,
          child: SizedBox(
            height: 50,
            child: Center(
              child: IconTheme.merge(
                data: IconThemeData(color: active ? PalierColors.textMid : PalierColors.line),
                child: DefaultTextStyle.merge(
                  style: TextStyle(color: active ? PalierColors.textHigh : PalierColors.textLow),
                  child: child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Le montant en grand, au centre : c'est lui que l'on vérifie d'un coup d'œil.
class AmountDisplay extends StatelessWidget {
  const AmountDisplay({super.key, required this.amount, this.color});

  final AmountEntry amount;

  /// Couleur d'un montant saisi ; par défaut le texte principal.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final color = amount.isZero ? PalierColors.textLow : (this.color ?? PalierColors.textHigh);
    return Semantics(
      liveRegion: true,
      label: l10n.amountLabel(formatMoney(amount.minor, amount.currency)),
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: PalierSpace.md),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  amount.display,
                  style: TextStyle(
                    fontFamily: PalierFonts.display,
                    fontSize: 44,
                    fontWeight: FontWeight.w600,
                    height: 1.1,
                    color: color,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(width: PalierSpace.sm),
                Text(
                  amount.currency.symbol,
                  style: manrope(size: 18, weight: FontWeight.w600, color: PalierColors.textMid),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Pavé, message éventuel et bouton d'enregistrement, posés sur le fond le plus profond.
class AmountPanel extends StatelessWidget {
  const AmountPanel({
    super.key,
    required this.amount,
    required this.onAmountChanged,
    required this.problem,
    required this.saveLabel,
    required this.saving,
    required this.onSave,
  });

  final AmountEntry amount;
  final ValueChanged<AmountEntry> onAmountChanged;
  final String? problem;
  final String saveLabel;
  final bool saving;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: PalierColors.deep,
        border: Border(top: BorderSide(color: PalierColors.line)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(PalierSpace.page, PalierSpace.sm + 4, PalierSpace.page, PalierSpace.sm + 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AmountPad(value: amount, onChanged: onAmountChanged),
            if (problem != null)
              Padding(
                padding: const EdgeInsets.only(bottom: PalierSpace.sm),
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    problem!,
                    style: manrope(size: 14, weight: FontWeight.w600, color: PalierColors.danger),
                  ),
                ),
              ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: saving ? null : onSave,
                child: saving
                    ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(saveLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

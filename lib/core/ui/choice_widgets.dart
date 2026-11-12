import 'package:material_ui/material_ui.dart';

import '../../app/theme/palier_theme.dart';
import '../../app/theme/palier_tokens.dart';

// Pastilles et titres de choix, partagés par les dépenses et le sport.

/// Titre court au-dessus d'un groupe de choix.
class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: PalierSpace.md + 4, bottom: PalierSpace.sm),
      child: Text(text, style: Theme.of(context).textTheme.labelMedium),
    );
  }
}

/// Une pastille à choisir (compte, date) : contour discret, accent quand elle est choisie.
class ChoicePill extends StatelessWidget {
  const ChoicePill({super.key, required this.label, required this.selected, required this.onTap, this.icon});

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? accent.withValues(alpha: 0.16) : Colors.transparent,
        shape: StadiumBorder(side: BorderSide(color: selected ? accent : PalierColors.line)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: kPalierMinTarget),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: PalierSpace.md),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 18, color: selected ? accent : PalierColors.textMid),
                    const SizedBox(width: PalierSpace.sm),
                  ],
                  Text(
                    label,
                    style: manrope(
                      size: 14,
                      weight: FontWeight.w600,
                      color: selected ? PalierColors.textHigh : PalierColors.textMid,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Rangée de pastilles qui défile si elle déborde.
class PillRow extends StatelessWidget {
  const PillRow({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        children: [
          for (var i = 0; i < children.length; i++) ...[if (i > 0) const SizedBox(width: PalierSpace.sm), children[i]],
        ],
      ),
    );
  }
}

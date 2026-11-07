import 'package:flutter/material.dart';

import '../../app/theme/palier_tokens.dart';

/// Le symbole Palier : trois marches et la personne arrivée en haut.
///
/// Même géométrie que `branding/sources/palier-symbole.svg`, dessinée en
/// vectoriel pour rester nette à toutes les tailles sans dépendance SVG.
class PalierMark extends StatelessWidget {
  const PalierMark({super.key, this.height = 96, this.dotColor, this.stepsColor = PalierColors.steel});

  final double height;

  /// Couleur de la personne ; par défaut l'accent du thème.
  final Color? dotColor;
  final Color stepsColor;

  /// Boîte du symbole dans le SVG source.
  static const Size _box = Size(568, 662);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Palier',
      image: true,
      child: SizedBox(
        height: height,
        width: height * _box.width / _box.height,
        child: CustomPaint(painter: _MarkPainter(stepsColor, dotColor ?? Theme.of(context).colorScheme.primary)),
      ),
    );
  }
}

class _MarkPainter extends CustomPainter {
  const _MarkPainter(this.steps, this.dot);

  final Color steps;
  final Color dot;

  @override
  void paint(Canvas canvas, Size size) {
    canvas
      ..scale(size.width / PalierMark._box.width)
      ..translate(-228, -110);

    final stairs = Path()
      ..moveTo(256, 744)
      ..lineTo(256, 608)
      ..lineTo(416, 608)
      ..lineTo(416, 448)
      ..lineTo(576, 448)
      ..lineTo(576, 288)
      ..lineTo(768, 288)
      ..lineTo(768, 744)
      ..close();

    // Le trait épais du même bleu arrondit les angles extérieurs, comme dans le SVG.
    canvas
      ..drawPath(stairs, Paint()..color = steps)
      ..drawPath(
        stairs,
        Paint()
          ..color = steps
          ..style = PaintingStyle.stroke
          ..strokeWidth = 56
          ..strokeJoin = StrokeJoin.round,
      )
      ..drawCircle(const Offset(672, 168), 58, Paint()..color = dot);
  }

  @override
  bool shouldRepaint(_MarkPainter old) => old.steps != steps || old.dot != dot;
}

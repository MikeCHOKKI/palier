import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:palier/app/theme/palier_accent.dart';
import 'package:palier/app/theme/palier_tokens.dart';

/// Rapport de contraste WCAG 2.x entre deux couleurs opaques.
double contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (max(la, lb) + 0.05) / (min(la, lb) + 0.05);
}

void main() {
  group('accents', () {
    for (final accent in PalierAccent.values) {
      test('${accent.name} se voit sur le bleu nuit et porte un texte lisible', () {
        expect(contrast(accent.color, PalierColors.night), greaterThanOrEqualTo(3));
        expect(contrast(accent.color, PalierColors.surface), greaterThanOrEqualTo(3));
        expect(contrast(PalierAccent.onAccent, accent.color), greaterThanOrEqualTo(4.5));
      });
    }

    test('un nom inconnu revient au cyan', () {
      expect(PalierAccent.fromName('violet'), PalierAccent.cyan);
      expect(PalierAccent.fromName(null), PalierAccent.cyan);
    });
  });

  group('textes', () {
    for (final (name, color) in [
      ('principal', PalierColors.textHigh),
      ('secondaire', PalierColors.textMid),
      ('d’appoint', PalierColors.textLow),
    ]) {
      test('le texte $name atteint 4,5:1 sur le fond et sur les cartes', () {
        expect(contrast(color, PalierColors.night), greaterThanOrEqualTo(4.5));
        expect(contrast(color, PalierColors.surface), greaterThanOrEqualTo(4.5));
      });
    }

    test('le texte principal reste lisible sur une surface relevée', () {
      expect(contrast(PalierColors.textHigh, PalierColors.indigo), greaterThanOrEqualTo(4.5));
      expect(contrast(PalierColors.textMid, PalierColors.indigo), greaterThanOrEqualTo(4.5));
    });
  });
}

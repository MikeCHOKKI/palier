import 'package:flutter/material.dart';

/// Couleur d'accent choisie par chaque profil : c'est elle qui colore les
/// boutons, l'onglet actif et les réussites de la personne.
///
/// Toutes restent lisibles sur le bleu nuit (au moins 3:1) et portent un texte
/// [onAccent] à au moins 4,5:1 ; `test/app/theme/palier_accent_test.dart` le
/// vérifie pour chacune.
enum PalierAccent {
  cyan(Color(0xFF02D1E8)),
  ciel(Color(0xFF6CBBFF)),
  menthe(Color(0xFF3DDC97)),
  ambre(Color(0xFFF5B83D)),
  corail(Color(0xFFFF8F7E)),
  lilas(Color(0xFFBBA9FF));

  const PalierAccent(this.color);

  final Color color;

  /// Texte et icônes posés sur l'accent.
  static const Color onAccent = Color(0xFF020913);

  /// Retrouve un accent enregistré ; un nom inconnu revient au cyan.
  static PalierAccent fromName(String? name) {
    return PalierAccent.values.firstWhere((a) => a.name == name, orElse: () => PalierAccent.cyan);
  }
}

import 'package:flutter/material.dart';

/// Couleurs de Palier, relevées dans l'univers Ekim (voir branding/LISEZMOI.md).
///
/// Thème sombre seulement : l'application se consulte surtout le soir, au
/// calme, et le bleu nuit porte l'identité. Le cyan (ou l'accent choisi par le
/// profil) est réservé à ce qui compte : l'action principale, un objectif
/// atteint, la personne dans le symbole.
abstract final class PalierColors {
  /// Fond le plus profond (écran de démarrage, zones en retrait).
  static const deep = Color(0xFF020913);

  /// Fond de l'application.
  static const night = Color(0xFF111827);

  /// Surface des cartes et des barres.
  static const surface = Color(0xFF172238);

  /// Surface relevée (champ actif, carte choisie).
  static const indigo = Color(0xFF172D4F);

  /// Filet des cartes et séparateurs.
  static const line = Color(0xFF2A3A57);

  /// Bleu acier : les marches du symbole, la couleur de marque.
  static const steel = Color(0xFF0A6A9E);

  /// Cyan : l'accent par défaut.
  static const cyan = Color(0xFF02D1E8);

  /// Texte principal.
  static const textHigh = Color(0xFFE6EEF6);

  /// Texte secondaire (au moins 4,5:1 sur [night] et [surface]).
  static const textMid = Color(0xFFAEBCCB);

  /// Texte d'appoint : dates, unités (au moins 4,5:1 sur [night]).
  static const textLow = Color(0xFF8C9DB0);

  static const danger = Color(0xFFFF7B7B);
  static const success = Color(0xFF3DDC97);
}

/// Rythme d'espacement : multiples de 4.
abstract final class PalierSpace {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;

  /// Marge latérale des écrans.
  static const double page = 20;
}

abstract final class PalierRadius {
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
}

/// Taille minimale d'une cible tactile.
const double kPalierMinTarget = 48;

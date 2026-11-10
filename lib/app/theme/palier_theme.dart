import 'package:flutter/material.dart';
import 'package:lucid_core_flutter/lucid_core_flutter.dart';

import 'palier_accent.dart';
import 'palier_tokens.dart';

/// Polices embarquées (OFL) : Unbounded pour les titres, Manrope pour le texte.
abstract final class PalierFonts {
  static const display = 'Unbounded';
  static const text = 'Manrope';
}

/// Style Manrope à une graisse donnée.
///
/// Manrope est une police variable : on règle l'axe `wght` en plus de
/// [FontWeight], sinon toutes les graisses s'affichent identiques.
TextStyle manrope({
  required double size,
  FontWeight weight = FontWeight.w400,
  Color color = PalierColors.textHigh,
  double height = 1.45,
  double letterSpacing = 0,
}) {
  return TextStyle(
    fontFamily: PalierFonts.text,
    fontSize: size,
    fontWeight: weight,
    fontVariations: [FontVariation.weight(weight.value.toDouble())],
    color: color,
    height: height,
    letterSpacing: letterSpacing,
  );
}

TextStyle _unbounded(double size, FontWeight weight, {double height = 1.2}) {
  return TextStyle(
    fontFamily: PalierFonts.display,
    fontSize: size,
    fontWeight: weight,
    color: PalierColors.textHigh,
    height: height,
    letterSpacing: -0.2,
  );
}

/// Le thème Palier pour le socle `lucid_core_flutter` : ses widgets d'état
/// (vide, erreur) lisent ces jetons via `LucidThemeProvider`.
LucidAppTheme palierLucidTheme(PalierAccent accent) {
  return LucidAppTheme(
    name: 'palier-${accent.name}',
    mode: LucidThemeMode.dark,
    brightness: Brightness.dark,
    primary: accent.color,
    onPrimary: PalierAccent.onAccent,
    secondary: PalierColors.steel,
    onSecondary: PalierColors.textHigh,
    accent: accent.color,
    background: PalierColors.night,
    onBackground: PalierColors.textHigh,
    surface: PalierColors.surface,
    onSurface: PalierColors.textHigh,
    error: PalierColors.danger,
    onError: PalierColors.deep,
    divider: PalierColors.line,
    cardColor: PalierColors.surface,
    scaffoldBackgroundColor: PalierColors.night,
    cardElevation: 0,
    elevatedButtonElevation: 0,
    borderRadius: PalierRadius.md,
    cardBorderRadius: PalierRadius.lg,
    fontFamily: PalierFonts.text,
    displayFontFamily: PalierFonts.display,
    gradientStart: accent.color.withValues(alpha: 0.18),
    gradientEnd: PalierColors.steel.withValues(alpha: 0.08),
  );
}

/// Le thème Material de Palier, coloré par l'accent du profil actif.
ThemeData palierTheme(PalierAccent accent) {
  final base = palierLucidTheme(accent).toThemeData();
  final scheme = base.colorScheme.copyWith(
    outline: PalierColors.textLow,
    outlineVariant: PalierColors.line,
    onSurfaceVariant: PalierColors.textMid,
    surfaceContainerHighest: PalierColors.indigo,
    primaryContainer: accent.color.withValues(alpha: 0.16),
    onPrimaryContainer: accent.color,
  );

  final textTheme = TextTheme(
    displaySmall: _unbounded(32, FontWeight.w600),
    headlineLarge: _unbounded(28, FontWeight.w600),
    headlineMedium: _unbounded(24, FontWeight.w600),
    headlineSmall: _unbounded(20, FontWeight.w600),
    titleLarge: _unbounded(18, FontWeight.w500),
    titleMedium: manrope(size: 16, weight: FontWeight.w700),
    titleSmall: manrope(size: 14, weight: FontWeight.w700),
    bodyLarge: manrope(size: 16),
    bodyMedium: manrope(size: 15, color: PalierColors.textMid),
    bodySmall: manrope(size: 13, color: PalierColors.textLow),
    labelLarge: manrope(size: 15, weight: FontWeight.w700),
    labelMedium: manrope(size: 13, weight: FontWeight.w600, color: PalierColors.textMid),
    labelSmall: manrope(size: 12, weight: FontWeight.w600, color: PalierColors.textLow, letterSpacing: 0.2),
  );

  final buttonShape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(PalierRadius.md));
  const buttonSize = Size(kPalierMinTarget, 52);
  final buttonText = manrope(size: 15, weight: FontWeight.w700);

  return base.copyWith(
    colorScheme: scheme,
    textTheme: textTheme,
    primaryTextTheme: textTheme,
    splashFactory: InkSparkle.splashFactory,
    appBarTheme: base.appBarTheme.copyWith(
      backgroundColor: PalierColors.night,
      foregroundColor: PalierColors.textHigh,
      centerTitle: false,
      titleTextStyle: _unbounded(18, FontWeight.w500),
      scrolledUnderElevation: 0,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: accent.color,
        foregroundColor: PalierAccent.onAccent,
        disabledBackgroundColor: PalierColors.indigo,
        disabledForegroundColor: PalierColors.textLow,
        elevation: 0,
        minimumSize: buttonSize,
        shape: buttonShape,
        textStyle: buttonText,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: PalierColors.indigo,
        foregroundColor: PalierColors.textHigh,
        minimumSize: buttonSize,
        shape: buttonShape,
        textStyle: buttonText,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: PalierColors.textHigh,
        side: const BorderSide(color: PalierColors.line),
        minimumSize: buttonSize,
        shape: buttonShape,
        textStyle: buttonText,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: accent.color,
        minimumSize: const Size(kPalierMinTarget, kPalierMinTarget),
        textStyle: buttonText,
      ),
    ),
    inputDecorationTheme: base.inputDecorationTheme.copyWith(
      fillColor: PalierColors.surface,
      labelStyle: manrope(size: 15, color: PalierColors.textMid),
      floatingLabelStyle: manrope(size: 14, weight: FontWeight.w600, color: accent.color),
      hintStyle: manrope(size: 15, color: PalierColors.textLow),
      helperStyle: manrope(size: 13, color: PalierColors.textLow),
      errorStyle: manrope(size: 13, color: PalierColors.danger),
      // Sans plafond, Material coupe l'aide et l'erreur à une ligne, en « … ».
      helperMaxLines: 3,
      errorMaxLines: 3,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(PalierRadius.md),
        borderSide: const BorderSide(color: PalierColors.line),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: PalierColors.deep,
      indicatorColor: accent.color.withValues(alpha: 0.16),
      height: 72,
      elevation: 0,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(color: states.contains(WidgetState.selected) ? accent.color : PalierColors.textLow),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => manrope(
          size: 12,
          weight: FontWeight.w700,
          color: states.contains(WidgetState.selected) ? PalierColors.textHigh : PalierColors.textLow,
        ),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? PalierAccent.onAccent : PalierColors.textMid,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? accent.color : PalierColors.indigo,
      ),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        backgroundColor: PalierColors.surface,
        foregroundColor: PalierColors.textMid,
        selectedBackgroundColor: accent.color.withValues(alpha: 0.18),
        selectedForegroundColor: PalierColors.textHigh,
        side: const BorderSide(color: PalierColors.line),
        minimumSize: const Size(kPalierMinTarget, kPalierMinTarget),
        textStyle: manrope(size: 14, weight: FontWeight.w600),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: PalierColors.indigo,
      contentTextStyle: manrope(size: 15),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(PalierRadius.sm)),
      // Une croix, et un glissement de côté plutôt que vers le bas (geste peu
      // naturel au-dessus de la barre de navigation).
      showCloseIcon: true,
      closeIconColor: PalierColors.textMid,
      dismissDirection: DismissDirection.horizontal,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: PalierColors.surface,
      titleTextStyle: _unbounded(18, FontWeight.w500),
      contentTextStyle: manrope(size: 15, color: PalierColors.textMid),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(PalierRadius.lg)),
    ),
    dividerTheme: const DividerThemeData(color: PalierColors.line, thickness: 1, space: 1),
    listTileTheme: ListTileThemeData(
      iconColor: PalierColors.textMid,
      titleTextStyle: manrope(size: 16, weight: FontWeight.w600),
      subtitleTextStyle: manrope(size: 14, color: PalierColors.textMid),
      minVerticalPadding: 12,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: accent.color),
  );
}

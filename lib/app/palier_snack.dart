import 'package:lucid_core_flutter/lucid_core_flutter.dart' show LucidSnack;
import 'package:material_ui/material_ui.dart';

import 'theme/palier_tokens.dart';

/// Les messages de bas d'écran de Palier : la pastille du socle, avec une
/// icône selon ce qui vient de se passer. Le messager se capture avant tout
/// `await` ou `pop`.
abstract final class PalierSnack {
  /// Une action réussie (enregistré, exporté…), que [onUndo] peut rattraper
  /// quand un seul geste l'a faite.
  static void done(ScaffoldMessengerState messenger, String message, {String? undoLabel, VoidCallback? onUndo}) =>
      LucidSnack.showOn(
        messenger,
        message: message,
        icon: Icons.check_rounded,
        actionLabel: onUndo == null ? null : undoLabel,
        onAction: onUndo,
      );

  /// Une suppression, que [onUndo] peut rattraper.
  static void deleted(ScaffoldMessengerState messenger, String message, {String? undoLabel, VoidCallback? onUndo}) =>
      LucidSnack.showOn(
        messenger,
        message: message,
        icon: Icons.delete_outline_rounded,
        actionLabel: onUndo == null ? null : undoLabel,
        onAction: onUndo,
      );

  /// Fait, mais avec un seuil franchi (plafond de budget).
  static void warn(ScaffoldMessengerState messenger, String message) =>
      LucidSnack.showOn(messenger, message: message, icon: Icons.speed_rounded, iconColor: PalierColors.warning);

  /// Ce qui n'a pas pu se faire.
  static void problem(ScaffoldMessengerState messenger, String message) =>
      LucidSnack.showOn(messenger, message: message, icon: Icons.error_outline_rounded, iconColor: PalierColors.danger);
}

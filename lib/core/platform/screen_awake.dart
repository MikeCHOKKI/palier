import 'package:flutter/services.dart';

/// Garder l'écran allumé, le temps d'une séance guidée.
abstract interface class ScreenAwake {
  Future<void> keepOn(bool on);
}

/// L'écran du téléphone, par le canal `palier/ecran` de MainActivity.
class DeviceScreenAwake implements ScreenAwake {
  const DeviceScreenAwake();

  static const _channel = MethodChannel('palier/ecran');

  @override
  Future<void> keepOn(bool on) async {
    try {
      await _channel.invokeMethod<void>('garderAllume', on);
    } on MissingPluginException {
      // Hors d'Android (tests, bureau) : rien à faire, l'écran s'éteindra comme d'habitude.
    } on PlatformException {
      // Un écran qui s'éteint ne doit pas interrompre la séance.
    }
  }
}

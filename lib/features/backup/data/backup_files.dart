import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

/// Un fichier choisi par la personne.
class PickedFile {
  const PickedFile({required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;
}

/// Enregistrer et choisir des fichiers d'export, séparé de `file_picker` pour
/// pouvoir le simuler dans les tests.
abstract interface class BackupFiles {
  /// `false` si la personne a annulé.
  Future<bool> save(String fileName, Uint8List bytes);

  /// `null` si la personne a annulé.
  Future<PickedFile?> pick();
}

class DeviceBackupFiles implements BackupFiles {
  const DeviceBackupFiles();

  @override
  Future<bool> save(String fileName, Uint8List bytes) async {
    final uri = await FilePicker.saveFile(fileName: fileName, bytes: bytes);
    return uri != null;
  }

  @override
  Future<PickedFile?> pick() async {
    final files = await FilePicker.pickFiles();
    if (files.isEmpty) return null;
    final file = files.single;
    return PickedFile(name: file.name, bytes: await file.xFile.readAsBytes());
  }
}

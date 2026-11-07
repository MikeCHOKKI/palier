import 'dart:typed_data';

import 'package:palier/core/security/biometric_gate.dart';
import 'package:palier/features/backup/data/backup_files.dart';

class FakeBiometricGate implements BiometricGate {
  FakeBiometricGate({this.available = false, this.succeeds = true});

  bool available;
  bool succeeds;
  int prompts = 0;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<bool> authenticate(String reason) async {
    prompts++;
    return succeeds;
  }
}

class FakeBackupFiles implements BackupFiles {
  final Map<String, Uint8List> saved = {};
  PickedFile? toPick;

  @override
  Future<bool> save(String fileName, Uint8List bytes) async {
    saved[fileName] = bytes;
    return true;
  }

  @override
  Future<PickedFile?> pick() async => toPick;
}

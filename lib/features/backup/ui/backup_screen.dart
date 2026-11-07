import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucid_core_flutter/lucid_core_flutter.dart';

import '../../../app/providers.dart';
import '../../../app/theme/palier_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../data/backup_files.dart';
import '../domain/backup_codec.dart';

/// Exporter le profil ouvert, ou importer un profil depuis un fichier.
class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key});

  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  final _exportForm = GlobalKey<FormState>();
  final _exportPassword = TextEditingController();
  final _exportConfirm = TextEditingController();
  final _importPassword = TextEditingController();
  PickedFile? _picked;
  String? _importError;
  bool _exporting = false;
  bool _importing = false;

  @override
  void dispose() {
    _exportPassword.dispose();
    _exportConfirm.dispose();
    _importPassword.dispose();
    super.dispose();
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _export() async {
    if (!_exportForm.currentState!.validate()) return;
    final l10n = AppLocalizations.of(context);
    final profile = ref.read(activeProfileProvider)!;
    setState(() => _exporting = true);
    try {
      final bytes = await ref.read(backupServiceProvider).exportProfile(profile.id, _exportPassword.text);
      final date = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final saved = await ref.read(backupFilesProvider).save('palier-$date.${BackupCodec.extension}', bytes);
      if (!mounted) return;
      if (saved) {
        _exportPassword.clear();
        _exportConfirm.clear();
        _toast(l10n.backupExported);
      }
    } on Object {
      if (mounted) _toast(l10n.errorGeneric);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _choose() async {
    final file = await ref.read(backupFilesProvider).pick();
    if (file != null && mounted) {
      setState(() {
        _picked = file;
        _importError = null;
      });
    }
  }

  Future<void> _import() async {
    final picked = _picked;
    if (picked == null) return;
    final l10n = AppLocalizations.of(context);
    final service = ref.read(backupServiceProvider);
    setState(() {
      _importing = true;
      _importError = null;
    });
    try {
      final preview = await service.open(picked.bytes, _importPassword.text);
      if (!mounted) return;
      if (preview.existsOnDevice && !await _confirmReplace(preview.profile.name)) return;
      await service.import(preview);
      if (!mounted) return;
      setState(() {
        _picked = null;
        _importPassword.clear();
      });
      _toast(l10n.backupImported(preview.profile.name));
    } on BackupException catch (e) {
      if (mounted) {
        setState(
          () => _importError = switch (e.failure) {
            BackupFailure.wrongPassword => l10n.backupWrongPassword,
            BackupFailure.invalidFile => l10n.backupInvalidFile,
            BackupFailure.newerVersion => l10n.backupNewerVersion,
          },
        );
      }
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<bool> _confirmReplace(String name) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.backupReplaceTitle(name)),
        content: Text(l10n.backupReplaceBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancel)),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text(l10n.backupReplace)),
        ],
      ),
    );
    return confirmed ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    const minLength = BackupCodec.minPasswordLength;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.backupTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(PalierSpace.page, PalierSpace.sm, PalierSpace.page, PalierSpace.xl),
          children: [
            LucidCard(
              padding: const EdgeInsets.all(PalierSpace.lg - 4),
              child: Form(
                key: _exportForm,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(l10n.backupExportTitle, style: text.titleLarge),
                    const SizedBox(height: PalierSpace.sm),
                    Text(l10n.backupExportBody, style: text.bodyMedium),
                    const SizedBox(height: PalierSpace.lg - 4),
                    LucidTextField.password(
                      controller: _exportPassword,
                      label: l10n.backupPasswordLabel,
                      requireStrong: false,
                      textInputAction: TextInputAction.next,
                      validator: (v) => (v ?? '').length < minLength ? l10n.backupPasswordTooShort(minLength) : null,
                    ),
                    const SizedBox(height: PalierSpace.sm + 4),
                    LucidTextField.password(
                      controller: _exportConfirm,
                      label: l10n.backupPasswordConfirmLabel,
                      requireStrong: false,
                      textInputAction: TextInputAction.done,
                      validator: (v) => v != _exportPassword.text ? l10n.backupPasswordMismatch : null,
                    ),
                    const SizedBox(height: PalierSpace.lg - 4),
                    LucidButton(
                      label: l10n.backupExportAction,
                      icon: Icons.ios_share_rounded,
                      isLoading: _exporting,
                      onPressed: _exporting ? null : _export,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: PalierSpace.md),
            LucidCard(
              padding: const EdgeInsets.all(PalierSpace.lg - 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(l10n.backupImportTitle, style: text.titleLarge),
                  const SizedBox(height: PalierSpace.sm),
                  Text(l10n.backupImportBody, style: text.bodyMedium),
                  const SizedBox(height: PalierSpace.lg - 4),
                  if (_picked == null)
                    LucidButton(
                      label: l10n.backupImportChoose,
                      icon: Icons.folder_open_rounded,
                      variant: LucidButtonVariant.outlined,
                      onPressed: _choose,
                    )
                  else ...[
                    Row(
                      children: [
                        const Icon(Icons.insert_drive_file_outlined, size: 20, color: PalierColors.textMid),
                        const SizedBox(width: PalierSpace.sm),
                        Expanded(
                          child: Text(
                            l10n.backupImportFile(_picked!.name),
                            style: text.bodyMedium,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          tooltip: l10n.backupImportChoose,
                          onPressed: _choose,
                          icon: const Icon(Icons.swap_horiz_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: PalierSpace.sm),
                    LucidTextField.password(
                      controller: _importPassword,
                      label: l10n.backupImportPasswordLabel,
                      requireStrong: false,
                      onSubmitted: (_) => _import(),
                    ),
                    if (_importError != null) ...[
                      const SizedBox(height: PalierSpace.sm),
                      Text(_importError!, style: text.bodyMedium?.copyWith(color: PalierColors.danger)),
                    ],
                    const SizedBox(height: PalierSpace.lg - 4),
                    LucidButton(
                      label: l10n.backupImportAction,
                      icon: Icons.download_rounded,
                      isLoading: _importing,
                      onPressed: _importing ? null : _import,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
// Ses push/pop sur BuildContext masqueraient ceux de go_router.
import 'package:lucid_core_flutter/lucid_core_flutter.dart' hide LucidBuildContextExtensions;

import '../../../app/providers.dart';
import '../../../app/routes.dart';
import '../../../app/theme/palier_accent.dart';
import '../../../app/theme/palier_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/expense_kinds.dart';
import '../domain/expenses.dart';
import 'expense_visuals.dart';
import 'expense_widgets.dart';
import 'expenses_providers.dart';

/// Les catégories du profil, dépenses puis revenus.
class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final categories = ref.watch(categoriesProvider(null)).value;

    List<Widget> section(String title, CategoryKind kind) {
      final list = categories!.where((c) => c.kind == kind).toList();
      return [
        Padding(
          padding: const EdgeInsets.only(top: PalierSpace.lg, bottom: PalierSpace.xs),
          child: Text(title, style: text.titleLarge),
        ),
        if (list.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: PalierSpace.sm),
            child: Text(l10n.categoryEmpty, style: text.bodyMedium),
          ),
        for (final category in list)
          ListTile(
            key: ValueKey(category.id),
            contentPadding: EdgeInsets.zero,
            leading: OperationBadge(
              kind: kind == CategoryKind.income ? OperationKind.income : OperationKind.expense,
              icon: category.icon,
            ),
            title: Text(category.name),
            trailing: const Icon(Icons.chevron_right_rounded, color: PalierColors.textLow),
            onTap: () => context.push(Routes.expensesCategory(category.id)),
          ),
      ];
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.categoriesTitle)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(Routes.expensesCategoryNew),
        icon: const Icon(Icons.add_rounded),
        label: Text(l10n.categoriesAdd),
      ),
      body: categories == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(PalierSpace.page, 0, PalierSpace.page, 96),
              children: [
                ...section(l10n.categoriesExpenses, CategoryKind.expense),
                ...section(l10n.categoriesIncome, CategoryKind.income),
              ],
            ),
    );
  }
}

/// Créer ou modifier une catégorie : nom, type (à la création) et icône.
class CategoryFormScreen extends ConsumerStatefulWidget {
  const CategoryFormScreen({super.key, this.categoryId});

  final String? categoryId;

  @override
  ConsumerState<CategoryFormScreen> createState() => _CategoryFormScreenState();
}

class _CategoryFormScreenState extends ConsumerState<CategoryFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  CategoryKind _kind = CategoryKind.expense;
  String _icon = categoryIcons.keys.first;
  bool _saving = false;
  bool _filled = false;

  bool get _editing => widget.categoryId != null;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _fill(Category category) {
    if (_filled) return;
    _filled = true;
    _name.text = category.name;
    _kind = category.kind;
    _icon = category.icon;
  }

  Future<void> _save(Category? existing) async {
    if (!_formKey.currentState!.validate()) return;
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final repo = ref.read(expensesRepositoryProvider);
    setState(() => _saving = true);
    try {
      if (existing == null) {
        final profileId = ref.read(activeProfileIdProvider)!;
        await repo.createCategory(profileId, CategoryDraft(name: _name.text, kind: _kind, icon: _icon));
      } else {
        await repo.updateCategory(existing.id, name: _name.text, icon: _icon);
      }
      if (!mounted) return;
      context.pop();
      messenger.showSnackBar(SnackBar(content: Text(l10n.categorySaved)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete(Category category) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.categoryDeleteTitle(category.name)),
        content: Text(l10n.categoryDeleteBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancel)),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: PalierColors.danger),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await ref.read(expensesRepositoryProvider).deleteCategory(category.id);
    if (!mounted) return;
    context.pop();
    messenger.showSnackBar(SnackBar(content: Text(l10n.categoryDeleted)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final categories = ref.watch(categoriesProvider(null)).value;
    Category? existing;
    if (_editing && categories != null) {
      for (final category in categories) {
        if (category.id == widget.categoryId) existing = category;
      }
      if (existing != null) _fill(existing);
    }
    final ready = !_editing || existing != null;

    return Scaffold(
      appBar: AppBar(title: Text(_editing ? l10n.categoryEditTitle : l10n.categoryNewTitle)),
      body: !ready
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    PalierSpace.page,
                    PalierSpace.sm,
                    PalierSpace.page,
                    PalierSpace.xl,
                  ),
                  children: [
                    LucidTextField(
                      controller: _name,
                      label: l10n.categoryNameLabel,
                      autofocus: !_editing,
                      textInputAction: TextInputAction.done,
                      inputFormatters: [LengthLimitingTextInputFormatter(CategoryDraft.maxNameLength)],
                      validator: (value) => (value?.trim() ?? '').isEmpty ? l10n.categoryNameRequired : null,
                    ),
                    if (!_editing) ...[
                      FieldLabel(l10n.categoryKindLabel),
                      PillRow(
                        children: [
                          ChoicePill(
                            label: l10n.categoriesExpenses,
                            selected: _kind == CategoryKind.expense,
                            onTap: () => setState(() => _kind = CategoryKind.expense),
                          ),
                          ChoicePill(
                            label: l10n.categoriesIncome,
                            selected: _kind == CategoryKind.income,
                            onTap: () => setState(() => _kind = CategoryKind.income),
                          ),
                        ],
                      ),
                    ],
                    FieldLabel(l10n.categoryIconLabel),
                    _IconGrid(selected: _icon, onSelect: (key) => setState(() => _icon = key)),
                    const SizedBox(height: PalierSpace.xl),
                    LucidButton(
                      label: l10n.accountSave,
                      expand: true,
                      isLoading: _saving,
                      onPressed: () => _save(existing),
                    ),
                    if (existing != null) ...[
                      const SizedBox(height: PalierSpace.sm),
                      TextButton.icon(
                        style: TextButton.styleFrom(foregroundColor: PalierColors.danger),
                        onPressed: () => _delete(existing!),
                        icon: const Icon(Icons.delete_outline_rounded),
                        label: Text(l10n.categoryDelete),
                      ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }
}

class _IconGrid extends StatelessWidget {
  const _IconGrid({required this.selected, required this.onSelect});

  final String selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Wrap(
      spacing: PalierSpace.sm,
      runSpacing: PalierSpace.sm,
      children: [
        for (final MapEntry(:key, :value) in categoryIcons.entries)
          Semantics(
            selected: key == selected,
            button: true,
            label: key,
            excludeSemantics: true,
            child: Material(
              color: key == selected ? accent : PalierColors.surface,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => onSelect(key),
                child: SizedBox.square(
                  dimension: kPalierMinTarget,
                  child: Icon(value, size: 22, color: key == selected ? PalierAccent.onAccent : PalierColors.textMid),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

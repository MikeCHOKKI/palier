import 'expense_kinds.dart';
import 'expenses.dart';

/// Ce que reçoit un profil la première fois qu'il ouvre ses dépenses : un
/// compte « Espèces » pour pouvoir saisir tout de suite, et des catégories
/// courantes d'un foyer, que chacun renomme ou supprime ensuite.
abstract final class StarterKit {
  static const account = AccountDraft(name: 'Espèces');

  /// Où vont les frais d'un virement. Un profil qui ne l'a pas (créé avant, ou
  /// qui l'a supprimée) la retrouve au premier virement avec frais.
  static const feesCategory = CategoryDraft(name: 'Frais et taxes', kind: CategoryKind.expense, icon: 'fees');

  static const categories = <CategoryDraft>[
    CategoryDraft(name: 'Alimentation', kind: CategoryKind.expense, icon: 'basket'),
    CategoryDraft(name: 'Transport', kind: CategoryKind.expense, icon: 'moto'),
    CategoryDraft(name: 'Crédit et data', kind: CategoryKind.expense, icon: 'phone'),
    CategoryDraft(name: 'Électricité', kind: CategoryKind.expense, icon: 'bolt'),
    CategoryDraft(name: 'Eau', kind: CategoryKind.expense, icon: 'water'),
    CategoryDraft(name: 'Loyer', kind: CategoryKind.expense, icon: 'home'),
    CategoryDraft(name: 'Santé', kind: CategoryKind.expense, icon: 'health'),
    CategoryDraft(name: 'Scolarité', kind: CategoryKind.expense, icon: 'school'),
    CategoryDraft(name: 'Famille et dons', kind: CategoryKind.expense, icon: 'family'),
    CategoryDraft(name: 'Loisirs', kind: CategoryKind.expense, icon: 'party'),
    feesCategory,
    CategoryDraft(name: 'Divers', kind: CategoryKind.expense, icon: 'more'),
    CategoryDraft(name: 'Salaire', kind: CategoryKind.income, icon: 'salary'),
    CategoryDraft(name: 'Ventes', kind: CategoryKind.income, icon: 'shop'),
    CategoryDraft(name: 'Cadeaux reçus', kind: CategoryKind.income, icon: 'gift'),
    CategoryDraft(name: 'Autres revenus', kind: CategoryKind.income, icon: 'plus'),
  ];
}

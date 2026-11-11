import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../domain/expense_kinds.dart';

/// Icônes proposées pour les catégories, par clé enregistrée en base. Une seule
/// famille (Material, contour ou arrondi) pour toute l'application.
const Map<String, IconData> categoryIcons = {
  'basket': Icons.shopping_basket_outlined,
  'restaurant': Icons.restaurant_outlined,
  'moto': Icons.two_wheeler_rounded,
  'bus': Icons.directions_bus_outlined,
  'car': Icons.directions_car_outlined,
  'fuel': Icons.local_gas_station_outlined,
  'phone': Icons.phone_android_rounded,
  'internet': Icons.wifi_rounded,
  'bolt': Icons.bolt_rounded,
  'water': Icons.water_drop_outlined,
  'home': Icons.home_outlined,
  'tools': Icons.build_outlined,
  'health': Icons.healing_outlined,
  'school': Icons.school_outlined,
  'book': Icons.menu_book_outlined,
  'baby': Icons.child_care_outlined,
  'family': Icons.volunteer_activism_outlined,
  'church': Icons.church_outlined,
  'party': Icons.celebration_outlined,
  'sport': Icons.fitness_center_outlined,
  'clothes': Icons.checkroom_outlined,
  'beauty': Icons.content_cut_rounded,
  'travel': Icons.luggage_outlined,
  'savings': Icons.savings_outlined,
  'salary': Icons.work_outline_rounded,
  'shop': Icons.storefront_outlined,
  'gift': Icons.redeem_rounded,
  'plus': Icons.add_card_outlined,
  'more': Icons.more_horiz_rounded,
};

IconData categoryIcon(String? key) => categoryIcons[key] ?? Icons.label_outline_rounded;

IconData accountIcon(AccountKind kind) => switch (kind) {
  AccountKind.cash => Icons.payments_outlined,
  AccountKind.mobileMoney => Icons.send_to_mobile_outlined,
  AccountKind.bank => Icons.account_balance_outlined,
  AccountKind.savings => Icons.savings_outlined,
  AccountKind.tontine => Icons.diversity_3_outlined,
  AccountKind.loan => Icons.handshake_outlined,
};

const IconData transferIcon = Icons.swap_horiz_rounded;

extension ExpenseLabels on AppLocalizations {
  String accountKindName(AccountKind kind) => accountKind(kind.name);
  String operationKindName(OperationKind kind) => operationKind(kind.name);
}

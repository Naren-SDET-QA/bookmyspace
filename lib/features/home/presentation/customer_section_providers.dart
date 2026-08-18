import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/customer_section_catalog.dart';

/// Currently selected customer section. Null = first screen (4 cards only).
final selectedCustomerSectionProvider = StateProvider<CustomerSection?>(
  (ref) => null,
);

/// Selected subcategory inside the active section (`all` or a catalog id).
final selectedCustomerCategoryProvider = StateProvider<String>((ref) => 'all');

void selectCustomerSection(WidgetRef ref, CustomerSection section) {
  ref.read(selectedCustomerSectionProvider.notifier).state = section;
  ref.read(selectedCustomerCategoryProvider.notifier).state = 'all';
}

void clearCustomerSection(WidgetRef ref) {
  ref.read(selectedCustomerSectionProvider.notifier).state = null;
  ref.read(selectedCustomerCategoryProvider.notifier).state = 'all';
}

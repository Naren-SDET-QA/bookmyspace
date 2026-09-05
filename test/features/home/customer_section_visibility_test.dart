import 'package:bookmyspace/features/home/domain/customer_section_catalog.dart';
import 'package:bookmyspace/features/home/domain/home_category_catalog.dart';
import 'package:bookmyspace/features/venues/domain/category_configuration.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('admin visibility hides configured first-screen sections', () {
    final visible = HomeCategoryCatalog.effectiveMainSections(
      configured: const [
        AppSectionConfig(id: 'function_halls', title: 'Halls'),
        AppSectionConfig(id: 'lodge_rooms', title: 'Stays', visible: false),
      ],
      featureVisibleIds: CustomerSection.values.map((s) => s.id).toSet(),
      customerEnabledIds: CustomerSection.values.map((s) => s.id).toSet(),
    );

    expect(visible, [CustomerSection.functionHalls]);
  });

  test('empty configuration preserves the four-section fallback', () {
    final visible = HomeCategoryCatalog.effectiveMainSections(
      configured: const [],
      featureVisibleIds: CustomerSection.values.map((s) => s.id).toSet(),
      customerEnabledIds: CustomerSection.values.map((s) => s.id).toSet(),
    );

    expect(visible, CustomerSection.values);
  });
}

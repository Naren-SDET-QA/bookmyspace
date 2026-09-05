import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/settings_controller.dart';
import '../domain/customer_category_preferences.dart';

const _preferenceKey = 'bms_customer_category_preferences';

final customerCategoryPreferencesProvider =
    NotifierProvider<
      CustomerCategoryPreferencesNotifier,
      CustomerCategoryPreferences
    >(CustomerCategoryPreferencesNotifier.new);

class CustomerCategoryPreferencesNotifier
    extends Notifier<CustomerCategoryPreferences> {
  @override
  CustomerCategoryPreferences build() {
    _load();
    return CustomerCategoryPreferences.defaults(_defaultIds);
  }

  Future<void> _load() async {
    final raw = await ref.read(preferencesProvider).read(_preferenceKey);
    if (raw == null || raw.isEmpty) return;
    final values = CustomerCategoryPreferences.decode(raw);
    state = CustomerCategoryPreferences.fromEnabled(_defaultIds, values);
  }

  Future<void> save(Map<String, bool> values) async {
    final ids = values.keys.isEmpty ? _defaultIds : values.keys;
    final next = CustomerCategoryPreferences.fromEnabled(ids, values);
    state = next;
    await ref.read(preferencesProvider).write(_preferenceKey, next.encode());
  }

  Future<void> selectAll() => save({for (final id in _defaultIds) id: true});

  Future<void> clearAll() => save({for (final id in _defaultIds) id: false});

  static const _defaultIds = [
    'function_halls',
    'lodge_rooms',
    'pg_hostels',
    'institutes_classes',
  ];
}

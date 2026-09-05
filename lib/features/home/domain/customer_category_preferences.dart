class CustomerCategoryPreferences {
  const CustomerCategoryPreferences._(this._enabled);

  factory CustomerCategoryPreferences.defaults(Iterable<String> ids) {
    return CustomerCategoryPreferences._({
      for (final id in ids.where((id) => id.trim().isNotEmpty)) id: true,
    });
  }

  factory CustomerCategoryPreferences.fromEnabled(
    Iterable<String> ids,
    Map<String, bool> values,
  ) {
    final normalized = ids.where((id) => id.trim().isNotEmpty).toList();
    final enabled = <String, bool>{
      for (final id in normalized) id: values[id] ?? true,
    };
    if (enabled.values.every((value) => !value) && normalized.isNotEmpty) {
      enabled[normalized.first] = true;
    }
    return CustomerCategoryPreferences._(enabled);
  }

  final Map<String, bool> _enabled;

  List<String> get visibleIds => [
    for (final entry in _enabled.entries)
      if (entry.value) entry.key,
  ];

  bool isEnabled(String id) => _enabled[id] ?? false;

  Map<String, bool> get values => Map.unmodifiable(_enabled);

  String encode() => _enabled.entries
      .map((entry) => '${entry.key}=${entry.value}')
      .join('|');

  static Map<String, bool> decode(String? raw) {
    if (raw == null || raw.isEmpty) return const {};
    return {
      for (final part in raw.split('|'))
        if (part.contains('='))
          part.substring(0, part.indexOf('=')): part.substring(part.indexOf('=') + 1) == 'true',
    };
  }
}

import 'dart:convert';

import '../../../core/offline/offline_store.dart';

class RecentSearch {
  const RecentSearch({required this.query, required this.searchedAt});

  final String query;
  final DateTime searchedAt;

  Map<String, dynamic> toJson() => {
    'query': query,
    'searchedAt': searchedAt.toIso8601String(),
  };

  factory RecentSearch.fromJson(Map<String, dynamic> json) => RecentSearch(
    query: (json['query'] as String? ?? '').trim(),
    searchedAt:
        DateTime.tryParse(json['searchedAt'] as String? ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0),
  );
}

/// Persistent recent-search list (legacy Room RecentSearchDao equivalent).
class RecentSearchStore {
  RecentSearchStore(this._store, {this.maxItems = maxHistory});

  static const storageKey = 'bms_recent_searches';

  /// Legacy Room DAO `LIMIT 10`, newest first.
  static const int maxHistory = 10;

  final OfflineStore _store;
  final int maxItems;

  Future<List<RecentSearch>> load() async {
    final raw = await _store.read(storageKey);
    if (raw == null || raw.isEmpty) return const [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    final items = [
      for (final row in decoded)
        if (row is Map<String, dynamic>)
          RecentSearch.fromJson(row)
        else if (row is Map)
          RecentSearch.fromJson(Map<String, dynamic>.from(row)),
    ].where((item) => item.query.isNotEmpty).toList();
    items.sort((a, b) => b.searchedAt.compareTo(a.searchedAt));
    return items.take(maxItems).toList(growable: false);
  }

  Future<List<RecentSearch>> add(String query, {DateTime? now}) async {
    final trimmed = query.trim();
    if (trimmed.length < 2) return load();
    final stamp = now ?? DateTime.now();
    final existing = [
      ...await load(),
    ]..removeWhere((item) => item.query.toLowerCase() == trimmed.toLowerCase());
    final next = [
      RecentSearch(query: trimmed, searchedAt: stamp),
      ...existing,
    ].take(maxItems).toList(growable: false);
    await _persist(next);
    return next;
  }

  Future<List<RecentSearch>> remove(String query) async {
    final next = [
      for (final item in await load())
        if (item.query.toLowerCase() != query.trim().toLowerCase()) item,
    ];
    await _persist(next);
    return next;
  }

  Future<List<RecentSearch>> clear() async {
    await _store.delete(storageKey);
    return const [];
  }

  Future<void> _persist(List<RecentSearch> items) async {
    await _store.write(
      storageKey,
      jsonEncode(items.map((item) => item.toJson()).toList(growable: false)),
    );
  }
}

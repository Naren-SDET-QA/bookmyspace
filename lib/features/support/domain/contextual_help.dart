import '../../../core/offline/offline_store.dart';

/// Per-screen help that is stored locally and is not the AI chat or admin
/// knowledge-base articles.
class ContextualHelpTopic {
  const ContextualHelpTopic({
    required this.id,
    required this.routePrefix,
    required this.title,
    required this.body,
  });

  final String id;
  final String routePrefix;
  final String title;
  final String body;
}

class ContextualHelpCatalog {
  static const topics = <ContextualHelpTopic>[
    ContextualHelpTopic(
      id: 'home',
      routePrefix: '/home',
      title: 'Finding a space',
      body:
          'Pick a category, then search or open the map. Availability and price are confirmed only in the booking flow.',
    ),
    ContextualHelpTopic(
      id: 'search',
      routePrefix: '/search',
      title: 'Search tips',
      body:
          'Filter by section, location and price. Recent searches are saved on this device and can be cleared any time.',
    ),
    ContextualHelpTopic(
      id: 'map',
      routePrefix: '/map',
      title: 'Map',
      body:
          'The map shows the same results as search. Tap a pin for details. Tiles cache on this device when the OS allows it.',
    ),
    ContextualHelpTopic(
      id: 'booking',
      routePrefix: '/venues',
      title: 'Booking a slot',
      body:
          'Choose a date and an open slot. The server holds the slot; pay before the countdown ends. Expired holds are released by the server, not the app clock.',
    ),
    ContextualHelpTopic(
      id: 'pay',
      routePrefix: '/bookings',
      title: 'Payment hold',
      body:
          'A visible countdown uses the server hold-expiry time. If it runs out, pick the slot again. Email receipts still come from the server outbox.',
    ),
    ContextualHelpTopic(
      id: 'owner',
      routePrefix: '/owner',
      title: 'Owner tools',
      body:
          'Listings, calendar, offline walk-in bookings and the Venue Optimizer all use live owner bookings — they never invent occupancy.',
    ),
    ContextualHelpTopic(
      id: 'support',
      routePrefix: '/support',
      title: 'Support',
      body:
          'Open a ticket for account or payment issues. This help panel stays on-device; the knowledge base and assistant are separate.',
    ),
  ];

  static ContextualHelpTopic? forRoute(String route) {
    if (route.contains('/pay')) {
      return topics.firstWhere((topic) => topic.id == 'pay');
    }
    if (route.contains('/book')) {
      return topics.firstWhere((topic) => topic.id == 'booking');
    }
    ContextualHelpTopic? match;
    for (final topic in topics) {
      if (route == topic.routePrefix || route.startsWith('${topic.routePrefix}/')) {
        if (match == null ||
            topic.routePrefix.length >= match.routePrefix.length) {
          match = topic;
        }
      }
    }
    return match;
  }
}

class ContextualHelpStore {
  ContextualHelpStore(this._store);

  static const storageKey = 'bms_contextual_help_dismissed';

  final OfflineStore _store;

  Future<Set<String>> dismissedIds() async {
    final raw = await _store.read(storageKey);
    if (raw == null || raw.isEmpty) return {};
    return raw
        .split(',')
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet();
  }

  Future<bool> isDismissed(String id) async => (await dismissedIds()).contains(id);

  Future<void> dismiss(String id) async {
    final next = {...await dismissedIds(), id};
    await _store.write(storageKey, next.join(','));
  }

  Future<void> restore(String id) async {
    final next = {...await dismissedIds()}..remove(id);
    await _store.write(storageKey, next.join(','));
  }
}

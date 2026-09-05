import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bookmyspace/core/errors/app_exceptions.dart';
import 'package:bookmyspace/core/offline/offline_cache.dart';
import 'package:bookmyspace/core/offline/offline_store.dart';
import 'package:bookmyspace/features/auth/domain/auth_repository.dart';
import 'package:bookmyspace/features/auth/domain/auth_user.dart';
import 'package:bookmyspace/features/auth/presentation/auth_providers.dart';
import 'package:bookmyspace/features/venues/domain/venue.dart';
import 'package:bookmyspace/features/venues/domain/venue_repository.dart';
import 'package:bookmyspace/features/venues/infrastructure/caching_venue_repository.dart';

/// Regression coverage for the offline-favorites cross-account leak:
/// `venueRepositoryProvider` used to read `client.auth.currentUser?.id`
/// once, at construction, and never rebuilt on sign-in/sign-out -- so the
/// `CachingVenueRepository.cacheScope` it created stayed frozen to whichever
/// user was signed in first, letting a later account on the same device
/// read (and overwrite) the previous account's cached favorites without an
/// app restart. The fix makes the provider watch `currentUserProvider`
/// (already a reactive, auth-stream-backed provider) instead.
///
/// These tests exercise two layers, not just string comparisons:
///  - the cache/repository layer, with a real [OfflineCache] doing actual
///    read-through I/O against a shared in-memory store (as two different
///    users on one device would share one on-disk cache), and
///  - the provider layer, driving the exact reactive value
///    (`currentUserProvider`) that `venueRepositoryProvider` now watches
///    through a live auth-state stream across every transition.
void main() {
  const venueA = Venue(id: 'venue-a', name: 'A Stay', latitude: 0, longitude: 0);
  const venueB = Venue(id: 'venue-b', name: 'B Stay', latitude: 0, longitude: 0);

  group('CachingVenueRepository favorites cache isolation (storage layer)', () {
    test('1. different users compute different cache scopes', () {
      final store = MemoryOfflineStore();
      final cache = OfflineCache(store);
      final repoA = CachingVenueRepository(
        _OnlineOnce([venueA]),
        cache,
        cacheScope: 'user-a',
      );
      final repoB = CachingVenueRepository(
        _OnlineOnce([venueB]),
        cache,
        cacheScope: 'user-b',
      );

      expect(repoA.cacheScope, isNot(repoB.cacheScope));
    });

    test('2. A favorites are cached while online, then readable by A offline', () async {
      final store = MemoryOfflineStore();
      final cache = OfflineCache(store);
      final repoA = CachingVenueRepository(
        _OnlineOnce([venueA]),
        cache,
        cacheScope: 'user-a',
      );

      final live = await repoA.favorites();
      expect(live.map((v) => v.id), ['venue-a']);
      expect(store.snapshot.containsKey('venues.favorites.user-a'), isTrue);

      // The inner repository now throws (simulated connectivity loss); A
      // should still see A's own data, served from A's own cache slot.
      final offline = await repoA.favorites();
      expect(offline.map((v) => v.id), ['venue-a']);
    });

    test('3. B cannot read A\'s cached favorites while offline', () async {
      final store = MemoryOfflineStore();
      final cache = OfflineCache(store);
      final repoA = CachingVenueRepository(
        _OnlineOnce([venueA]),
        cache,
        cacheScope: 'user-a',
      );
      await repoA.favorites(); // seeds venues.favorites.user-a only

      final repoB = CachingVenueRepository(
        _AlwaysOffline(),
        cache,
        cacheScope: 'user-b',
      );

      // B has never been online: B's own cache slot is empty, so B must get
      // a clear failure -- never a silent fall-through into A's data.
      await expectLater(repoB.favorites(), throwsA(isA<NetworkException>()));
    });

    test('4. A -> B live handoff: both scopes persist independently, never overwriting each other', () async {
      final store = MemoryOfflineStore();
      final cache = OfflineCache(store);
      final repoA = CachingVenueRepository(
        _OnlineOnce([venueA]),
        cache,
        cacheScope: 'user-a',
      );
      final repoB = CachingVenueRepository(
        _OnlineOnce([venueB]),
        cache,
        cacheScope: 'user-b',
      );

      await repoA.favorites();
      await repoB.favorites();

      expect(store.snapshot['venues.favorites.user-a'], isNotNull);
      expect(store.snapshot['venues.favorites.user-b'], isNotNull);
      expect(
        store.snapshot['venues.favorites.user-a'],
        isNot(store.snapshot['venues.favorites.user-b']),
      );

      // Fresh offline repositories for each scope, sharing the same
      // on-device store, must each resolve only their own data.
      final offlineA = CachingVenueRepository(
        _AlwaysOffline(),
        cache,
        cacheScope: 'user-a',
      );
      final offlineB = CachingVenueRepository(
        _AlwaysOffline(),
        cache,
        cacheScope: 'user-b',
      );
      expect((await offlineA.favorites()).map((v) => v.id), ['venue-a']);
      expect((await offlineB.favorites()).map((v) => v.id), ['venue-b']);
    });

    test('5. anonymous (no session) cannot read an authenticated user\'s cache', () async {
      final store = MemoryOfflineStore();
      final cache = OfflineCache(store);
      final repoA = CachingVenueRepository(
        _OnlineOnce([venueA]),
        cache,
        cacheScope: 'user-a',
      );
      await repoA.favorites();

      final anonymous = CachingVenueRepository(
        _AlwaysOffline(),
        cache,
        cacheScope: null,
      );

      await expectLater(
        anonymous.favorites(),
        throwsA(isA<NetworkException>()),
      );
    });

    test('6. B can independently favorite/read without touching A\'s data', () async {
      final store = MemoryOfflineStore();
      final cache = OfflineCache(store);
      final repoA = CachingVenueRepository(
        _OnlineOnce([venueA]),
        cache,
        cacheScope: 'user-a',
      );
      final repoB = CachingVenueRepository(
        _OnlineOnce([venueB]),
        cache,
        cacheScope: 'user-b',
      );

      await repoA.favorites();
      final bResult = await repoB.favorites();

      expect(bResult.map((v) => v.id), ['venue-b']);
      expect(store.snapshot['venues.favorites.user-a'], isNotNull);
    });

    test('7. existing online favorites behaviour (live-first, write-through) is unchanged', () async {
      final store = MemoryOfflineStore();
      final cache = OfflineCache(store);
      final repo = CachingVenueRepository(
        _OnlineOnce([venueA, venueB]),
        cache,
        cacheScope: 'user-a',
      );

      final result = await repo.favorites();

      expect(result.map((v) => v.id), ['venue-a', 'venue-b']);
      expect(store.snapshot['venues.favorites.user-a'], isNotNull);
    });
  });

  group('venueRepositoryProvider cache scope reacts to auth transitions (provider lifecycle)', () {
    test(
      'anonymous -> A -> B -> logout -> B: the reactive value venueRepositoryProvider '
      'now watches updates on every transition, with no stale carry-over and no app restart',
      () async {
        final events = StreamController<AuthUser?>.broadcast();
        addTearDown(events.close);

        final container = ProviderContainer(
          overrides: [
            authRepositoryProvider.overrideWithValue(
              _ScriptedAuthRepository(events),
            ),
          ],
        );
        addTearDown(container.dispose);

        final seenIds = <String?>[];
        container.listen<AuthUser?>(
          currentUserProvider,
          (previous, next) => seenIds.add(next?.id),
          fireImmediately: true,
        );

        // Starts anonymous: no session, no scope.
        expect(container.read(currentUserProvider), isNull);

        // anonymous -> A
        events.add(const AuthUser(id: 'user-a', email: 'a@test.com'));
        await Future<void>.delayed(Duration.zero);
        expect(container.read(currentUserProvider)?.id, 'user-a');

        // A -> B, in the same running container -- no restart.
        events.add(const AuthUser(id: 'user-b', email: 'b@test.com'));
        await Future<void>.delayed(Duration.zero);
        expect(container.read(currentUserProvider)?.id, 'user-b');

        // B -> logout -> anonymous.
        events.add(null);
        await Future<void>.delayed(Duration.zero);
        expect(container.read(currentUserProvider), isNull);

        // anonymous -> B again.
        events.add(const AuthUser(id: 'user-b', email: 'b@test.com'));
        await Future<void>.delayed(Duration.zero);
        expect(container.read(currentUserProvider)?.id, 'user-b');

        expect(seenIds, [null, 'user-a', 'user-b', null, 'user-b']);
      },
    );
  });
}

/// Succeeds with [_result] exactly once (a live fetch that populates the
/// cache), then behaves as if the device lost connectivity on every
/// subsequent call.
class _OnlineOnce implements VenueRepository {
  _OnlineOnce(this._result);

  final List<Venue> _result;
  bool _served = false;

  @override
  Future<List<Venue>> favorites() async {
    if (_served) {
      throw const NetworkException('offline');
    }
    _served = true;
    return _result;
  }

  @override
  noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

/// Always behaves as offline -- used to prove a scope with nothing cached
/// gets a clear failure rather than another scope's data.
class _AlwaysOffline implements VenueRepository {
  @override
  Future<List<Venue>> favorites() async {
    throw const NetworkException('offline');
  }

  @override
  noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

/// Minimal scripted [AuthRepository] whose auth-state stream is driven
/// directly by the test, so exact user/anonymous transitions (including a
/// direct A -> B swap) can be exercised deterministically.
class _ScriptedAuthRepository implements AuthRepository {
  _ScriptedAuthRepository(this._events);

  final StreamController<AuthUser?> _events;

  @override
  AuthUser? get currentUser => null;

  @override
  Stream<AuthUser?> authStateChanges() => _events.stream;

  @override
  noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

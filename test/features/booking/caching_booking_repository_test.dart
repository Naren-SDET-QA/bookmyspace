import 'package:flutter_test/flutter_test.dart';

import 'package:bookmyspace/core/offline/offline_cache.dart';
import 'package:bookmyspace/core/offline/offline_store.dart';
import 'package:bookmyspace/features/booking/infrastructure/caching_booking_repository.dart';
import 'package:bookmyspace/features/booking/domain/booking_repository.dart';

void main() {
  test('scopes cached booking keys per authenticated user', () {
    final cache = OfflineCache(MemoryOfflineStore());
    final first = CachingBookingRepository(
      _UnimplementedRepository(),
      cache,
      cacheScope: 'user-a',
    );
    final second = CachingBookingRepository(
      _UnimplementedRepository(),
      cache,
      cacheScope: 'user-b',
    );

    expect(first.cacheScope, isNot(second.cacheScope));
  });
}

class _UnimplementedRepository implements BookingRepository {
  @override
  noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

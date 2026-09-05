import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bookmyspace/features/venues/domain/category_configuration.dart';
import 'package:bookmyspace/features/venues/presentation/category_configuration_providers.dart';
import 'package:bookmyspace/features/venues/presentation/venue_providers.dart';

import '../venues/mock_venue_repository.dart';

void main() {
  test(
    'All resolves only configured categories in the selected module',
    () async {
      final repository = MockVenueRepository();
      final container = ProviderContainer(
        overrides: [
          venueRepositoryProvider.overrideWithValue(repository),
          categoryConfigurationsProvider.overrideWith(
            (ref) async => const [
              CategoryConfiguration(
                id: 'hotel-id',
                slug: 'hotel_stay',
                name: 'Hotel',
                sectionId: 'lodge_rooms',
              ),
              CategoryConfiguration(
                id: 'lodge-id',
                slug: 'lodge',
                name: 'Lodge',
                sectionId: 'lodge_rooms',
              ),
            ],
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(moduleVenuesProvider('lodge_rooms').future);

      expect(
        repository.searchQueries.map((query) => query.categorySlug),
        containsAll(<String>['hotel_stay', 'lodge']),
      );
      expect(repository.searchQueries, isNotEmpty);
    },
  );
}

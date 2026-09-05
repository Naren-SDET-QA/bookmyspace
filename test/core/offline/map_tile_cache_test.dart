import 'package:bookmyspace/core/offline/map_tile_cache.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('map tiles use flutter_map network provider with built-in cache', () {
    final provider = createCachingTileProvider();
    expect(provider, isA<NetworkTileProvider>());
  });
}

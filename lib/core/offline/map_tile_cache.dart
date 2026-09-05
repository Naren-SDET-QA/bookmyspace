import 'package:flutter_map/flutter_map.dart';

/// OSM tile provider. flutter_map's [NetworkTileProvider] already uses
/// [BuiltInMapCachingProvider] lazily (native disk cache; web no-op).
TileProvider createCachingTileProvider() => NetworkTileProvider();

import 'package:flutter_map/flutter_map.dart';

import '../app_plugin.dart';
import '../plugin_kind.dart';
import '../provider_registry.dart';

/// Host for the existing flutter_map SDK. Not a second map implementation.
abstract interface class MapProvider implements AppPlugin {
  String get tileUrlTemplate;
  String get userAgentPackageName;

  /// Constructs a [MapController]. Call only when a map surface is shown.
  MapController createController();
}

MapProvider? resolvedMapProvider(ProviderRegistry registry) {
  final plugin = registry.tryResolve(PluginKind.map);
  return plugin is MapProvider ? plugin : null;
}

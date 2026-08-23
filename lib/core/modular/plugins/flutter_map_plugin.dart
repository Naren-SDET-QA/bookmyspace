import 'package:flutter_map/flutter_map.dart';

import 'map_provider.dart';

/// Existing OpenStreetMap + flutter_map host used by map surfaces.
/// [MapController] is created only via [createController], not at plugin
/// construction.
class FlutterMapPlugin implements MapProvider {
  FlutterMapPlugin({MapController Function()? controllerFactory})
    : _controllerFactory = controllerFactory ?? MapController.new;

  static const defaultTileUrl =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const defaultUserAgent = 'com.bookmyspace.app';

  final MapController Function() _controllerFactory;
  bool _ready = false;

  @override
  String get tileUrlTemplate => defaultTileUrl;

  @override
  String get userAgentPackageName => defaultUserAgent;

  @override
  String get id => 'flutter_map';

  @override
  bool get initialized => _ready;

  @override
  MapController createController() {
    _ready = true;
    return _controllerFactory();
  }

  @override
  Future<void> ensureInitialized() async {
    _ready = true;
  }

  @override
  Future<void> dispose() async {
    _ready = false;
  }
}

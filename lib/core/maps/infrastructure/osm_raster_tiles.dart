import '../../config/app_config.dart';
import '../domain/map_providers.dart';

/// OpenStreetMap raster tiles (configurable URL template).
class OsmRasterTiles implements MapTileProvider {
  const OsmRasterTiles({
    String? urlTemplate,
    String? userAgentPackageName,
    this.attribution = '© OpenStreetMap contributors',
  })  : _urlTemplate = urlTemplate,
        _userAgentPackageName = userAgentPackageName;

  final String? _urlTemplate;
  final String? _userAgentPackageName;
  @override
  final String attribution;

  @override
  String get urlTemplate => _urlTemplate ?? AppConfig.osmTileUrlTemplate;

  @override
  String get userAgentPackageName =>
      _userAgentPackageName ?? AppConfig.mapsPackageName;
}

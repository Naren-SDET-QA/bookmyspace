import '../../location/device_location_service.dart';
import '../domain/geo_point.dart';
import '../domain/map_providers.dart';

/// GPS via [DeviceLocationService] / Geolocator.
class GeolocatorGps implements LocationProvider {
  GeolocatorGps({DeviceLocationService? deviceLocation})
      : _device = deviceLocation ?? const GeolocatorDeviceLocationService();

  final DeviceLocationService _device;

  @override
  Future<GeoPoint?> currentPosition() async {
    final result = await _device.currentPosition();
    return switch (result) {
      DeviceLocationSuccess(:final latitude, :final longitude) =>
        GeoPoint(latitude, longitude),
      _ => null,
    };
  }
}

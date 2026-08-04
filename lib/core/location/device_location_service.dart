import 'package:geolocator/geolocator.dart';

/// Result of a device location lookup.
sealed class DeviceLocationResult {
  const DeviceLocationResult();
}

class DeviceLocationSuccess extends DeviceLocationResult {
  const DeviceLocationSuccess({
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
  });

  final double latitude;
  final double longitude;
  final double accuracyMeters;
}

class DeviceLocationPermissionDenied extends DeviceLocationResult {
  const DeviceLocationPermissionDenied();
}

class DeviceLocationServiceDisabled extends DeviceLocationResult {
  const DeviceLocationServiceDisabled();
}

class DeviceLocationUnavailable extends DeviceLocationResult {
  const DeviceLocationUnavailable(this.message);

  final String message;
}

/// Reads the device's current GPS position via [Geolocator].
abstract class DeviceLocationService {
  Future<DeviceLocationResult> currentPosition();
}

class GeolocatorDeviceLocationService implements DeviceLocationService {
  const GeolocatorDeviceLocationService();

  @override
  Future<DeviceLocationResult> currentPosition() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return const DeviceLocationServiceDisabled();
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        return const DeviceLocationPermissionDenied();
      }
      if (permission == LocationPermission.deniedForever) {
        return const DeviceLocationPermissionDenied();
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 12),
        ),
      );

      return DeviceLocationSuccess(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracyMeters: position.accuracy,
      );
    } on LocationServiceDisabledException {
      return const DeviceLocationServiceDisabled();
    } on PermissionDeniedException {
      return const DeviceLocationPermissionDenied();
    } catch (e) {
      return DeviceLocationUnavailable(e.toString());
    }
  }
}

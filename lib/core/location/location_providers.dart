import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'device_location_service.dart';

final deviceLocationServiceProvider = Provider<DeviceLocationService>(
  (ref) => const GeolocatorDeviceLocationService(),
);

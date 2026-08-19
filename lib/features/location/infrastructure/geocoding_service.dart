import 'package:dio/dio.dart';

import 'package:geolocator/geolocator.dart';

import '../domain/search_area.dart';

/// Address lookup built on the OpenStreetMap Nominatim API.
///
/// Free, keyless and consistent across Android/iOS/Web — the same tile
/// stack already used by the in-app maps. Requests send a descriptive
/// User-Agent as required by the Nominatim usage policy.
class GeocodingService {
  GeocodingService({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: 'https://nominatim.openstreetmap.org',
              connectTimeout: const Duration(seconds: 12),
              receiveTimeout: const Duration(seconds: 12),
              headers: const {
                'Accept': 'application/json',
                'User-Agent': 'bookmyspace-flutter/1.0 (customer search)',
              },
            ),
          );

  final Dio _dio;

  /// Forward geocoding: free-text place name to a [SearchArea].
  /// Returns `null` when nothing matches.
  Future<SearchArea?> geocode(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return null;
    final response = await _dio.get<List<dynamic>>(
      '/search',
      queryParameters: {
        'q': trimmed,
        'format': 'json',
        'limit': 1,
        'countrycodes': 'in',
      },
    );
    final rows = response.data ?? const [];
    if (rows.isEmpty) return null;
    final row = rows.first as Map<String, dynamic>;
    final lat = double.tryParse(row['lat'] as String? ?? '');
    final lng = double.tryParse(row['lon'] as String? ?? '');
    if (lat == null || lng == null) return null;
    return SearchArea(
      label: row['display_name'] as String? ?? trimmed,
      latitude: lat,
      longitude: lng,
    );
  }

  /// Reverse geocoding: coordinates to a human-readable label.
  /// Falls back to a plain coordinate label when the lookup fails.
  Future<String> reverse(double latitude, double longitude) async {
    try {
      final response = await _dio.get<List<dynamic>>(
        '/reverse',
        queryParameters: {
          'lat': latitude.toStringAsFixed(6),
          'lon': longitude.toStringAsFixed(6),
          'format': 'jsonv2',
          'zoom': 14,
        },
      );
      final rows = response.data ?? const [];
      if (rows.isEmpty) {
        return '${latitude.toStringAsFixed(4)}, '
            '${longitude.toStringAsFixed(4)}';
      }
      final row = rows.first as Map<String, dynamic>;
      final name = row['name'] as String? ?? '';
      final address = row['address'] is Map<String, dynamic>
          ? row['address'] as Map<String, dynamic>
          : const <String, dynamic>{};
      final parts = <String>[
        name,
        address['city_district'] as String? ?? '',
        address['city'] as String? ?? '',
        address['town'] as String? ?? '',
      ].where((p) => p.trim().isNotEmpty).toSet().toList();
      if (parts.isEmpty) {
        return '${latitude.toStringAsFixed(4)}, '
            '${longitude.toStringAsFixed(4)}';
      }
      return parts.take(2).join(', ');
    } catch (_) {
      return '${latitude.toStringAsFixed(4)}, '
          '${longitude.toStringAsFixed(4)}';
    }
  }

  /// The device's current position as a [SearchArea], requesting
  /// permission when needed. Throws [LocationServiceDisabledException] or
  /// [LocationPermissionDeniedException] so callers can degrade gracefully.
  Future<SearchArea> deviceLocation() async {
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      await Geolocator.requestPermission();
    }
    final granted = await Geolocator.checkPermission();
    if (granted == LocationPermission.denied ||
        granted == LocationPermission.deniedForever) {
      throw const LocationPermissionDeniedException(
        'Location permission denied.',
        'permission_denied',
      );
    }
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
        timeLimit: Duration(seconds: 15),
      ),
    );
    final label = await reverse(position.latitude, position.longitude);
    return SearchArea(
      label: label,
      latitude: position.latitude,
      longitude: position.longitude,
      radiusKm: SearchArea.defaultArea.radiusKm,
    );
  }
}

class LocationPermissionDeniedException implements Exception {
  const LocationPermissionDeniedException(this.message, this.code);
  final String message;
  final String code;

  @override
  String toString() => message;
}

class LocationServiceDisabledException implements Exception {
  const LocationServiceDisabledException(this.message);
  final String message;

  @override
  String toString() => message;
}
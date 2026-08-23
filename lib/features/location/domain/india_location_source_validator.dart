import 'india_pin.dart';

/// Rejects incomplete or invented India location source rows.
class IndiaLocationSourceValidator {
  const IndiaLocationSourceValidator._();

  static bool lgdRecord(Map<String, String> row) {
    if (!_present(row, 'state_code') || !_present(row, 'state_name')) {
      return false;
    }
    if (!_present(row, 'district_code') || !_present(row, 'district_name')) {
      return false;
    }
    return true;
  }

  static bool pinRecord(Map<String, String> row) {
    final pin = IndiaPin.normalize(row['pincode'] ?? '');
    return pin != null &&
        _present(row, 'officename') &&
        _present(row, 'districtname') &&
        _present(row, 'statename');
  }

  static bool _present(Map<String, String> row, String key) {
    return (row[key] ?? '').trim().isNotEmpty;
  }
}

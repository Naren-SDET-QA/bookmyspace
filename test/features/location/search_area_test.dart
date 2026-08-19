import 'package:bookmyspace/features/location/domain/search_area.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SearchArea coordinates', () {
    test('accepts finite coordinates within map bounds', () {
      expect(SearchArea.isValidCoordinate(17.385, 78.486), isTrue);
      expect(SearchArea.defaultArea.hasValidCoordinates, isTrue);
    });

    test('rejects invalid or non-finite coordinates', () {
      expect(SearchArea.isValidCoordinate(91, 78), isFalse);
      expect(SearchArea.isValidCoordinate(17, 181), isFalse);
      expect(SearchArea.isValidCoordinate(double.nan, 78), isFalse);
      expect(SearchArea.isValidCoordinate(17, double.infinity), isFalse);
    });

    test('copyWith keeps the last valid area when coordinates are invalid', () {
      final area = SearchArea.defaultArea;
      final unchanged = area.copyWith(latitude: 999);
      expect(unchanged.latitude, area.latitude);
      expect(unchanged.longitude, area.longitude);
      expect(unchanged.label, area.label);
    });
  });
}

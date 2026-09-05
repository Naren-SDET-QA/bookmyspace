import 'package:bookmyspace/core/modular/feature_config.dart';
import 'package:bookmyspace/core/theme/theme_tokens.dart';
import 'package:bookmyspace/features/ai/domain/booking_intent.dart';
import 'package:bookmyspace/features/analytics/domain/analytics_display_config.dart';
import 'package:bookmyspace/features/booking/domain/booking_side_effect.dart';
import 'package:bookmyspace/features/booking/domain/configurable_booking.dart';
import 'package:bookmyspace/features/booking/domain/invoice_repository.dart';
import 'package:bookmyspace/features/offers/domain/offer_configuration.dart';
import 'package:bookmyspace/features/venues/domain/category_configuration.dart';
import 'package:bookmyspace/features/venues/domain/category_discovery.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('category ordering is metadata-driven', () {
    const later = CategoryConfiguration(
      id: '2',
      slug: 'b',
      name: 'Second',
      sortOrder: 20,
    );
    const earlier = CategoryConfiguration(
      id: '1',
      slug: 'a',
      name: 'First',
      sortOrder: 5,
    );
    expect(
      CategoryDiscovery.carouselItems(const [
        later,
        earlier,
      ]).map((c) => c.slug),
      ['a', 'b'],
    );
  });

  test('search visibility hides non-searchable categories', () {
    const hidden = CategoryConfiguration(
      id: '1',
      slug: 'hidden',
      name: 'Hidden',
      searchable: false,
    );
    const shown = CategoryConfiguration(
      id: '2',
      slug: 'shown',
      name: 'Shown',
      searchable: true,
    );
    expect(
      CategoryDiscovery.searchable(const [hidden, shown]).map((c) => c.slug),
      ['shown'],
    );
  });

  test('disabled booking remains inaccessible', () {
    const listing = CategoryConfiguration(
      id: 'i',
      slug: 'campus',
      name: 'Campus',
      bookable: false,
    );
    expect(CategoryDiscovery.canBook(listing), isFalse);
    expect(ConfigurableBookingFields.from(listing), isEmpty);
  });

  test('offers respect enable, display visibility and category targeting', () {
    final offer = OfferConfiguration.fromJson({
      'id': 'o1',
      'code': 'HALL10',
      'discount_type': 'fixed',
      'discount_value': 500,
      'is_active': true,
      'metadata': {
        'visible': true,
        'category_ids': ['hall'],
      },
    });
    const visibleCat = CategoryConfiguration(
      id: 'hall',
      slug: 'hall',
      name: 'Hall',
      offerVisible: true,
    );
    const hiddenCat = CategoryConfiguration(
      id: 'hall',
      slug: 'hall',
      name: 'Hall',
      offerVisible: false,
    );
    expect(offer.isPercentage, isFalse);
    expect(offer.displayVisible, isTrue);
    expect(offer.visibleFor(visibleCat), isTrue);
    expect(offer.visibleFor(hiddenCat), isFalse);
  });

  test('offers outside their validity window are not visible', () {
    const category = CategoryConfiguration(
      id: 'hall',
      slug: 'hall',
      name: 'Hall',
    );
    final offer = OfferConfiguration(
      id: 'o2',
      title: 'Seasonal',
      startsAt: DateTime(2026, 9, 1),
      endsAt: DateTime(2026, 9, 30),
    );

    expect(offer.visibleFor(category, now: DateTime(2026, 8, 31)), isFalse);
    expect(offer.visibleFor(category, now: DateTime(2026, 9, 15)), isTrue);
    expect(offer.visibleFor(category, now: DateTime(2026, 10, 1)), isFalse);
  });

  test('theme tokens accept a secondary color without a second engine', () {
    const seed = Color(0xFF3F51B5);
    final tokens = ThemeTokens.fromSeed(
      seed,
      secondary: const Color(0xFFFF7043),
    );
    expect(
      tokens.primary,
      ThemeTokens.colorSchemeFor(seed, Brightness.light).primary,
    );
    expect(tokens.secondary, const Color(0xFFFF7043));
    final accent = const CategoryConfiguration(
      id: '1',
      slug: 'hall',
      name: 'Hall',
      themeColor: '#1565C0',
    ).accentColor;
    expect(accent, const Color(0xFF1565C0));
  });

  test(
    'English, Telugu and Hindi intents map into existing booking fields',
    () {
      const parser = BookingIntentParser();
      final now = DateTime(2026, 8, 20);
      final en = parser.parse(
        'Tomorrow book function hall for 300 people',
        now: now,
      );
      final te = parser.parse(
        'రేపు 300 మందికి ఫంక్షన్ హాల్ బుక్ చేయాలి',
        now: now,
      );
      final hi = parser.parse('कल 300 लोगों के लिए हॉल बुक करना है', now: now);
      for (final intent in [en, te, hi]) {
        expect(intent.category, 'function_halls');
        expect(intent.guests, 300);
        expect(intent.date, DateTime(2026, 8, 21));
        expect(intent.wantsBooking, isTrue);
        expect(intent.missingRequired, isEmpty);
        expect(intent.toFieldValues().values['guests'], 300);
      }
    },
  );

  test('incomplete AI booking asks instead of guessing', () {
    final intent = const BookingIntentParser().parse('book a function hall');
    expect(intent.category, 'function_halls');
    expect(intent.wantsBooking, isTrue);
    expect(intent.guests, isNull);
    expect(intent.date, isNull);
    expect(intent.missingRequired, containsAll(['date', 'guests']));
    expect(intent.isCompleteForBooking, isFalse);
  });

  test(
    'analytics display config hides charts without a second analytics system',
    () {
      final config = AnalyticsDisplayConfig.fromFeature(
        const FeatureConfig(
          config: {
            'show_kpis': true,
            'show_charts': false,
            'kpi_order': ['net_revenue', 'total_revenue'],
            'date_ranges': ['today', 'last_7_days'],
          },
        ),
      );
      expect(config.showKpis, isTrue);
      expect(config.showCharts, isFalse);
      expect(config.showDaily, isFalse);
      expect(config.showWeekly, isFalse);
      expect(config.showMonthly, isFalse);
      expect(config.showCategoryBreakdown, isFalse);
      expect(config.showListingBreakdown, isFalse);
      expect(config.kpiOrder, ['net_revenue', 'total_revenue']);
      expect(config.dateRanges, ['today', 'last_7_days']);
    },
  );

  test('invoice and notification failures stay fail-closed', () {
    expect(InvoiceArtifact.fromJson(const {}).invoiceNumber, '');
    expect(BookingSideEffect.parseInvoice(null), isNull);
    expect(BookingSideEffect.parseInvoice({'bad': true})?.canOpenPdf, isFalse);
    expect(
      BookingSideEffect.parseInvoice({
        'invoice_number': 'BMS-1',
        'signed_url': 'https://example.test/a.pdf',
      })?.canShare,
      isTrue,
    );
  });
}

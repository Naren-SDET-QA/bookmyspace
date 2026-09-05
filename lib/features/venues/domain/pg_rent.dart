import 'venue.dart';

/// One PG sharing occupancy option (single / twin / triple, etc.).
class PgSharingOption {
  const PgSharingOption({
    required this.id,
    required this.typeName,
    required this.monthlyRent,
    required this.depositAmount,
    this.isAvailable = true,
    this.roomFeatures = const [],
  });

  final String id;
  final String typeName;
  final double monthlyRent;
  final double depositAmount;
  final bool isAvailable;
  final List<String> roomFeatures;

  factory PgSharingOption.fromJson(Map<String, dynamic> json) {
    final features = json['room_features'] ?? json['roomFeatures'];
    return PgSharingOption(
      id: json['id']?.toString() ?? '',
      typeName: (json['type_name'] ?? json['typeName'] ?? '').toString(),
      monthlyRent: _asDouble(json['monthly_rent'] ?? json['monthlyRent']),
      depositAmount: _asDouble(json['deposit_amount'] ?? json['depositAmount']),
      isAvailable:
          json['is_available'] as bool? ?? json['isAvailable'] as bool? ?? true,
      roomFeatures: features is List
          ? features
                .map((e) => e.toString())
                .where((e) => e.isNotEmpty)
                .toList()
          : const [],
    );
  }
}

/// PG listing extras used by the rent calculator.
class PgDetails {
  const PgDetails({
    this.pgType = '',
    this.sharingOptions = const [],
    this.securityDepositMonths = 1,
    this.monthlyMaintenanceFee = 0,
  });

  final String pgType;
  final List<PgSharingOption> sharingOptions;
  final double securityDepositMonths;
  final double monthlyMaintenanceFee;

  /// Alias matching the legacy field name.
  double get maintenanceFee => monthlyMaintenanceFee;

  factory PgDetails.fromJson(Map<String, dynamic> json) {
    final options = json['sharing_options'] ?? json['sharingOptions'];
    return PgDetails(
      pgType: (json['pg_type'] ?? json['pgType'] ?? '').toString(),
      sharingOptions: options is List
          ? options
                .whereType<Map<Object?, Object?>>()
                .map(
                  (e) => PgSharingOption.fromJson(Map<String, dynamic>.from(e)),
                )
                .toList()
          : const [],
      securityDepositMonths: _asDouble(
        json['security_deposit_months'] ?? json['securityDepositMonths'],
        1,
      ),
      monthlyMaintenanceFee: _asDouble(
        json['maintenance_fee'] ?? json['maintenanceFee'],
      ),
    );
  }

  /// Reads PG extras from category metadata when a dedicated table is absent.
  static PgDetails? tryFromVenue(Venue venue) {
    final meta = venue.category?.metadata ?? const <String, dynamic>{};
    final nested = meta['pg_details'] ?? meta['pgDetails'];
    if (nested is Map) {
      return PgDetails.fromJson(Map<String, dynamic>.from(nested));
    }
    final options = meta['sharing_options'] ?? meta['sharingOptions'];
    if (options is List) {
      return PgDetails(
        pgType: (meta['pg_type'] ?? meta['pgType'] ?? '').toString(),
        sharingOptions: options
            .whereType<Map<Object?, Object?>>()
            .map((e) => PgSharingOption.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        securityDepositMonths: _asDouble(
          meta['security_deposit_months'] ?? meta['securityDepositMonths'],
          1,
        ),
        monthlyMaintenanceFee: _asDouble(
          meta['maintenance_fee'] ?? meta['maintenanceFee'],
        ),
      );
    }
    return null;
  }
}

/// Calculated PG cost lines. Matches legacy [PgRentBreakdown].
class PgRentBreakdown {
  const PgRentBreakdown({
    required this.monthlyBaseRent,
    required this.securityDeposit,
    required this.monthlyMaintenanceFee,
    this.tenureMonths = 1,
  });

  final double monthlyBaseRent;
  final double securityDeposit;
  final double monthlyMaintenanceFee;
  final int tenureMonths;

  double get monthlyPayable => monthlyBaseRent + monthlyMaintenanceFee;

  double get totalRent => monthlyBaseRent * tenureMonths;

  double get totalMaintenance => monthlyMaintenanceFee * tenureMonths;

  /// First-month cash out: one month rent + deposit + one month maintenance.
  double get totalMoveInCost =>
      monthlyBaseRent + securityDeposit + monthlyMaintenanceFee;

  /// Full stay: rent × tenure + deposit + maintenance × tenure.
  double get totalTenureCost => totalRent + securityDeposit + totalMaintenance;
}

/// Pure PG rent calculator. Does not change booking holds or payment amounts.
class PgRentCalculator {
  const PgRentCalculator._();

  static const int minTenureMonths = 1;
  static const int maxTenureMonths = 12;

  static int sanitizeTenure(int months) {
    if (months < minTenureMonths) return minTenureMonths;
    if (months > maxTenureMonths) return maxTenureMonths;
    return months;
  }

  static double sanitizeAmount(double value) {
    if (value.isNaN || value.isInfinite || value.isNegative) return 0;
    return value;
  }

  /// Direct calculation from numeric inputs (empty/invalid values sanitized).
  static PgRentBreakdown calculate({
    double monthlyRent = 0,
    double deposit = 0,
    double maintenance = 0,
    int tenureMonths = 1,
  }) {
    return PgRentBreakdown(
      monthlyBaseRent: sanitizeAmount(monthlyRent),
      securityDeposit: sanitizeAmount(deposit),
      monthlyMaintenanceFee: sanitizeAmount(maintenance),
      tenureMonths: sanitizeTenure(tenureMonths),
    );
  }

  static PgRentBreakdown fromVenue(
    Venue venue, {
    int selectedOptionIndex = 0,
    int tenureMonths = 1,
  }) {
    final details = PgDetails.tryFromVenue(venue);
    if (details == null) {
      final base = sanitizeAmount(venue.pricingBaseAmount);
      return calculate(
        monthlyRent: base,
        deposit: base,
        maintenance: 0,
        tenureMonths: tenureMonths,
      );
    }
    return fromDetails(
      details,
      selectedOptionIndex: selectedOptionIndex,
      fallbackBase: venue.pricingBaseAmount,
      tenureMonths: tenureMonths,
    );
  }

  static PgRentBreakdown fromDetails(
    PgDetails details, {
    PgSharingOption? selectedOption,
    int selectedOptionIndex = 0,
    double fallbackBase = 0,
    int tenureMonths = 1,
  }) {
    final options = details.sharingOptions;
    PgSharingOption? option = selectedOption;
    if (option == null && options.isNotEmpty) {
      if (selectedOptionIndex >= 0 && selectedOptionIndex < options.length) {
        option = options[selectedOptionIndex];
      } else {
        option = options.first;
      }
    }

    final baseRent = sanitizeAmount(option?.monthlyRent ?? fallbackBase);
    final deposit = option != null
        ? sanitizeAmount(option.depositAmount)
        : sanitizeAmount(
            baseRent *
                (details.securityDepositMonths < 1
                    ? 1
                    : details.securityDepositMonths),
          );

    return calculate(
      monthlyRent: baseRent,
      deposit: deposit,
      maintenance: details.maintenanceFee,
      tenureMonths: tenureMonths,
    );
  }
}

double _asDouble(Object? value, [double fallback = 0]) {
  if (value is num) {
    final n = value.toDouble();
    if (n.isNaN || n.isInfinite) return fallback;
    return n;
  }
  if (value is String) {
    final n = double.tryParse(value.trim());
    if (n == null || n.isNaN || n.isInfinite) return fallback;
    return n;
  }
  return fallback;
}

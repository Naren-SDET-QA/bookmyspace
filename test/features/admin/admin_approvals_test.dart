import 'package:bookmyspace/features/admin/domain/admin_content_repository.dart';
import 'package:bookmyspace/features/admin/domain/content_models.dart';
import 'package:bookmyspace/features/admin/presentation/content_providers.dart';
import 'package:bookmyspace/features/admin/presentation/screens/admin_content_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAdminRepo implements AdminContentRepository {
  final approvals = <String, bool>{};

  @override
  Future<AdminContentVenue> approveVenue(
    String venueId, {
    required bool approve,
    String? notes,
  }) async {
    approvals[venueId] = approve;
    return AdminContentVenue(
      id: venueId,
      name: 'Pending Hall',
      isActive: approve,
      isVerified: approve,
    );
  }

  @override
  Future<HomepageContentConfig> homepageConfig() async =>
      const HomepageContentConfig();

  @override
  Future<List<HomepageSection>> listHomepageSections({
    bool includeHidden = true,
  }) async => const [];

  @override
  Future<List<HomeCategoryTile>> listCategoryTiles({
    bool includeHidden = true,
  }) async => const [];

  @override
  Future<List<AdminContentVenue>> listVenues({
    String? query,
    int limit = 50,
  }) async => const [];

  @override
  Future<AdminContentVenue> updateVenueContent(
    String venueId,
    Map<String, dynamic> patch,
  ) async => throw UnimplementedError();

  @override
  Future<int> replaceVenueImages(
    String venueId,
    List<Map<String, dynamic>> images,
  ) async => 0;

  @override
  Future<int> setVenueAmenities(String venueId, List<String> amenities) async => 0;

  @override
  Future<HomepageSection> upsertHomepageSection({
    required String sectionKey,
    required String title,
    String? emoji,
    int? sortOrder,
    bool? isVisible,
    Map<String, dynamic>? config,
  }) async => throw UnimplementedError();

  @override
  Future<int> reorderHomepageSections(List<String> orderedKeys) async => 0;

  @override
  Future<HomeCategoryTile> upsertCategoryTile({
    required String tileKey,
    required String label,
    required String emoji,
    required String routeTarget,
    int? sortOrder,
    bool? isVisible,
  }) async => throw UnimplementedError();

  @override
  Future<Map<String, dynamic>> updateCategoryDisplay({
    required String categoryId,
    String? displayName,
    String? icon,
    int? sortOrder,
    bool? isHomeVisible,
  }) async => throw UnimplementedError();

  @override
  Future<Map<String, dynamic>> setPlatformSetting({
    required String key,
    required Map<String, dynamic> value,
    String? description,
  }) async => throw UnimplementedError();

  @override
  Future<Map<String, dynamic>> setOrgCommission({
    required String orgId,
    required double commissionRate,
  }) async => throw UnimplementedError();
}

void main() {
  testWidgets('Approvals tab lists pending halls and publishes on approve',
      (tester) async {
    final fake = _FakeAdminRepo();
    const pendingVenue = AdminContentVenue(
      id: 'venue-1',
      name: 'Grand Function Hall',
      city: 'Ongole',
      pricingBaseAmount: 15000,
      capacity: 300,
      isActive: false,
      isVerified: false,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          adminContentRepositoryProvider.overrideWithValue(fake),
          adminContentVenuesProvider.overrideWith(
            (ref) async => [pendingVenue],
          ),
        ],
        child: const MaterialApp(home: AdminContentScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // Approvals tab is first; pending hall listed.
    expect(find.text('Grand Function Hall'), findsOneWidget);
    expect(find.text('⏳ Pending review'), findsOneWidget);

    // Approve -> repo called with approve=true.
    await tester.tap(find.text('Approve & publish'));
    await tester.pumpAndSettle();

    expect(fake.approvals['venue-1'], isTrue);
  });

  testWidgets('Approvals tab shows empty state when nothing pending',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          adminContentRepositoryProvider.overrideWithValue(_FakeAdminRepo()),
          adminContentVenuesProvider.overrideWith((ref) async => const []),
        ],
        child: const MaterialApp(home: AdminContentScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No pending approvals'), findsOneWidget);
  });
}

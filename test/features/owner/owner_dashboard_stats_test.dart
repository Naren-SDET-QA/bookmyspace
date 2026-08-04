import 'package:bookmyspace/features/owner/domain/owner_dashboard_stats.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('OwnerDashboardStats holds computed values', () {
    const stats = OwnerDashboardStats(
      monthlyRevenue: 12500,
      totalBookings: 8,
      pendingApprovals: 2,
      todayBookings: 1,
    );

    expect(stats.monthlyRevenue, 12500);
    expect(stats.totalBookings, 8);
    expect(stats.pendingApprovals, 2);
    expect(stats.todayBookings, 1);
  });
}

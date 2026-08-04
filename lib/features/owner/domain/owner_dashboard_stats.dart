/// Aggregated owner dashboard metrics from live Supabase queries.
class OwnerDashboardStats {
  const OwnerDashboardStats({
    required this.monthlyRevenue,
    required this.totalBookings,
    required this.pendingApprovals,
    required this.todayBookings,
  });

  final double monthlyRevenue;
  final int totalBookings;
  final int pendingApprovals;
  final int todayBookings;
}

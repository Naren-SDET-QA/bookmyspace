import 'package:bookmyspace/features/institute_listings/domain/institute_listing_plan.dart';

abstract class InstituteListingPlanRepository {
  Future<List<InstituteListingPlan>> getActivePlans();
}

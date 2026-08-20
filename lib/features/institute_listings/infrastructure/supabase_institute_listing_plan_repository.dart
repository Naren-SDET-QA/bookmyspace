import 'package:bookmyspace/core/errors/app_exceptions.dart';
import 'package:bookmyspace/core/network/dio_client.dart';
import 'package:bookmyspace/features/institute_listings/domain/institute_listing_plan.dart';
import 'package:bookmyspace/features/institute_listings/domain/institute_listing_plan_repository.dart';
import 'package:dio/dio.dart';

class SupabaseInstituteListingPlanRepository
    implements InstituteListingPlanRepository {
  SupabaseInstituteListingPlanRepository(this._dio);

  final Dio _dio;

  @override
  Future<List<InstituteListingPlan>> getActivePlans() async {
    try {
      final response = await _dio.get(
        '/institute_listing_plans',
        queryParameters: {'is_active': 'true'},
      );
      final List<dynamic> data = response.data;
      return data.map((json) => InstituteListingPlan.fromJson(json)).toList();
    } on DioException catch (e) {
      throw AppException.fromDioError(e);
    } catch (e) {
      throw AppException(message: e.toString());
    }
  }
}

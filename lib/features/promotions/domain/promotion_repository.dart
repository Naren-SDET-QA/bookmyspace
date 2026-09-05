import 'promotion.dart';

abstract interface class PromotionRepository {
  Future<List<Promotion>> listActive({int limit = 10});
}

import 'package:bookmyspace/features/payments/domain/payment.dart';

abstract class InstituteListingPaymentRepository {
  Future<PaymentOrder> createOrder({required String instituteListingId});
}

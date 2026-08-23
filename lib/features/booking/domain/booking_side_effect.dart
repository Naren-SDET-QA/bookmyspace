import 'invoice_repository.dart';

/// Fail-closed helpers for invoice/email/notification after a booking exists.
/// Never retries booking/payment/refund/invoice generation.
class BookingSideEffect {
  const BookingSideEffect._();

  static InvoiceArtifact? parseInvoice(Map<String, dynamic>? json) {
    if (json == null) return null;
    try {
      return InvoiceArtifact.fromJson(json);
    } catch (_) {
      return null;
    }
  }
}

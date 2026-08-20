import 'package:flutter_test/flutter_test.dart';

import '../../../lib/features/booking/domain/invoice_repository.dart';

void main() {
  test('parses a server-generated invoice artifact and signed URL', () {
    final invoice = InvoiceArtifact.fromJson({
      'invoice': {'invoice_number': 'BMS-2026-ABC123'},
      'signed_url': 'https://example.test/signed-invoice',
    });

    expect(invoice.invoiceNumber, 'BMS-2026-ABC123');
    expect(invoice.signedUrl, 'https://example.test/signed-invoice');
  });

  test('accepts a flat invoice response for backwards-compatible callers', () {
    final invoice = InvoiceArtifact.fromJson({
      'invoice_number': 'BMS-2026-FLAT',
    });

    expect(invoice.invoiceNumber, 'BMS-2026-FLAT');
    expect(invoice.signedUrl, isNull);
  });
}

import 'dart:convert';

import 'package:bookmyspace/features/invoices/domain/invoice.dart';
import 'package:bookmyspace/features/invoices/presentation/invoice_pdf.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final invoice = InvoiceDocument.fromJson({
    'id': '1',
    'invoice_number': 'INV-000001',
    'document_type': 'tax_invoice',
    'status': 'issued',
    'currency': 'INR',
    'subtotal': 100,
    'discount': 10,
    'tax_total': 5,
    'fee_total': 2,
    'total': 97,
    'paid': 97,
    'due': 0,
    'refund': 0,
    'config_snapshot': {'business_name': 'Test Business'},
    'invoice_snapshot': {
      'customer_name': 'Customer',
      'line_items': [
        {
          'description': 'Booking',
          'quantity': 1,
          'unit_price': 100,
          'amount': 100,
        },
      ],
    },
    'issued_at': '2026-08-04T00:00:00Z',
  });

  test('parses immutable invoice totals and snapshots', () {
    expect(invoice.number, 'INV-000001');
    expect(invoice.total, 97);
    expect(invoice.config['business_name'], 'Test Business');
  });

  test('generates a valid PDF document', () async {
    final bytes = await buildInvoicePdf(invoice);
    expect(ascii.decode(bytes.take(4).toList()), '%PDF');
    expect(bytes.length, greaterThan(500));
  });
}

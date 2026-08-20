import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/invoice_repository.dart';

class SupabaseInvoiceRepository implements InvoiceRepository {
  SupabaseInvoiceRepository(this._client);
  final SupabaseClient _client;

  @override
  Future<InvoiceArtifact> generate(String bookingId) async {
    final result = await _client.functions.invoke(
      'generate-invoice',
      body: {'booking_id': bookingId},
    );
    if (result.data is! Map) {
      throw StateError('Invoice generation returned an invalid response');
    }
    return InvoiceArtifact.fromJson(
      Map<String, dynamic>.from(result.data as Map),
    );
  }
}

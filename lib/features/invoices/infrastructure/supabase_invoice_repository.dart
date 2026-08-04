import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exceptions.dart' as errors;
import '../domain/invoice.dart';

class SupabaseInvoiceRepository implements InvoiceRepository {
  SupabaseInvoiceRepository(this.client);
  final SupabaseClient client;

  @override
  Future<Map<String, dynamic>> config() async {
    try {
      final uid = client.auth.currentUser?.id;
      if (uid == null) return const {};
      final row = await client
          .from('invoice_configs')
          .select('config')
          .eq('owner_user_id', uid)
          .maybeSingle();
      return Map<String, dynamic>.from(row?['config'] as Map? ?? const {});
    } catch (error) {
      throw errors.mapError(error);
    }
  }

  @override
  Future<void> saveConfig(Map<String, dynamic> config) async {
    try {
      await client.rpc<void>(
        'save_invoice_config',
        params: {'p_config': config},
      );
    } catch (error) {
      throw errors.mapError(error);
    }
  }

  @override
  Future<InvoiceDocument> invoice(String id) async {
    try {
      final row = await client.from('invoices').select().eq('id', id).single();
      return InvoiceDocument.fromJson(row);
    } catch (error) {
      throw errors.mapError(error);
    }
  }

  @override
  Future<String> issue({
    required String bookingId,
    required String documentType,
    required Map<String, dynamic> snapshot,
    String? parentInvoiceId,
  }) async {
    try {
      return await client.rpc<String>(
        'issue_invoice',
        params: {
          'p_booking_id': bookingId,
          'p_document_type': documentType,
          'p_invoice': snapshot,
          'p_parent_invoice_id': parentInvoiceId,
        },
      );
    } catch (error) {
      throw errors.mapError(error);
    }
  }

  @override
  Future<String> issueCommerce({
    required String referenceId,
    String documentType = 'receipt',
    Map<String, dynamic> snapshot = const {},
  }) async {
    try {
      return await client.rpc<String>(
        'issue_commerce_invoice',
        params: {
          'p_reference_id': referenceId,
          'p_document_type': documentType,
          'p_invoice': snapshot,
        },
      );
    } catch (error) {
      throw errors.mapError(error);
    }
  }
}

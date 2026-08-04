import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/invoice.dart';
import '../infrastructure/supabase_invoice_repository.dart';

final invoiceRepositoryProvider = Provider<InvoiceRepository>(
  (ref) => SupabaseInvoiceRepository(Supabase.instance.client),
);
final invoiceConfigProvider = FutureProvider<Map<String, dynamic>>(
  (ref) => ref.watch(invoiceRepositoryProvider).config(),
);
final invoiceProvider = FutureProvider.family<InvoiceDocument, String>(
  (ref, id) => ref.watch(invoiceRepositoryProvider).invoice(id),
);

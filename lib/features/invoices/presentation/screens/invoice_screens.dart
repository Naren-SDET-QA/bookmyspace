import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/error_view.dart';
import '../../domain/invoice.dart';
import '../invoice_pdf.dart';
import '../invoice_providers.dart';

class InvoiceConfigScreen extends ConsumerStatefulWidget {
  const InvoiceConfigScreen({super.key});
  @override
  ConsumerState<InvoiceConfigScreen> createState() => _InvoiceConfigState();
}

class _InvoiceConfigState extends ConsumerState<InvoiceConfigScreen> {
  final formKey = GlobalKey<FormState>();
  final controllers = <String, TextEditingController>{};
  final visible = <String, bool>{};
  bool loaded = false, busy = false;
  static const fields = <String, String>{
    'business_name': 'Business name',
    'logo_url': 'Logo URL',
    'address': 'Address',
    'phone': 'Phone',
    'email': 'Email',
    'tax_details': 'GSTIN / tax details',
    'tax_rules': 'Tax rules / labels',
    'fee_rules': 'Fee rules / labels',
    'invoice_prefix': 'Invoice prefix',
    'bank_details': 'Bank / payment details',
    'terms': 'Terms',
    'signature': 'Signature',
    'footer': 'Footer',
  };
  static const switches = [
    'address',
    'contact',
    'tax_details',
    'customer',
    'booking',
    'resource',
    'dates',
    'payment',
    'bank',
    'terms',
    'signature',
  ];

  void load(Map<String, dynamic> config) {
    if (loaded) return;
    loaded = true;
    for (final entry in fields.entries) {
      controllers[entry.key] = TextEditingController(
        text: config[entry.key]?.toString() ?? '',
      );
    }
    final existing = Map<String, dynamic>.from(
      config['visible_fields'] as Map? ?? const {},
    );
    for (final key in switches) {
      visible[key] = existing[key] as bool? ?? true;
    }
  }

  Future<void> save() async {
    if (!(formKey.currentState?.validate() ?? false)) return;
    setState(() => busy = true);
    try {
      await ref.read(invoiceRepositoryProvider).saveConfig({
        for (final entry in controllers.entries)
          entry.key: entry.value.text.trim(),
        'visible_fields': visible,
      });
      ref.invalidate(invoiceConfigProvider);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Invoice settings saved')));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Invoice settings')),
    body: ref
        .watch(invoiceConfigProvider)
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => ErrorView(
            message: error.toString(),
            onRetry: () => ref.invalidate(invoiceConfigProvider),
          ),
          data: (config) {
            load(config);
            return Form(
              key: formKey,
              child: ListView(
                padding: const EdgeInsets.all(AppTheme.pagePadding),
                children: [
                  for (final entry in fields.entries)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: TextFormField(
                        controller: controllers[entry.key],
                        maxLines:
                            {
                              'address',
                              'bank_details',
                              'terms',
                              'footer',
                            }.contains(entry.key)
                            ? 3
                            : 1,
                        decoration: InputDecoration(labelText: entry.value),
                        validator: entry.key == 'business_name'
                            ? (value) => value == null || value.trim().isEmpty
                                  ? 'Required'
                                  : null
                            : null,
                      ),
                    ),
                  Text(
                    'Visible fields',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  for (final key in switches)
                    SwitchListTile(
                      value: visible[key] ?? true,
                      title: Text(key.replaceAll('_', ' ')),
                      onChanged: (value) =>
                          setState(() => visible[key] = value),
                    ),
                  FilledButton.icon(
                    onPressed: busy ? null : save,
                    icon: const Icon(Icons.save),
                    label: Text(busy ? 'Saving...' : 'Save settings'),
                  ),
                ],
              ),
            );
          },
        ),
  );
}

class InvoiceScreen extends ConsumerWidget {
  const InvoiceScreen({super.key, required this.invoiceId});
  final String invoiceId;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: const Text('Invoice')),
    body: ref
        .watch(invoiceProvider(invoiceId))
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => ErrorView(
            message: error.toString(),
            onRetry: () => ref.invalidate(invoiceProvider(invoiceId)),
          ),
          data: (invoice) => PdfPreview(
            build: (_) => buildInvoicePdf(invoice),
            pdfFileName: '${invoice.number}.pdf',
            canChangeOrientation: false,
            canChangePageFormat: false,
            allowPrinting: true,
            allowSharing: true,
          ),
        ),
  );
}

Future<String> issueSharedInvoice(
  InvoiceRepository repository, {
  required String bookingId,
  required String documentType,
  required Map<String, dynamic> snapshot,
  String? parentInvoiceId,
}) => repository.issue(
  bookingId: bookingId,
  documentType: documentType,
  snapshot: snapshot,
  parentInvoiceId: parentInvoiceId,
);

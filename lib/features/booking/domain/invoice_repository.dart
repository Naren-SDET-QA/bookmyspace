class InvoiceArtifact {
  const InvoiceArtifact({required this.invoiceNumber, this.signedUrl});

  final String invoiceNumber;
  final String? signedUrl;

  factory InvoiceArtifact.fromJson(Map<String, dynamic> json) {
    final invoice = json['invoice'] is Map
        ? Map<String, dynamic>.from(json['invoice'] as Map)
        : json;
    return InvoiceArtifact(
      invoiceNumber: invoice['invoice_number'] as String? ?? '',
      signedUrl: json['signed_url'] as String?,
    );
  }
}

abstract interface class InvoiceRepository {
  Future<InvoiceArtifact> generate(String bookingId);
}

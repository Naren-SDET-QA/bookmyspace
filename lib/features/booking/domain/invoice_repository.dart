class InvoiceArtifact {
  const InvoiceArtifact({
    required this.invoiceNumber,
    this.signedUrl,
    this.emailQueued = false,
    this.notificationQueued = false,
  });

  final String invoiceNumber;
  final String? signedUrl;

  /// True when generate-invoice enqueued `email_outbox` with the service role.
  /// The client never inserts into `email_outbox`.
  final bool emailQueued;

  /// True when the server queued a notification. Client never writes notifications.
  final bool notificationQueued;

  bool get canOpenPdf => signedUrl != null && signedUrl!.isNotEmpty;
  bool get canShare => canOpenPdf;

  factory InvoiceArtifact.fromJson(Map<String, dynamic> json) {
    final invoice = json['invoice'] is Map
        ? Map<String, dynamic>.from(json['invoice'] as Map)
        : json;
    return InvoiceArtifact(
      invoiceNumber: invoice['invoice_number'] as String? ?? '',
      signedUrl: json['signed_url'] as String?,
      emailQueued: json['email_queued'] == true,
      notificationQueued: json['notification_queued'] == true,
    );
  }
}

abstract interface class InvoiceRepository {
  Future<InvoiceArtifact> generate(String bookingId);
}

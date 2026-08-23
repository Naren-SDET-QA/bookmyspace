import '../../../core/modular/feature_config.dart';
import '../../venues/domain/category_configuration.dart';

/// UI visibility for the existing server-side invoice artifact.
/// Stored on FeatureId.invoice FeatureConfig.config — not a second invoice store.
class InvoiceDisplayConfig {
  const InvoiceDisplayConfig({
    this.showPdf = true,
    this.showPrint = true,
    this.showShare = true,
    this.showEmailStatus = true,
    this.showNotificationStatus = true,
    this.showQr = true,
  });

  final bool showPdf;
  final bool showPrint;
  final bool showShare;
  final bool showEmailStatus;
  final bool showNotificationStatus;
  final bool showQr;

  InvoiceDisplayConfig applyCategory(CategoryConfiguration? category) {
    if (category == null) return this;
    return InvoiceDisplayConfig(
      showPdf: showPdf && category.invoiceVisible,
      showPrint: showPrint && category.invoiceVisible,
      showShare: showShare && category.invoiceVisible,
      showEmailStatus: showEmailStatus && category.invoiceVisible,
      showNotificationStatus:
          showNotificationStatus && category.notificationVisible,
      showQr: showQr && category.qrVisible,
    );
  }

  factory InvoiceDisplayConfig.fromFeature(FeatureConfig config) {
    bool flag(String key, bool fallback) {
      final value = config.config[key];
      if (value is bool) return value;
      return fallback;
    }

    final visible = flag('invoice_visible', config.enabled);
    return InvoiceDisplayConfig(
      showPdf: visible && flag('show_pdf', true),
      showPrint: visible && flag('show_print', true),
      showShare: visible && flag('show_share', true),
      showEmailStatus: visible && flag('email_visible', true),
      showNotificationStatus: visible && flag('notification_visible', true),
      showQr: visible && flag('qr_visible', true),
    );
  }
}

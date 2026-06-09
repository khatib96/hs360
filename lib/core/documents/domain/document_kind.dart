/// Supported document types for Phase 5 M3 print renderer.
enum DocumentKind {
  salesInvoice('sales_invoice'),
  purchaseInvoice('purchase_invoice'),
  receiptVoucher('receipt_voucher'),
  paymentVoucher('payment_voucher'),
  customerStatement('customer_statement'),
  assetTagLabel('asset_tag_label');

  const DocumentKind(this.documentType);

  final String documentType;

  static DocumentKind? fromDocumentType(String? value) {
    if (value == null) return null;
    for (final kind in DocumentKind.values) {
      if (kind.documentType == value) return kind;
    }
    return null;
  }
}

/// Paper formats stored on templates and tenant settings.
enum PaperKind {
  a4('a4'),
  thermal80mm('thermal_80mm'),
  labelSheet('label_sheet');

  const PaperKind(this.value);

  final String value;

  static PaperKind? fromValue(String? value) {
    if (value == null) return null;
    for (final kind in PaperKind.values) {
      if (kind.value == value) return kind;
    }
    return null;
  }
}

/// Template language mode.
enum DocumentLanguageMode {
  ar('ar'),
  en('en'),
  bilingual('bilingual');

  const DocumentLanguageMode(this.value);

  final String value;

  static DocumentLanguageMode fromValue(String? value) {
    return DocumentLanguageMode.values.firstWhere(
      (m) => m.value == value,
      orElse: () => DocumentLanguageMode.bilingual,
    );
  }
}

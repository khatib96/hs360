import 'document_kind.dart';

/// Central policy for tenant-configurable document columns.
class DocumentOptionalColumns {
  const DocumentOptionalColumns._();

  static const Map<DocumentKind, Set<String>> optionalFields = {
    DocumentKind.salesInvoice: {'line.qty', 'line.unit_price'},
    DocumentKind.purchaseInvoice: {'line.qty', 'line.unit_price'},
    DocumentKind.customerStatement: {'line.debit', 'line.credit'},
  };

  static bool isVisible({
    required DocumentKind documentType,
    required String field,
    required Map<String, dynamic> tenantSettings,
  }) {
    if (!(optionalFields[documentType]?.contains(field) ?? false)) {
      return true;
    }

    final allColumns = tenantSettings['optional_columns_json'];
    if (allColumns is! Map) return true;

    final documentColumns = allColumns[documentType.documentType];
    if (documentColumns is! Map) return true;

    return documentColumns[field] != false;
  }
}

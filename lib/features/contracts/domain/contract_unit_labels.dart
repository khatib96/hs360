import '../../../core/documents/services/pdf/pdf_field_labels.dart';
import '../../products/domain/unit_of_measure.dart';

/// Bilingual unit labels for contract PDF line rendering.
abstract final class ContractUnitLabels {
  static String labelForDbValue(
    String? dbValue, {
    required String languageCode,
  }) {
    return PdfFieldLabels.unitLabel(dbValue, languageCode: languageCode);
  }

  static String labelForUnit(
    UnitOfMeasure? unit, {
    required String languageCode,
  }) {
    if (unit == null) return '';
    return labelForDbValue(unit.dbValue, languageCode: languageCode);
  }
}

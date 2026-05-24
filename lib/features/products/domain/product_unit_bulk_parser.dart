import 'package:decimal/decimal.dart';

import '../../../core/utils/decimal_parser.dart';

/// Simple CSV / line paste parser for bulk unit serials (no quoted commas).
class ProductUnitBulkParser {
  const ProductUnitBulkParser();

  static const maxUnitsPerBatch = 100;

  static const _headerSerial = 'serial_number';
  ProductUnitBulkParseResult parse(String raw) {
    final lines = raw.split(RegExp(r'\r?\n'));
    final rows = <ProductUnitBulkRow>[];
    final errors = <String>[];
    final seenSerials = <String>{};
    var startIndex = 0;

    if (lines.isNotEmpty && _isHeaderLine(lines.first)) {
      startIndex = 1;
    }

    for (var i = startIndex; i < lines.length; i++) {
      final line = lines[i];
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      final parts = trimmed.split(',').map((p) => p.trim()).toList();
      final serial = parts.isNotEmpty ? parts.first : '';
      if (serial.isEmpty) {
        errors.add('empty_serial_line_${i + 1}');
        continue;
      }

      final serialKey = serial.toLowerCase();
      if (seenSerials.contains(serialKey)) {
        errors.add('duplicate_serial_in_input:$serial');
      }
      seenSerials.add(serialKey);

      String? barcode;
      Decimal? cost;
      if (parts.length > 1 && parts[1].isNotEmpty) {
        barcode = parts[1];
      }
      if (parts.length > 2 && parts[2].isNotEmpty) {
        final parsed = tryParseDecimal(parts[2]);
        if (parsed == null) {
          errors.add('invalid_cost_line_${i + 1}');
        } else if (parsed < Decimal.zero) {
          errors.add('negative_cost_line_${i + 1}');
        } else {
          cost = parsed;
        }
      }

      rows.add(
        ProductUnitBulkRow(
          serialNumber: serial,
          barcode: barcode,
          purchaseCost: cost,
        ),
      );
    }

    if (rows.length > maxUnitsPerBatch) {
      errors.add('bulk_limit_exceeded');
    }

    return ProductUnitBulkParseResult(rows: rows, errors: errors);
  }

  bool _isHeaderLine(String line) {
    final lower = line.trim().toLowerCase();
    return lower.contains(_headerSerial) ||
        lower == 'serial,barcode,cost' ||
        lower.startsWith('serial');
  }
}

class ProductUnitBulkRow {
  const ProductUnitBulkRow({
    required this.serialNumber,
    this.barcode,
    this.purchaseCost,
  });

  final String serialNumber;
  final String? barcode;
  final Decimal? purchaseCost;
}

class ProductUnitBulkParseResult {
  const ProductUnitBulkParseResult({
    required this.rows,
    required this.errors,
  });

  final List<ProductUnitBulkRow> rows;
  final List<String> errors;

  bool get hasErrors => errors.isNotEmpty;
  bool get isEmpty => rows.isEmpty;
}

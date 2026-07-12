import 'package:decimal/decimal.dart';
import 'package:intl/intl.dart';

import '../../domain/document_money_formatter.dart';
import '../../domain/effective_language.dart';
import '../../domain/tenant_currency_format.dart';
import 'pdf_field_labels.dart';

/// Resolves template field paths to display strings from serialized payload JSON.
class PdfFieldResolver {
  const PdfFieldResolver({
    required this.payload,
    required this.currency,
    required this.languageCode,
  });

  final Map<String, dynamic> payload;
  final TenantCurrencyFormat currency;
  final String languageCode;

  static const moneyFields = {
    'line.debit',
    'line.credit',
    'line.balance',
    'line.unit_price',
    'line.total',
    'summary.opening_balance',
    'summary.total_debit',
    'summary.total_credit',
    'summary.closing_balance',
    'totals.subtotal',
    'totals.discount',
    'totals.tax',
    'totals.total',
    'totals.monthly_rental',
    'totals.total_value',
    'payment.amount',
  };
  static const statementLineMoneyFields = {
    'line.debit',
    'line.credit',
    'line.balance',
  };

  String resolve(String field) {
    if (field == 'totals.is_trial') {
      return _formatTrialFlag(_rawValue(field));
    }
    if (field == 'document.type') {
      return _formatContractType(_rawValue(field));
    }
    if (field == 'document.status') {
      return _formatContractStatus(_rawValue(field));
    }
    if (field == 'line.unit') {
      return _formatUnit(_rawValue(field));
    }
    if (moneyFields.contains(field)) {
      return _formatMoney(_rawValue(field));
    }
    if (field.endsWith('.date') ||
        field == 'document.from_date' ||
        field == 'document.to_date' ||
        field == 'document.generated_at' ||
        field == 'document.start_date' ||
        field == 'document.end_date' ||
        field == 'document.trial_end_date' ||
        field == 'document.printed_at' ||
        field == 'line.date') {
      return _formatDate(_rawValue(field));
    }
    final value = _rawValue(field);
    if (value == null) return '';
    return value.toString();
  }

  String resolveNotes() {
    final root = payload['notes'];
    if (root is String && root.trim().isNotEmpty) return root;
    final document = payload['document'];
    if (document is Map) {
      final docNotes = document['notes'];
      if (docNotes is String && docNotes.trim().isNotEmpty) return docNotes;
    }
    return '';
  }

  String resolveMoney(String field, {required String languageCode}) {
    return _formatMoney(_rawValue(field), languageCodeOverride: languageCode);
  }

  List<Map<String, String>> resolveLineRows(
    List<String> fields,
    List<Map<String, dynamic>> lines,
  ) {
    return lines.map((line) {
      final row = <String, String>{};
      for (final field in fields) {
        row[field] = _resolveLineField(field, line);
      }
      return row;
    }).toList();
  }

  String _resolveLineField(String field, Map<String, dynamic> line) {
    if (moneyFields.contains(field)) {
      final key = switch (field) {
        'line.balance' => 'running_balance',
        _ => field.split('.').last,
      };
      return _formatMoney(
        line[key],
        includeSymbol: !statementLineMoneyFields.contains(field),
      );
    }
    if (field == 'line.date') {
      return _formatDate(line['entry_date']);
    }
    if (field == 'line.unit') {
      return _formatUnit(line['unit']);
    }
    if (field == 'line.description') {
      final desc = line['description'];
      if (desc != null && desc.toString().trim().isNotEmpty) {
        return desc.toString();
      }
      return line['entry_number']?.toString() ?? '';
    }
    final key = field.contains('.') ? field.split('.').last : field;
    return line[key]?.toString() ?? '';
  }

  dynamic _rawValue(String field) {
    final parts = field.split('.');
    dynamic current = payload;
    for (final part in parts) {
      if (current is! Map) return null;
      current = current[part];
    }
    return current;
  }

  String _formatMoney(
    dynamic value, {
    bool includeSymbol = true,
    String? languageCodeOverride,
  }) {
    if (value == null) return '';
    final effectiveLanguageCode = languageCodeOverride ?? languageCode;
    if (value is String) {
      final serialized = tryFormatSerializedDocumentMoney(
        value,
        currency,
        languageCode: effectiveLanguageCode,
        includeSymbol: includeSymbol,
      );
      if (serialized != null) return serialized;
    }
    final decimal = value is Decimal
        ? value
        : Decimal.tryParse(value.toString()) ?? Decimal.zero;
    return formatDocumentMoney(
      decimal,
      currency,
      languageCode: effectiveLanguageCode,
      includeSymbol: includeSymbol,
    );
  }

  String _formatDate(dynamic value) {
    if (value == null) return '';
    try {
      final date = value is DateTime
          ? value
          : DateTime.parse(value.toString().split('T').first);
      final fmt = DateFormat.yMMMd(intlLocaleFor(languageCode));
      return fmt.format(date);
    } catch (_) {
      return value.toString();
    }
  }

  String _formatUnit(dynamic value) {
    return PdfFieldLabels.unitLabel(
      value?.toString(),
      languageCode: languageCode,
    );
  }

  String _formatContractType(dynamic value) {
    return PdfFieldLabels.contractTypeLabel(
      value?.toString(),
      languageCode: languageCode,
    );
  }

  String _formatContractStatus(dynamic value) {
    return PdfFieldLabels.contractStatusLabel(
      value?.toString(),
      languageCode: languageCode,
    );
  }

  String _formatTrialFlag(dynamic value) {
    return PdfFieldLabels.trialFlagLabel(value, languageCode: languageCode);
  }
}

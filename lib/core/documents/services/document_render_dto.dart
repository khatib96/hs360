import 'dart:isolate';
import 'dart:typed_data';

import 'package:decimal/decimal.dart';

import '../domain/document_kind.dart';
import '../domain/document_payload.dart';
import '../domain/document_template.dart';
import '../domain/effective_language.dart';

/// Serializable input for the worker isolate. Money values are decimal strings.
class DocumentRenderDto {
  const DocumentRenderDto({
    required this.documentType,
    required this.paperKind,
    required this.languageCode,
    required this.templateNameAr,
    required this.templateNameEn,
    required this.templateBodyJson,
    required this.tenantSettings,
    required this.currencyJson,
    required this.companyNames,
    required this.payloadJson,
    required this.fontBundle,
    this.logoBytes,
  });

  final String documentType;
  final String paperKind;
  final String languageCode;
  final String templateNameAr;
  final String templateNameEn;
  final Map<String, dynamic> templateBodyJson;
  final Map<String, dynamic> tenantSettings;
  final Map<String, dynamic>? currencyJson;
  final Map<String, String> companyNames;
  final Map<String, dynamic> payloadJson;
  final PdfFontTransferBundle fontBundle;
  final TransferableTypedData? logoBytes;
}

/// Font bytes transferred to the worker isolate (new bundle per run).
class PdfFontTransferBundle {
  const PdfFontTransferBundle({
    required this.regularLatin,
    required this.boldLatin,
    required this.regularArabic,
    required this.boldArabic,
  });

  final TransferableTypedData regularLatin;
  final TransferableTypedData boldLatin;
  final TransferableTypedData regularArabic;
  final TransferableTypedData boldArabic;
}

/// Builds a [DocumentRenderDto] from domain objects on the root isolate.
DocumentRenderDto buildDocumentRenderDto({
  required EffectiveDocumentContext context,
  required DocumentPayload payload,
  required String userLocale,
  String? previewLanguageOverride,
  required PdfFontTransferBundle fontBundle,
  Uint8List? logoBytes,
}) {
  final languageCode = resolveEffectiveLanguage(
    templateMode: context.template.languageMode,
    tenantDefault: DocumentLanguageMode.fromValue(
      context.settings['default_language'] as String?,
    ),
    previewLanguageOverride: previewLanguageOverride,
    userLocale: userLocale,
  );

  return DocumentRenderDto(
    documentType: context.template.documentType.documentType,
    paperKind: context.template.paperKind.value,
    languageCode: languageCode,
    templateNameAr: context.template.nameAr,
    templateNameEn: context.template.nameEn,
    templateBodyJson: _templateBodyToJson(context.template.body),
    tenantSettings: context.settings,
    currencyJson: context.currency,
    companyNames: context.companyNames,
    payloadJson: serializePayload(
      payload,
      decimalPlaces: context.currency?['decimal_places'] as int? ?? 3,
    ),
    fontBundle: fontBundle,
    logoBytes: logoBytes == null
        ? null
        : TransferableTypedData.fromList([logoBytes]),
  );
}

Map<String, dynamic> _templateBodyToJson(TemplateBody body) {
  return {
    'schema_version': body.schemaVersion,
    'settings': body.settings,
    'blocks': body.blocks.map(_blockToJson).toList(),
  };
}

Map<String, dynamic> _blockToJson(TemplateBlock block) {
  final json = <String, dynamic>{'type': block.type, 'id': block.id};
  if (block.fields.isNotEmpty) json['fields'] = block.fields;
  if (block.columns.isNotEmpty) {
    json['columns'] = block.columns
        .map(
          (c) => {
            'field': c.field,
            'label_key': c.labelKey,
            'label_ar': c.labelAr,
            'label_en': c.labelEn,
            'width_pct': c.widthPct,
            'align': c.align,
          },
        )
        .toList();
  }
  if (block.partyRole != null) json['party_role'] = block.partyRole;
  if (block.source != null) json['source'] = block.source;
  if (block.payloadField != null) json['payload_field'] = block.payloadField;
  if (block.captionField != null) json['caption_field'] = block.captionField;
  if (block.heightMm != null) json['height_mm'] = block.heightMm;
  return json;
}

/// Serializes [Decimal] money for isolate transfer (no [double] conversion).
String decimalTransferString(Decimal value, {required int decimalPlaces}) {
  if (value == Decimal.zero) return '0';
  if (decimalPlaces <= 0) {
    return value.round(scale: 0).toString();
  }
  final rounded = value.round(scale: decimalPlaces);
  final negative = rounded < Decimal.zero;
  final abs = negative ? -rounded : rounded;
  final parts = abs.toString().split('.');
  final intPart = parts.first;
  final frac = parts.length > 1 ? parts[1] : '';
  final padded = frac.padRight(decimalPlaces, '0').substring(0, decimalPlaces);
  final result = '$intPart.$padded';
  return negative ? '-$result' : result;
}

/// Serializes payloads with money as decimal strings (no double conversion).
Map<String, dynamic> serializePayload(
  DocumentPayload payload, {
  int decimalPlaces = 3,
}) {
  return switch (payload) {
    StatementPayload s => {
      'kind': s.kind.documentType,
      'customer': s.customer,
      'party': {
        'name_ar': s.customer['name_ar'],
        'name_en': s.customer['name_en'],
        'code': s.customer['code'],
      },
      'document': {
        'from_date': s.fromDate.toIso8601String().split('T').first,
        'to_date': s.toDate.toIso8601String().split('T').first,
        'generated_at': s.generatedAt.toIso8601String(),
      },
      'from_date': s.fromDate.toIso8601String(),
      'to_date': s.toDate.toIso8601String(),
      'generated_at': s.generatedAt.toIso8601String(),
      'summary': {
        'opening_balance': decimalTransferString(
          s.summary.openingBalance,
          decimalPlaces: decimalPlaces,
        ),
        'total_debit': decimalTransferString(
          s.summary.totalDebit,
          decimalPlaces: decimalPlaces,
        ),
        'total_credit': decimalTransferString(
          s.summary.totalCredit,
          decimalPlaces: decimalPlaces,
        ),
        'closing_balance': decimalTransferString(
          s.summary.closingBalance,
          decimalPlaces: decimalPlaces,
        ),
      },
      'lines': s.lines
          .map(
            (line) => {
              'entry_date': line.entryDate.toIso8601String().split('T').first,
              'entry_number': line.entryNumber,
              'source': line.source,
              'description': line.description,
              'debit': decimalTransferString(
                line.debit,
                decimalPlaces: decimalPlaces,
              ),
              'credit': decimalTransferString(
                line.credit,
                decimalPlaces: decimalPlaces,
              ),
              'running_balance': decimalTransferString(
                line.runningBalance,
                decimalPlaces: decimalPlaces,
              ),
            },
          )
          .toList(),
      'row_count': s.rowCount,
      'notes': s.notes,
    },
    AssetLabelPayload a => {
      'kind': a.kind.documentType,
      'unit': a.unit,
      'product': a.product,
      'tenant': a.tenant,
    },
    InvoicePayload i => {
      'kind': i.kind.documentType,
      'document': _serializeMap(i.document, decimalPlaces: decimalPlaces),
      'party': i.party,
      'lines': i.lines
          .map((line) => _serializeMap(line, decimalPlaces: decimalPlaces))
          .toList(),
      'totals': _serializeMoneyMap(i.totals, decimalPlaces: decimalPlaces),
    },
    VoucherPayload v => {
      'kind': v.kind.documentType,
      'document': _serializeMap(v.document, decimalPlaces: decimalPlaces),
      'party': v.party,
      'payment': _serializeMoneyMap(v.payment, decimalPlaces: decimalPlaces),
    },
  };
}

Map<String, dynamic> _serializeMap(
  Map<String, dynamic> map, {
  required int decimalPlaces,
}) {
  final out = <String, dynamic>{};
  for (final entry in map.entries) {
    out[entry.key] = _serializeValue(entry.value, decimalPlaces: decimalPlaces);
  }
  return out;
}

Map<String, dynamic> _serializeMoneyMap(
  Map<String, dynamic> map, {
  required int decimalPlaces,
}) {
  final out = <String, dynamic>{};
  for (final entry in map.entries) {
    final value = entry.value;
    if (value is Decimal) {
      out[entry.key] = decimalTransferString(
        value,
        decimalPlaces: decimalPlaces,
      );
    } else {
      out[entry.key] = _serializeValue(value, decimalPlaces: decimalPlaces);
    }
  }
  return out;
}

dynamic _serializeValue(dynamic value, {required int decimalPlaces}) {
  if (value is Decimal) {
    return decimalTransferString(value, decimalPlaces: decimalPlaces);
  }
  if (value is DateTime) return value.toIso8601String();
  return value;
}

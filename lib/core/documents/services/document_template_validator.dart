import '../domain/document_kind.dart';

import '../domain/document_template.dart';

import 'document_template_json_parser.dart';

/// Mirrors SQL [validate_document_template_body] for client-side tests.

class DocumentTemplateValidator {
  const DocumentTemplateValidator({DocumentTemplateJsonParser? parser})
    : _parser = parser ?? const DocumentTemplateJsonParser();

  final DocumentTemplateJsonParser _parser;

  void validate({
    required DocumentKind documentType,

    required TemplateBody body,

    PaperKind paperKind = PaperKind.a4,

    int schemaVersion = 1,
  }) {
    _parser.validateRaw(
      documentType: documentType,

      raw: {
        'schema_version': body.schemaVersion,

        'settings': body.settings,

        'blocks': body.blocks.map(_blockToJson).toList(),
      },

      paperKind: paperKind,

      schemaVersion: schemaVersion,
    );
  }

  Map<String, dynamic> _blockToJson(TemplateBlock block) {
    final json = <String, dynamic>{'type': block.type, 'id': block.id};

    if (block.fields.isNotEmpty) {
      json['fields'] = block.fields;
    }

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
}

class DocumentTemplateValidationException implements Exception {
  const DocumentTemplateValidationException(this.message);

  final String message;

  @override
  String toString() => message;
}

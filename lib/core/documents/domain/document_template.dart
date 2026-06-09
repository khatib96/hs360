import 'document_kind.dart';
import '../services/document_template_json_parser.dart';

/// Parsed document template row from [get_effective_document_template].
class DocumentTemplate {
  const DocumentTemplate({
    required this.id,
    required this.templateKey,
    required this.documentType,
    required this.languageMode,
    required this.paperKind,
    required this.schemaVersion,
    required this.body,
    required this.nameAr,
    required this.nameEn,
  });

  final String id;
  final String templateKey;
  final DocumentKind documentType;
  final DocumentLanguageMode languageMode;
  final PaperKind paperKind;
  final int schemaVersion;
  final TemplateBody body;
  final String nameAr;
  final String nameEn;

  factory DocumentTemplate.fromRpc(Map<String, dynamic> json) {
    final kind = DocumentKind.fromDocumentType(
      json['document_type'] as String?,
    );
    final paper = PaperKind.fromValue(json['paper_kind'] as String?);
    if (kind == null || paper == null) {
      throw FormatException('Invalid document template metadata');
    }
    final schemaVersion = json['schema_version'] as int? ?? 1;
    final bodyJson = Map<String, dynamic>.from(json['body_json'] as Map);
    final body = const DocumentTemplateJsonParser().parse(
      documentType: kind,
      raw: bodyJson,
      paperKind: paper,
      schemaVersion: schemaVersion,
    );

    return DocumentTemplate(
      id: json['id'] as String,
      templateKey: json['template_key'] as String,
      documentType: kind,
      languageMode: DocumentLanguageMode.fromValue(
        json['language_mode'] as String?,
      ),
      paperKind: paper,
      schemaVersion: schemaVersion,
      body: body,
      nameAr: json['name_ar'] as String? ?? '',
      nameEn: json['name_en'] as String? ?? '',
    );
  }
}

class TemplateBody {
  const TemplateBody({
    required this.schemaVersion,
    required this.settings,
    required this.blocks,
  });

  final int schemaVersion;
  final Map<String, dynamic> settings;
  final List<TemplateBlock> blocks;

  factory TemplateBody.fromJson(Map<String, dynamic> json) {
    final blocksRaw = json['blocks'];
    if (blocksRaw is! List) {
      throw FormatException('Template body blocks must be a list');
    }
    return TemplateBody(
      schemaVersion: json['schema_version'] as int? ?? 1,
      settings: Map<String, dynamic>.from(json['settings'] as Map? ?? const {}),
      blocks: blocksRaw
          .map(
            (b) => TemplateBlock.fromJson(Map<String, dynamic>.from(b as Map)),
          )
          .toList(),
    );
  }
}

class TemplateBlock {
  const TemplateBlock({
    required this.type,
    this.id,
    this.fields = const [],
    this.columns = const [],
    this.partyRole,
    this.source,
    this.payloadField,
    this.captionField,
    this.heightMm,
  });

  final String type;
  final String? id;
  final List<String> fields;
  final List<TemplateColumn> columns;
  final String? partyRole;
  final String? source;
  final String? payloadField;
  final String? captionField;
  final double? heightMm;

  factory TemplateBlock.fromJson(Map<String, dynamic> json) {
    final fieldsRaw = json['fields'];
    final columnsRaw = json['columns'];
    final heightRaw = json['height_mm'];
    return TemplateBlock(
      type: json['type'] as String,
      id: json['id'] as String?,
      fields: fieldsRaw is List
          ? fieldsRaw.map((e) => e.toString()).toList()
          : const [],
      columns: columnsRaw is List
          ? columnsRaw
                .map(
                  (c) => TemplateColumn.fromJson(
                    Map<String, dynamic>.from(c as Map),
                  ),
                )
                .toList()
          : const [],
      partyRole: json['party_role'] as String?,
      source: json['source'] as String?,
      payloadField: json['payload_field'] as String?,
      captionField: json['caption_field'] as String?,
      heightMm: heightRaw is num ? heightRaw.toDouble() : null,
    );
  }
}

class TemplateColumn {
  const TemplateColumn({
    required this.field,
    required this.labelKey,
    required this.labelAr,
    required this.labelEn,
    required this.widthPct,
    required this.align,
  });

  final String field;
  final String labelKey;
  final String labelAr;
  final String labelEn;
  final int widthPct;
  final String align;

  factory TemplateColumn.fromJson(Map<String, dynamic> json) {
    return TemplateColumn(
      field: json['field'] as String,
      labelKey: json['label_key'] as String? ?? '',
      labelAr: json['label_ar'] as String? ?? '',
      labelEn: json['label_en'] as String? ?? '',
      widthPct: json['width_pct'] as int? ?? 0,
      align: json['align'] as String? ?? 'start',
    );
  }
}

/// Full effective template RPC response envelope.
class EffectiveDocumentContext {
  const EffectiveDocumentContext({
    required this.template,
    required this.settings,
    required this.currency,
    required this.resolvedLogoUrl,
    required this.companyNames,
  });

  final DocumentTemplate template;
  final Map<String, dynamic> settings;
  final Map<String, dynamic>? currency;
  final String? resolvedLogoUrl;
  final Map<String, String> companyNames;

  factory EffectiveDocumentContext.fromRpc(Map<String, dynamic> json) {
    final companyRaw = json['company_names'];
    final company = companyRaw is Map
        ? {
            'ar': companyRaw['ar']?.toString() ?? '',
            'en': companyRaw['en']?.toString() ?? '',
          }
        : {'ar': '', 'en': ''};

    return EffectiveDocumentContext(
      template: DocumentTemplate.fromRpc(
        Map<String, dynamic>.from(json['template'] as Map),
      ),
      settings: Map<String, dynamic>.from(json['settings'] as Map? ?? const {}),
      currency: json['currency'] is Map
          ? Map<String, dynamic>.from(json['currency'] as Map)
          : null,
      resolvedLogoUrl: json['resolved_logo_url'] as String?,
      companyNames: company,
    );
  }
}

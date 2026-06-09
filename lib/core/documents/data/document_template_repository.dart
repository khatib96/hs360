import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../errors/document_exception.dart';
import '../../network/supabase_providers.dart';
import '../domain/document_kind.dart';
import '../domain/document_payload.dart';
import '../domain/document_template.dart';
import '../domain/tenant_document_settings.dart';

part 'document_template_repository.g.dart';

@Riverpod(keepAlive: true)
DocumentTemplateRepository documentTemplateRepository(Ref ref) {
  final client = ref.watch(supabaseClientProvider);
  return DocumentTemplateRepository(client);
}

class DocumentTemplateRepository {
  DocumentTemplateRepository(this._client);

  final SupabaseClient? _client;

  SupabaseClient get _requireClient {
    final client = _client;
    if (client == null) throw DocumentException.notConfigured();
    return client;
  }

  Future<EffectiveDocumentContext> fetchEffectiveTemplate({
    required DocumentKind documentType,
    PaperKind? paperKind,
  }) async {
    try {
      final result = await _requireClient.rpc(
        'get_effective_document_template',
        params: {
          'p_document_type': documentType.documentType,
          'p_paper_kind': paperKind?.value,
        },
      );
      return EffectiveDocumentContext.fromRpc(
        Map<String, dynamic>.from(result as Map),
      );
    } catch (e, st) {
      Error.throwWithStackTrace(DocumentException.fromSupabase(e), st);
    }
  }

  Future<TenantDocumentSettings> fetchTenantDocumentSettings() async {
    try {
      final result = await _requireClient.rpc('get_tenant_document_settings');
      return TenantDocumentSettings.fromRpc(
        Map<String, dynamic>.from(result as Map),
      );
    } catch (e, st) {
      Error.throwWithStackTrace(DocumentException.fromSupabase(e), st);
    }
  }

  Future<TenantDocumentSettings> upsertTenantDocumentSettings(
    Map<String, dynamic> patch,
  ) async {
    try {
      final result = await _requireClient.rpc(
        'upsert_tenant_document_settings',
        params: {'p_patch': patch},
      );
      return TenantDocumentSettings.fromRpc(
        Map<String, dynamic>.from(result as Map),
      );
    } catch (e, st) {
      Error.throwWithStackTrace(DocumentException.fromSupabase(e), st);
    }
  }

  Future<StatementPayload> fetchCustomerStatementPayload({
    required String customerId,
    required DateTime from,
    required DateTime to,
  }) async {
    try {
      final result = await _requireClient.rpc(
        'get_customer_statement_document_payload',
        params: {
          'p_customer_id': customerId,
          'p_from': _dateOnly(from),
          'p_to': _dateOnly(to),
        },
      );
      return StatementPayload.fromRpc(Map<String, dynamic>.from(result as Map));
    } catch (e, st) {
      Error.throwWithStackTrace(DocumentException.fromSupabase(e), st);
    }
  }

  Future<AssetLabelPayload> fetchProductUnitLabelPayload({
    required String unitId,
  }) async {
    try {
      final result = await _requireClient.rpc(
        'get_product_unit_label_payload',
        params: {'p_unit_id': unitId},
      );
      return AssetLabelPayload.fromRpc(
        Map<String, dynamic>.from(result as Map),
      );
    } catch (e, st) {
      Error.throwWithStackTrace(DocumentException.fromSupabase(e), st);
    }
  }

  static String _dateOnly(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}

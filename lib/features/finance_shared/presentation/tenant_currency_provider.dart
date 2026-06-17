import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/documents/data/document_template_repository.dart';
import '../../../core/documents/domain/document_kind.dart';
import '../../../core/documents/domain/tenant_currency_format.dart';

part 'tenant_currency_provider.g.dart';

/// Cached tenant currency format reused by all finance amount widgets.
@Riverpod(keepAlive: true)
Future<TenantCurrencyFormat> tenantCurrencyFormat(Ref ref) async {
  try {
    final context = await ref
        .read(documentTemplateRepositoryProvider)
        .fetchEffectiveTemplate(documentType: DocumentKind.salesInvoice);
    return TenantCurrencyFormat.fromRpc(context.currency);
  } catch (_) {
    return TenantCurrencyFormat.defaults();
  }
}

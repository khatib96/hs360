import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/documents/domain/document_payload.dart';
import '../../../core/errors/document_exception.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/contract_repository.dart';
import '../domain/contract_document_payload_mapper.dart';

/// Bridge from document preview to contract detail repository.
Future<DocumentPayload> loadContractDocumentPayload({
  required Ref ref,
  required String entityId,
}) async {
  final session = ref.read(authControllerProvider).valueOrNull;
  if (session == null) {
    throw const DocumentException(code: DocumentException.permissionDenied);
  }
  final detail = await ref
      .read(contractRepositoryProvider)
      .fetchContractDetail(session, entityId);
  return mapContractDetailToCustomerPayload(detail);
}

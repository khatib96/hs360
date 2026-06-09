import 'package:hs360/core/documents/domain/document_kind.dart';
import 'package:hs360/core/documents/domain/document_payload.dart';
import 'package:hs360/core/documents/domain/document_render_result.dart';

/// Arguments for navigating to document preview.
class DocumentPreviewArgs {
  const DocumentPreviewArgs({
    required this.kind,
    required this.entityId,
    this.fromDate,
    this.toDate,
    this.fixturePayload,
  });

  final DocumentKind kind;
  final String entityId;
  final DateTime? fromDate;
  final DateTime? toDate;
  final DocumentPayload? fixturePayload;

  @override
  bool operator ==(Object other) {
    return other is DocumentPreviewArgs &&
        other.kind == kind &&
        other.entityId == entityId &&
        other.fromDate == fromDate &&
        other.toDate == toDate &&
        other.fixturePayload == fixturePayload;
  }

  @override
  int get hashCode =>
      Object.hash(kind, entityId, fromDate, toDate, fixturePayload);
}

class DocumentPreviewState {
  const DocumentPreviewState({
    this.isLoading = false,
    this.permissionDenied = false,
    this.errorCode,
    this.renderResult,
    this.canExport = false,
  });

  final bool isLoading;
  final bool permissionDenied;
  final String? errorCode;
  final DocumentRenderResult? renderResult;
  final bool canExport;

  DocumentPreviewState copyWith({
    bool? isLoading,
    bool? permissionDenied,
    String? errorCode,
    bool clearError = false,
    DocumentRenderResult? renderResult,
    bool? canExport,
  }) {
    return DocumentPreviewState(
      isLoading: isLoading ?? this.isLoading,
      permissionDenied: permissionDenied ?? this.permissionDenied,
      errorCode: clearError ? null : (errorCode ?? this.errorCode),
      renderResult: renderResult ?? this.renderResult,
      canExport: canExport ?? this.canExport,
    );
  }
}

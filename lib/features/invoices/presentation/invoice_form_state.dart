import 'package:decimal/decimal.dart';

import '../domain/invoice_draft.dart';
import '../domain/invoice_form_state.dart' as domain;
import '../domain/invoice_type.dart';
import '../domain/return_invoice_draft.dart';

class InvoiceFormUiState {
  const InvoiceFormUiState({
    required this.invoiceType,
    this.invoiceId,
    this.form,
    this.returnDraft,
    this.isSubmitting = false,
    this.isSavingDraft = false,
    this.errorCode,
    this.validationCodes = const [],
    this.lastSavedInvoiceId,
    this.serializedByProductId = const {},
    this.returnableQtyByLineId = const {},
    this.serializedReturnLineIds = const {},
  });

  final InvoiceType invoiceType;
  final String? invoiceId;
  final domain.InvoiceFormState? form;
  final ReturnInvoiceDraft? returnDraft;
  final bool isSubmitting;
  final bool isSavingDraft;
  final String? errorCode;
  final List<String> validationCodes;
  final String? lastSavedInvoiceId;
  final Map<String, bool> serializedByProductId;
  final Map<String, Decimal> returnableQtyByLineId;
  final Set<String> serializedReturnLineIds;

  InvoiceFormUiState copyWith({
    InvoiceType? invoiceType,
    String? invoiceId,
    domain.InvoiceFormState? form,
    ReturnInvoiceDraft? returnDraft,
    bool? isSubmitting,
    bool? isSavingDraft,
    String? errorCode,
    List<String>? validationCodes,
    String? lastSavedInvoiceId,
    Map<String, bool>? serializedByProductId,
    Map<String, Decimal>? returnableQtyByLineId,
    Set<String>? serializedReturnLineIds,
    bool clearError = false,
    bool clearValidation = false,
  }) {
    return InvoiceFormUiState(
      invoiceType: invoiceType ?? this.invoiceType,
      invoiceId: invoiceId ?? this.invoiceId,
      form: form ?? this.form,
      returnDraft: returnDraft ?? this.returnDraft,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      isSavingDraft: isSavingDraft ?? this.isSavingDraft,
      errorCode: clearError ? null : (errorCode ?? this.errorCode),
      validationCodes: clearValidation
          ? const []
          : (validationCodes ?? this.validationCodes),
      lastSavedInvoiceId: lastSavedInvoiceId ?? this.lastSavedInvoiceId,
      serializedByProductId:
          serializedByProductId ?? this.serializedByProductId,
      returnableQtyByLineId:
          returnableQtyByLineId ?? this.returnableQtyByLineId,
      serializedReturnLineIds:
          serializedReturnLineIds ?? this.serializedReturnLineIds,
    );
  }

  static domain.InvoiceFormState emptyForm(InvoiceType type) {
    return domain.InvoiceFormState(
      draft: InvoiceDraft(
        type: type,
        warehouseId: '',
        date: DateTime.now(),
        lines: const [],
      ),
    );
  }
}

import 'package:decimal/decimal.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/errors/finance_exception.dart';
import '../../../domain/validators/purchase_invoice_validator.dart';
import '../../../domain/validators/return_invoice_validator.dart';
import '../../../domain/validators/sales_invoice_validator.dart';
import '../../../domain/validators/validation_result.dart';
import '../../auth/domain/app_session.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../finance_shared/domain/finance_idempotency.dart';
import '../data/invoice_repository.dart';
import '../domain/invoice_form_state.dart' as domain;
import '../domain/invoice_permissions.dart';
import '../domain/invoice_type.dart';
import '../domain/return_invoice_draft.dart';
import 'invoice_form_state.dart';

part 'invoice_form_controller.g.dart';

@riverpod
class InvoiceFormController extends _$InvoiceFormController {
  FinanceIdempotencySession? _idempotency;

  @override
  InvoiceFormUiState build(InvoiceType invoiceType) {
    return InvoiceFormUiState(
      invoiceType: invoiceType,
      form: invoiceType.isReturn
          ? null
          : InvoiceFormUiState.emptyForm(invoiceType),
      returnDraft: invoiceType.isReturn ? _emptyReturnDraft() : null,
    );
  }

  void updateForm(domain.InvoiceFormState form) {
    state = state.copyWith(form: form, clearError: true, clearValidation: true);
  }

  void updateReturnDraft(ReturnInvoiceDraft draft) {
    state = state.copyWith(
      returnDraft: draft,
      clearError: true,
      clearValidation: true,
    );
  }

  void setSerializedByProductId(Map<String, bool> value) {
    state = state.copyWith(serializedByProductId: value);
  }

  void setReturnContext({
    Map<String, Decimal>? returnableQtyByLineId,
    Set<String>? serializedReturnLineIds,
  }) {
    state = state.copyWith(
      returnableQtyByLineId: returnableQtyByLineId,
      serializedReturnLineIds: serializedReturnLineIds,
    );
  }

  Future<String?> saveDraft() async {
    final session = ref.read(authControllerProvider).valueOrNull;
    final form = state.form;
    if (session == null || form == null) return FinanceException.unknown;
    if (!canEditInvoiceDraft(session)) {
      return FinanceException.permissionDenied;
    }
    if (form.draft.type != InvoiceType.purchase) {
      return FinanceException.notAvailable;
    }

    final validation = const PurchaseInvoiceValidator().validate(
      form,
      serializedByProductId: state.serializedByProductId,
    );
    if (!validation.isValid) {
      state = state.copyWith(validationCodes: validation.codes);
      return validation.codes.first;
    }

    state = state.copyWith(
      isSavingDraft: true,
      clearError: true,
      clearValidation: true,
    );
    try {
      final id = await ref
          .read(invoiceRepositoryProvider)
          .saveInvoiceDraft(session, form);
      state = state.copyWith(
        isSavingDraft: false,
        invoiceId: id,
        lastSavedInvoiceId: id,
      );
      return null;
    } on FinanceException catch (e) {
      state = state.copyWith(isSavingDraft: false, errorCode: e.code);
      return e.code;
    } catch (_) {
      state = state.copyWith(
        isSavingDraft: false,
        errorCode: FinanceException.unknown,
      );
      return FinanceException.unknown;
    }
  }

  Future<String?> submit() async {
    final session = ref.read(authControllerProvider).valueOrNull;
    if (session == null) return FinanceException.unknown;

    if (state.invoiceType.isReturn) {
      return _submitReturn(session);
    }
    return _submitInvoice(session);
  }

  Future<String?> _submitInvoice(AppSession session) async {
    final form = state.form;
    if (form == null) return FinanceException.unknown;

    final ValidationResult validation = switch (form.draft.type) {
      InvoiceType.sales => const SalesInvoiceValidator().validate(
        form,
        serializedByProductId: state.serializedByProductId,
      ),
      InvoiceType.purchase => const PurchaseInvoiceValidator().validate(
        form,
        serializedByProductId: state.serializedByProductId,
      ),
      _ => const ValidationResult(codes: [FinanceException.notAvailable]),
    };
    if (!validation.isValid) {
      state = state.copyWith(validationCodes: validation.codes);
      return validation.codes.first;
    }

    if (!_canCreate(session, form.draft.type)) {
      return FinanceException.permissionDenied;
    }

    _idempotency ??= FinanceIdempotencySession();
    state = state.copyWith(
      isSubmitting: true,
      clearError: true,
      clearValidation: true,
    );

    try {
      final repo = ref.read(invoiceRepositoryProvider);
      final id = switch (form.draft.type) {
        InvoiceType.sales => await repo.recordSalesInvoice(
          session,
          form,
          _idempotency!.key,
        ),
        InvoiceType.purchase => await repo.recordPurchaseInvoice(
          session,
          form,
          _idempotency!.key,
        ),
        _ => throw StateError('Unsupported invoice type'),
      };
      _idempotency!.clear();
      state = state.copyWith(
        isSubmitting: false,
        invoiceId: id,
        lastSavedInvoiceId: id,
      );
      return null;
    } on FinanceException catch (e) {
      if (_idempotency != null && !_idempotency!.shouldPreserveKeyOn(e)) {
        _idempotency!.clear();
      }
      state = state.copyWith(isSubmitting: false, errorCode: e.code);
      return e.code;
    } catch (_) {
      _idempotency?.clear();
      state = state.copyWith(
        isSubmitting: false,
        errorCode: FinanceException.unknown,
      );
      return FinanceException.unknown;
    }
  }

  Future<String?> _submitReturn(AppSession session) async {
    final draft = state.returnDraft;
    if (draft == null) return FinanceException.unknown;

    final validation = const ReturnInvoiceValidator().validate(
      draft,
      returnableQtyByLineId: state.returnableQtyByLineId,
      serializedLineIds: state.serializedReturnLineIds,
    );
    if (!validation.isValid) {
      state = state.copyWith(validationCodes: validation.codes);
      return validation.codes.first;
    }

    if (!_canCreateReturn(session, state.invoiceType)) {
      return FinanceException.permissionDenied;
    }

    _idempotency ??= FinanceIdempotencySession();
    state = state.copyWith(
      isSubmitting: true,
      clearError: true,
      clearValidation: true,
    );

    try {
      final repo = ref.read(invoiceRepositoryProvider);
      final id = switch (state.invoiceType) {
        InvoiceType.salesReturn => await repo.recordSalesReturn(
          session,
          draft,
          _idempotency!.key,
        ),
        InvoiceType.purchaseReturn => await repo.recordPurchaseReturn(
          session,
          draft,
          _idempotency!.key,
        ),
        _ => throw StateError('Not a return invoice type'),
      };
      _idempotency!.clear();
      state = state.copyWith(
        isSubmitting: false,
        invoiceId: id,
        lastSavedInvoiceId: id,
      );
      return null;
    } on FinanceException catch (e) {
      if (_idempotency != null && !_idempotency!.shouldPreserveKeyOn(e)) {
        _idempotency!.clear();
      }
      state = state.copyWith(isSubmitting: false, errorCode: e.code);
      return e.code;
    } catch (_) {
      _idempotency?.clear();
      state = state.copyWith(
        isSubmitting: false,
        errorCode: FinanceException.unknown,
      );
      return FinanceException.unknown;
    }
  }

  bool _canCreate(AppSession session, InvoiceType type) {
    return switch (type) {
      InvoiceType.sales => canCreateSalesInvoice(session),
      InvoiceType.purchase => canCreatePurchaseInvoice(session),
      _ => false,
    };
  }

  bool _canCreateReturn(AppSession session, InvoiceType type) {
    return switch (type) {
      InvoiceType.salesReturn => canCreateSalesReturn(session),
      InvoiceType.purchaseReturn => canCreatePurchaseReturn(session),
      _ => false,
    };
  }

  ReturnInvoiceDraft _emptyReturnDraft() {
    return ReturnInvoiceDraft(
      originalInvoiceId: '',
      warehouseId: '',
      date: DateTime.now(),
      reason: '',
      lines: const [],
    );
  }
}

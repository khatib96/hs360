import '../../../core/errors/finance_exception.dart';
import '../../auth/domain/app_session.dart';
import '../../customers/data/customer_repository.dart';
import '../../customers/domain/customer.dart';
import '../../customers/domain/customer_filters.dart';
import '../../suppliers/data/supplier_repository.dart';
import '../../suppliers/domain/supplier.dart';
import '../../suppliers/domain/supplier_filters.dart';
import '../data/voucher_repository.dart';
import '../data/voucher_rpc_mapper.dart';
import '../domain/voucher_type.dart';
import 'voucher_form_state.dart' as ui;

Future<List<Object>> searchVoucherParties({
  required AppSession session,
  required VoucherType voucherType,
  required String query,
  required CustomerRepository customerRepository,
  required SupplierRepository supplierRepository,
}) async {
  final trimmed = query.trim();
  if (trimmed.isEmpty) return const [];

  if (voucherType == VoucherType.receipt) {
    return customerRepository.fetchCustomers(
      session,
      CustomerFilters(search: trimmed, isActive: true),
      limit: 20,
    );
  }

  return supplierRepository.fetchSuppliers(
    session,
    SupplierFilters(search: trimmed, isActive: true),
    limit: 20,
  );
}

Future<List<OpenInvoiceAllocationOption>> loadVoucherOpenInvoices({
  required AppSession session,
  required ui.VoucherFormUiState state,
  required VoucherRepository repository,
}) async {
  final customerId = state.selectedCustomer?.id;
  final supplierId = state.selectedSupplier?.id;
  final isReceipt = state.voucherType == VoucherType.receipt;
  final isSupplierPayment =
      state.voucherType == VoucherType.payment &&
      (state.form.paymentDestination ?? 'supplier') == 'supplier';

  if (isReceipt && customerId != null) {
    return repository.listOpenCustomerInvoices(session, customerId);
  }
  if (isSupplierPayment && supplierId != null) {
    return repository.listOpenSupplierInvoices(session, supplierId);
  }
  return const [];
}

ui.VoucherFormUiState applyCustomerSelection(
  ui.VoucherFormUiState state,
  Customer customer,
) {
  return state.copyWith(
    selectedCustomer: customer,
    partySearchResults: const [],
    form: state.form.copyWith(customerId: customer.id),
    clearOpenInvoices: true,
    clearManualAllocations: true,
    clearError: true,
    clearValidation: true,
  );
}

ui.VoucherFormUiState applySupplierSelection(
  ui.VoucherFormUiState state,
  Supplier supplier,
) {
  return state.copyWith(
    selectedSupplier: supplier,
    partySearchResults: const [],
    form: state.form.copyWith(supplierId: supplier.id),
    clearOpenInvoices: true,
    clearManualAllocations: true,
    clearError: true,
    clearValidation: true,
  );
}

String? openInvoiceLoadErrorCode(Object error) {
  if (error is FinanceException) return error.code;
  return FinanceException.unknown;
}

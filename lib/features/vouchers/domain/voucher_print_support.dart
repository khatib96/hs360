import '../../../core/documents/domain/document_kind.dart';
import 'voucher_detail.dart';
import 'voucher_status.dart';
import 'voucher_type.dart';

bool isVoucherPrintable(VoucherDetail detail) {
  return detail.status == VoucherStatus.confirmed &&
      detail.type == VoucherType.receipt;
}

DocumentKind documentKindForVoucher(VoucherDetail detail) {
  return DocumentKind.receiptVoucher;
}

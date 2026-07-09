import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/features/vouchers/domain/voucher_print_support.dart';
import 'package:hs360/features/vouchers/domain/voucher_status.dart';
import 'package:hs360/features/vouchers/domain/voucher_type.dart';

import '../fake_voucher_repository.dart';

void main() {
  test('isVoucherPrintable allows confirmed receipt only', () {
    expect(isVoucherPrintable(sampleVoucherDetail()), isTrue);
    expect(
      isVoucherPrintable(sampleVoucherDetail(status: VoucherStatus.cancelled)),
      isFalse,
    );
    expect(
      isVoucherPrintable(sampleVoucherDetail(type: VoucherType.payment)),
      isFalse,
    );
  });
}

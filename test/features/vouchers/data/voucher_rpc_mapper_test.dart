import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/features/finance_shared/domain/payment_method.dart';
import 'package:hs360/features/vouchers/data/voucher_rpc_mapper.dart';
import 'package:hs360/features/vouchers/domain/voucher_form_state.dart';
import 'package:hs360/features/vouchers/domain/voucher_type.dart';

void main() {
  group('returnRefundVoucherParams', () {
    test('uses p_return_invoice_id for single return refund', () {
      final params = returnRefundVoucherParams(
        rpcReturnInvoiceId: 'ret-1',
        form: _form(),
        idempotencyKey: 'idem-1',
      );

      expect(params['p_return_invoice_id'], 'ret-1');
      expect(params['p_idempotency_key'], 'idem-1');
      expect(params['p_data'], {
        'date': '2026-06-17',
        'amount': '12.5',
        'payment_method': 'cash',
        'cash_account_id': 'cash-1',
      });
    });

    test(
      'maps allocations with return_invoice_id when no single id is passed',
      () {
        final params = returnRefundVoucherParams(
          rpcReturnInvoiceId: ' ',
          form: _form(
            allocations: [
              VoucherAllocationInput(
                invoiceId: 'ret-1',
                allocatedAmount: Decimal.parse('7.500'),
              ),
              VoucherAllocationInput(
                invoiceId: 'ret-2',
                allocatedAmount: Decimal.parse('5.000'),
              ),
            ],
          ),
          idempotencyKey: 'idem-2',
        );

        expect(params['p_return_invoice_id'], isNull);
        expect((params['p_data'] as Map<String, dynamic>)['allocations'], [
          {'return_invoice_id': 'ret-1', 'allocated_amount': '7.5'},
          {'return_invoice_id': 'ret-2', 'allocated_amount': '5'},
        ]);
      },
    );
  });
}

VoucherFormState _form({List<VoucherAllocationInput> allocations = const []}) {
  return VoucherFormState(
    type: VoucherType.payment,
    date: DateTime(2026, 6, 17),
    amount: Decimal.parse('12.500'),
    paymentMethod: PaymentMethod.cash,
    cashAccountId: 'cash-1',
    allocations: allocations,
  );
}

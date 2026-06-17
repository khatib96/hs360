import 'package:decimal/decimal.dart';

import '../../finance_shared/domain/party_reference.dart';
import '../../finance_shared/domain/payment_method.dart';
import 'voucher_allocation.dart';
import 'voucher_status.dart';
import 'voucher_type.dart';

class VoucherDetail {
  const VoucherDetail({
    required this.id,
    this.voucherNumber,
    required this.type,
    required this.status,
    required this.date,
    required this.amount,
    required this.paymentMethod,
    this.referenceNo,
    this.notes,
    this.collectedBy,
    this.customer,
    this.supplier,
    required this.account,
    required this.cashAccount,
    this.journalEntryId,
    this.reversalJournalEntryId,
    this.confirmedAt,
    this.confirmedBy,
    this.cancelledAt,
    this.cancelledBy,
    this.cancellationReason,
    required this.allocations,
    required this.allocatedAmount,
    required this.unallocatedAmount,
  });

  final String id;
  final String? voucherNumber;
  final VoucherType type;
  final VoucherStatus status;
  final DateTime date;
  final Decimal amount;
  final PaymentMethod paymentMethod;
  final String? referenceNo;
  final String? notes;
  final String? collectedBy;
  final PartyReference? customer;
  final PartyReference? supplier;
  final VoucherAccountRef account;
  final VoucherAccountRef cashAccount;
  final String? journalEntryId;
  final String? reversalJournalEntryId;
  final DateTime? confirmedAt;
  final String? confirmedBy;
  final DateTime? cancelledAt;
  final String? cancelledBy;
  final String? cancellationReason;
  final List<VoucherAllocation> allocations;
  final Decimal allocatedAmount;
  final Decimal unallocatedAmount;
}

enum JournalSource {
  manual('manual'),
  salesInvoice('sales_invoice'),
  purchaseInvoice('purchase_invoice'),
  receiptVoucher('receipt_voucher'),
  paymentVoucher('payment_voucher'),
  rentalInvoice('rental_invoice'),
  contractCreation('contract_creation'),
  contractClosure('contract_closure'),
  openingBalance('opening_balance'),
  inventoryAdjustment('inventory_adjustment'),
  salaryPayment('salary_payment');

  const JournalSource(this.dbValue);

  final String dbValue;

  static JournalSource fromDb(String? value) {
    if (value == null) {
      throw FormatException('JournalSource value is null');
    }
    for (final source in JournalSource.values) {
      if (source.dbValue == value) return source;
    }
    throw FormatException('Unknown JournalSource: $value');
  }

  String toDb() => dbValue;
}

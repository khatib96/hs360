import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('finance l10n keys have Arabic parity', () {
    final enFile = File('lib/l10n/app_en.arb');
    final arFile = File('lib/l10n/app_ar.arb');
    final enKeys = _keysFromArb(enFile.readAsStringSync());
    final arKeys = _keysFromArb(arFile.readAsStringSync());

    const prefixes = [
      'finance',
      'navInvoices',
      'navVouchers',
      'navJournal',
      'navCashBank',
      'invoice',
      'voucher',
      'journal',
      'cashBank',
      'taxSettings',
      'inventoryDocument',
      'paymentMethod',
      'journalSourceSalesReturn',
      'journalSourcePurchaseReturn',
    ];

    final financeKeys = enKeys.where((key) {
      for (final prefix in prefixes) {
        if (key.startsWith(prefix)) return true;
      }
      return false;
    });

    final missing = financeKeys.where((key) => !arKeys.contains(key)).toList();
    expect(missing, isEmpty, reason: 'Missing AR keys: $missing');
  });
}

Set<String> _keysFromArb(String content) {
  final json = jsonDecode(content) as Map<String, dynamic>;
  return json.keys.where((key) => !key.startsWith('@')).toSet();
}

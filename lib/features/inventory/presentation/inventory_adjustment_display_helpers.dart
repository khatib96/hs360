import 'package:decimal/decimal.dart';

import '../../../core/utils/quantity_formatter.dart';

/// Signed quantity for adjustment preview (+5 / -5).
String formatSignedQuantityDelta(Decimal delta) {
  if (delta > Decimal.zero) {
    return '+${formatQuantity(delta)}';
  }
  return formatQuantity(delta);
}

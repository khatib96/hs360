import 'package:decimal/decimal.dart';
import 'package:intl/intl.dart';

/// Formats quantity for display without locale coupling in M2.
String formatQuantity(
  Decimal value, {
  int maxFractionDigits = 3,
}) {
  final formatter = NumberFormat('#,##0.###', 'en');
  formatter.maximumFractionDigits = maxFractionDigits;
  return formatter.format(value.toDouble());
}

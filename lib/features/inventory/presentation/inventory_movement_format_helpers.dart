import 'package:decimal/decimal.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../core/utils/money_formatter.dart';
import '../../../core/utils/quantity_formatter.dart';

const int movementNotesTableMaxLength = 80;

String formatMovementDateTime(DateTime occurredAt) {
  final local = occurredAt.toLocal();
  final y = local.year;
  final m = local.month.toString().padLeft(2, '0');
  final d = local.day.toString().padLeft(2, '0');
  final h = local.hour.toString().padLeft(2, '0');
  final min = local.minute.toString().padLeft(2, '0');
  return '$y-$m-$d $h:$min';
}

String formatMovementQuantity(Decimal qty) => formatQuantity(qty);

String formatMovementUnitCost(Decimal unitCost, String languageCode) =>
    formatMoney(unitCost, locale: languageCode);

String truncateMovementNotes(String? notes, {int maxLength = movementNotesTableMaxLength}) {
  final text = notes?.trim();
  if (text == null || text.isEmpty) return '';
  if (text.length <= maxLength) return text;
  return '${text.substring(0, maxLength)}…';
}

String movementNotesForTable(String? notes, AppLocalizations l10n) {
  final truncated = truncateMovementNotes(notes);
  if (truncated.isNotEmpty) return truncated;
  return l10n.inventoryMovementNotesNone;
}

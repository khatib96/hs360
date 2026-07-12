import 'contract_detail.dart';

/// Display-only month eligibility for rental collection (no financial logic).
class ContractRentalCollectionMonths {
  const ContractRentalCollectionMonths._();

  static DateTime monthStart(DateTime date) =>
      DateTime(date.year, date.month, 1);

  static String monthKey(DateTime monthStart) {
    final y = monthStart.year.toString().padLeft(4, '0');
    final m = monthStart.month.toString().padLeft(2, '0');
    return '$y-$m-01';
  }

  static DateTime? effectiveCloseDate(ContractDetail detail) {
    if (!detail.status.isClosed) {
      return null;
    }
    final closed = detail.closedAt ?? detail.returnedAt ?? detail.endDate;
    return closed == null ? null : monthStart(closed);
  }

  /// Candidate month keys for tests.
  static List<String> buildCandidateMonthKeys({
    required ContractDetail detail,
    DateTime? now,
  }) {
    final today = now ?? DateTime.now();
    final covered = <String>{};
    return buildEligibleMonthKeys(
      detail: detail,
      coveredMonthKeys: covered,
      now: today,
    );
  }

  static List<String> buildEligibleMonthKeys({
    required ContractDetail detail,
    required Set<String> coveredMonthKeys,
    DateTime? now,
  }) {
    final today = now ?? DateTime.now();
    final start = monthStart(detail.startDate);
    final upper = _upperMonthBound(detail, today);
    if (upper != null && upper.isBefore(start)) {
      return const [];
    }

    final keys = <String>[];
    var cursor = start;
    final limit = upper ?? _openEndedUpperBound(start, today);
    while (!cursor.isAfter(limit)) {
      final key = monthKey(cursor);
      if (!coveredMonthKeys.contains(key)) {
        keys.add(key);
      }
      cursor = DateTime(cursor.year, cursor.month + 1, 1);
    }
    return keys;
  }

  static DateTime? _upperMonthBound(ContractDetail detail, DateTime today) {
    if (detail.status.isClosed) {
      return effectiveCloseDate(detail);
    }
    if (detail.endDate != null) {
      return monthStart(detail.endDate!);
    }
    return _openEndedUpperBound(monthStart(detail.startDate), today);
  }

  static DateTime _openEndedUpperBound(DateTime start, DateTime today) {
    final current = monthStart(today);
    final forward = DateTime(current.year, current.month + 12, 1);
    return forward.isBefore(start) ? start : forward;
  }

  static bool isMonthAllowed({
    required ContractDetail detail,
    required String monthKey,
    required Set<String> coveredMonthKeys,
    DateTime? now,
  }) {
    return buildEligibleMonthKeys(
      detail: detail,
      coveredMonthKeys: coveredMonthKeys,
      now: now,
    ).contains(monthKey);
  }
}

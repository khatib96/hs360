import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/features/calendar/domain/calendar_filters.dart';
import 'package:hs360/features/calendar/domain/calendar_route_scope.dart';

const _customerId = '11111111-1111-1111-1111-111111111111';
const _contractId = '22222222-2222-2222-2222-222222222222';

void main() {
  group('CalendarRouteScope.fromQueryParameters', () {
    test('empty query parameters yield the empty scope', () {
      final scope = CalendarRouteScope.fromQueryParameters(const {});
      expect(scope.isEmpty, isTrue);
      expect(scope.isInvalid, isFalse);
      expect(scope, CalendarRouteScope.empty);
    });

    test('parses a valid customerId', () {
      final scope = CalendarRouteScope.fromQueryParameters(const {
        'customerId': _customerId,
      });
      expect(scope.customerId, _customerId);
      expect(scope.hasCustomer, isTrue);
      expect(scope.hasContract, isFalse);
      expect(scope.isInvalid, isFalse);
      expect(scope.isEmpty, isFalse);
    });

    test('parses a valid contractId', () {
      final scope = CalendarRouteScope.fromQueryParameters(const {
        'contractId': _contractId,
      });
      expect(scope.contractId, _contractId);
      expect(scope.hasContract, isTrue);
      expect(scope.isInvalid, isFalse);
    });

    test('parses both customerId and contractId without proving a relationship', () {
      final scope = CalendarRouteScope.fromQueryParameters(const {
        'customerId': _customerId,
        'contractId': _contractId,
      });
      expect(scope.customerId, _customerId);
      expect(scope.contractId, _contractId);
      expect(scope.isInvalid, isFalse);
    });

    test('parses a valid yyyy-MM-dd date', () {
      final scope = CalendarRouteScope.fromQueryParameters(const {
        'date': '2026-07-14',
      });
      expect(scope.date, DateTime(2026, 7, 14));
      expect(scope.isInvalid, isFalse);
      expect(scope.hasEntityScope, isFalse);
      expect(scope.showsBanner, isFalse);
      expect(scope.blocksRepositoryReads, isFalse);
    });

    test('entity scope shows the banner; invalid blocks repository reads', () {
      final entity = CalendarRouteScope.fromQueryParameters(const {
        'customerId': _customerId,
      });
      expect(entity.hasEntityScope, isTrue);
      expect(entity.showsBanner, isTrue);
      expect(entity.blocksRepositoryReads, isFalse);

      final invalid = CalendarRouteScope.fromQueryParameters(const {
        'customerId': 'not-a-uuid',
      });
      expect(invalid.hasEntityScope, isFalse);
      expect(invalid.showsBanner, isTrue);
      expect(invalid.blocksRepositoryReads, isTrue);
    });

    test('rejects a malformed customerId UUID into the invalid state', () {
      final scope = CalendarRouteScope.fromQueryParameters(const {
        'customerId': 'not-a-uuid',
      });
      expect(scope.isInvalid, isTrue);
      expect(scope.customerId, isNull);
      expect(scope.contractId, isNull);
      expect(scope.date, isNull);
      expect(scope.isEmpty, isFalse);
    });

    test('rejects a malformed contractId UUID into the invalid state', () {
      final scope = CalendarRouteScope.fromQueryParameters(const {
        'contractId': '12345',
      });
      expect(scope.isInvalid, isTrue);
    });

    test('rejects a malformed date into the invalid state', () {
      final scope = CalendarRouteScope.fromQueryParameters(const {
        'date': 'not-a-date',
      });
      expect(scope.isInvalid, isTrue);
    });

    test('rejects an out-of-range calendar date into the invalid state', () {
      final scope = CalendarRouteScope.fromQueryParameters(const {
        'date': '2026-02-30',
      });
      expect(scope.isInvalid, isTrue);
    });

    test('a valid customerId alongside an invalid contractId rejects the whole scope', () {
      final scope = CalendarRouteScope.fromQueryParameters(const {
        'customerId': _customerId,
        'contractId': 'bad',
      });
      expect(scope.isInvalid, isTrue);
      expect(scope.customerId, isNull);
    });

    test('blank string values are treated as absent, not invalid', () {
      final scope = CalendarRouteScope.fromQueryParameters(const {
        'customerId': '',
        'contractId': '  ',
        'date': '',
      });
      expect(scope.isEmpty, isTrue);
      expect(scope.isInvalid, isFalse);
    });
  });

  group('equality and copyWith', () {
    test('equal scopes compare equal', () {
      final a = CalendarRouteScope.fromQueryParameters(const {
        'customerId': _customerId,
        'date': '2026-07-14',
      });
      final b = CalendarRouteScope.fromQueryParameters(const {
        'customerId': _customerId,
        'date': '2026-07-14',
      });
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('copyWith replaces individual fields', () {
      final base = CalendarRouteScope.fromQueryParameters(const {
        'customerId': _customerId,
      });
      final withContract = base.copyWith(contractId: _contractId);
      expect(withContract.customerId, _customerId);
      expect(withContract.contractId, _contractId);

      final cleared = withContract.copyWith(clearCustomerId: true);
      expect(cleared.customerId, isNull);
      expect(cleared.contractId, _contractId);
    });
  });

  group('toQueryParameters', () {
    test('round-trips through fromQueryParameters', () {
      final original = CalendarRouteScope.fromQueryParameters(const {
        'customerId': _customerId,
        'contractId': _contractId,
        'date': '2026-07-14',
      });
      final params = original.toQueryParameters();
      expect(params, {
        'customerId': _customerId,
        'contractId': _contractId,
        'date': '2026-07-14',
      });
      expect(CalendarRouteScope.fromQueryParameters(params), original);
    });

    test('empty scope produces no query parameters', () {
      expect(CalendarRouteScope.empty.toQueryParameters(), isEmpty);
    });

    test('invalid scope produces no query parameters (nothing untrusted kept)', () {
      final invalid = CalendarRouteScope.fromQueryParameters(const {
        'customerId': 'bad',
      });
      expect(invalid.toQueryParameters(), isEmpty);
    });
  });

  group('mergeIntoFilters', () {
    test('merges customerId/contractId into a filters copy', () {
      final scope = CalendarRouteScope.fromQueryParameters(const {
        'customerId': _customerId,
        'contractId': _contractId,
      });
      final merged = scope.mergeIntoFilters(CalendarFilters.empty);
      expect(merged.customerId, _customerId);
      expect(merged.contractId, _contractId);
    });

    test('leaves other filter fields untouched', () {
      final scope = CalendarRouteScope.fromQueryParameters(const {
        'customerId': _customerId,
      });
      final base = CalendarFilters(search: 'pump');
      final merged = scope.mergeIntoFilters(base);
      expect(merged.search, 'pump');
      expect(merged.customerId, _customerId);
    });

    test('returns filters unchanged when scope has no IDs', () {
      final scope = CalendarRouteScope.fromQueryParameters(const {
        'date': '2026-07-14',
      });
      const base = CalendarFilters.empty;
      expect(scope.mergeIntoFilters(base), base);
    });

    test('returns filters unchanged when scope is invalid', () {
      final scope = CalendarRouteScope.fromQueryParameters(const {
        'customerId': 'bad',
      });
      const base = CalendarFilters.empty;
      expect(scope.mergeIntoFilters(base), base);
    });

    test('never leaks scope IDs into the popover-facing filters object', () {
      final scope = CalendarRouteScope.fromQueryParameters(const {
        'customerId': _customerId,
        'contractId': _contractId,
      });
      const uiFilters = CalendarFilters.empty;
      final requestFilters = scope.mergeIntoFilters(uiFilters);
      // The UI-facing filters instance itself must stay untouched.
      expect(uiFilters.customerId, isNull);
      expect(uiFilters.contractId, isNull);
      expect(requestFilters.customerId, _customerId);
    });
  });
}

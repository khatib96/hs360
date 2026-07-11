import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/features/auth/domain/app_permissions.dart';
import 'package:hs360/features/auth/domain/app_session.dart';
import 'package:hs360/features/contracts/domain/contract_detail.dart';
import 'package:hs360/features/contracts/domain/contract_lifecycle_actions.dart';
import 'package:hs360/features/contracts/domain/contract_line.dart';
import 'package:hs360/features/contracts/domain/contract_status.dart';
import 'package:hs360/features/contracts/domain/contract_type.dart';

AppSession _session(Set<String> permissions) {
  return AppSession(
    userId: 'u',
    email: 'e@test.com',
    tenantId: 't',
    tenantUserId: 'tu',
    accountType: 'user',
    displayName: 'Test',
    preferredLocale: 'en',
    permissions: AppPermissions(isManager: false, permissions: permissions),
  );
}

ContractDetail _trialDetail({String? convertedTo}) {
  return ContractDetail(
    id: 'trial-1',
    type: ContractType.trial,
    status: ContractStatus.active,
    startDate: DateTime(2026, 1, 1),
    convertedToContractId: convertedTo,
    monthlyRentalValue: Decimal.one,
  );
}

ContractDetail _rentalDetail({
  ContractStatus status = ContractStatus.active,
  List<ContractConsumableLine> consumableLines = const [],
}) {
  return ContractDetail(
    id: 'rental-1',
    type: ContractType.rental,
    status: status,
    startDate: DateTime(2026, 1, 1),
    monthlyRentalValue: Decimal.one,
    consumableLines: consumableLines,
  );
}

void main() {
  group('contract_lifecycle_actions', () {
    test('convert action visible for active unconverted trial', () {
      final session = _session({'contracts.convert_trial'});
      expect(canShowConvertTrialAction(session, _trialDetail()), isTrue);
    });

    test('convert action hidden after conversion', () {
      final session = _session({'contracts.convert_trial'});
      expect(
        canShowConvertTrialAction(
          session,
          _trialDetail(convertedTo: 'rental-1'),
        ),
        isFalse,
      );
    });

    test('consumable schedule hidden when future change exists', () {
      final session = _session({'contracts.oil_change'});
      final detail = _rentalDetail(
        consumableLines: [
          ContractConsumableLine(
            id: 'line-1',
            productId: 'oil-1',
            scheduledEffectiveFrom: DateTime(2026, 8, 1),
          ),
        ],
      );
      expect(canShowScheduleConsumableChangeAction(session, detail), isFalse);
    });

    test('close rental visible for active rental', () {
      final session = _session({'contracts.close'});
      expect(canShowCloseRentalAction(session, _rentalDetail()), isTrue);
    });
  });
}

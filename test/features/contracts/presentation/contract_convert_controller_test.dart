import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/features/auth/domain/app_permissions.dart';
import 'package:hs360/features/auth/domain/app_session.dart';
import 'package:hs360/features/auth/presentation/auth_controller.dart';
import 'package:hs360/features/contracts/data/contract_repository.dart';
import 'package:hs360/features/contracts/presentation/contract_convert_controller.dart';
import 'package:hs360/features/contracts/presentation/contract_convert_draft_builder.dart';

import '../fake_contract_repository.dart';

class TestAuthController extends AuthController {
  TestAuthController(this.session);
  final AppSession? session;
  @override
  FutureOr<AppSession?> build() => session;
}

AppSession _convertSession() {
  return AppSession(
    userId: 'u',
    email: 'e@test.com',
    tenantId: 't',
    tenantUserId: 'tu',
    accountType: 'user',
    displayName: 'Test',
    preferredLocale: 'en',
    permissions: AppPermissions(
      isManager: false,
      permissions: const {'contracts.convert_trial', 'contracts.view'},
    ),
  );
}

void main() {
  test('old trial defaults to 12-month rental term starting today', () async {
    final repo = FakeContractRepository(
      detailById: {
        'trial-old': sampleTrialDetail(
          id: 'trial-old',
          startDate: DateTime(2024, 3, 1),
        ),
      },
    );
    final container = ProviderContainer(
      overrides: [
        authControllerProvider.overrideWith(
          () => TestAuthController(_convertSession()),
        ),
        contractRepositoryProvider.overrideWith((ref) => repo),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(
      contractConvertControllerProvider('trial-old').notifier,
    );
    await notifier.load('trial-old');

    final state = container.read(
      contractConvertControllerProvider('trial-old'),
    );
    final today = normalizeConversionStartDate();

    expect(state.conversionStartDate, today);
    expect(state.endDate, defaultConversionEndDate(today));
    expect(state.billingDay, defaultCycleDay(today));
    expect(state.refillDay, defaultCycleDay(today));
    expect(state.trialDetail?.startDate, DateTime(2024, 3, 1));

    notifier.setMonthlyRentalValue(Decimal.fromInt(120));
    await notifier.refreshPreview();

    final previewDraft = repo.lastPreviewDraft;
    expect(previewDraft, isNotNull);
    expect(previewDraft!.startDate, today);
    expect(previewDraft.endDate, defaultConversionEndDate(today));
  });
}

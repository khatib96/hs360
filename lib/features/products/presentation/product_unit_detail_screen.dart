import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../core/localization/locale_controller.dart';
import '../../../core/routing/app_routes.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../auth/presentation/auth_controller.dart';
import '../domain/product_unit_permissions.dart';
import 'product_unit_detail_controller.dart';
import 'product_unit_timeline_controller.dart';
import 'products_error_messages.dart';
import 'widgets/product_unit_detail_header.dart';
import 'widgets/product_unit_serial_correction_card.dart';
import 'widgets/product_unit_timeline_list.dart';

class ProductUnitDetailScreen extends ConsumerWidget {
  const ProductUnitDetailScreen({required this.unitId, super.key});

  final String unitId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final locale = ref.watch(localeProvider);
    final session = ref.watch(authControllerProvider).valueOrNull;
    final state = ref.watch(productUnitDetailControllerProvider(unitId));
    final controller =
        ref.read(productUnitDetailControllerProvider(unitId).notifier);
    final timelineState =
        ref.watch(productUnitTimelineControllerProvider(unitId));

    final canCorrect =
        session != null && canCorrectProductUnitSerial(session);

    Widget body;
    if (state.isLoading) {
      body = Center(child: Text(l10n.loading));
    } else if (state.errorCode != null) {
      body = Center(
        child: Text(productsErrorMessage(l10n, state.errorCode!)),
      );
    } else if (state.unit == null) {
      body = Center(
        key: const Key('product-unit-detail-not-found'),
        child: Text(l10n.productUnitDetailNotFound),
      );
    } else {
      final unit = state.unit!;
      body = ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ProductUnitDetailHeader(
            unit: unit,
            l10n: l10n,
            languageCode: locale.languageCode,
          ),
          const SizedBox(height: 16),
          ProductUnitSerialCorrectionCard(
            l10n: l10n,
            canCorrect: canCorrect,
            isSubmitting: state.isSubmittingCorrection,
            errorCode: state.correctionErrorCode,
            showSuccess: state.correctionSuccess,
            onSubmit: (newSerial, reason) => controller.correctSerial(
                  newSerial: newSerial,
                  reason: reason,
                ),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.productUnitTimelineTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          ProductUnitTimelineList(
            l10n: l10n,
            isLoading: timelineState.isLoading,
            events: timelineState.events,
            errorCode: timelineState.errorCode,
          ),
        ],
      );
    }

    return AppShell(
      title: l10n.productUnitDetailTitle,
      currentRoute: AppRoutes.productUnitDetailPath(unitId),
      body: body,
    );
  }
}

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../auth/presentation/auth_controller.dart';
import '../../../finance_shared/presentation/money_display.dart';
import '../../../invoices/presentation/widgets/invoice_sheet.dart';
import '../../../invoices/presentation/widgets/invoice_totals_panel.dart';
import '../../../../shared/widgets/message_banner.dart';
import '../../domain/contract_detail.dart';
import '../../domain/contract_permissions.dart';
import '../contract_convert_controller.dart';
import '../contract_convert_draft_builder.dart';
import '../contract_display_helpers.dart';
import 'contract_cost_breakdown.dart';
import 'contract_detail_panel.dart';

class ContractConvertPricingSummary extends ConsumerWidget {
  const ContractConvertPricingSummary({
    required this.trialContractId,
    super.key,
  });

  final String trialContractId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final languageCode = Localizations.localeOf(context).languageCode;
    final session = ref.watch(authControllerProvider).valueOrNull;
    final state = ref.watch(contractConvertControllerProvider(trialContractId));
    final controller = ref.read(
      contractConvertControllerProvider(trialContractId).notifier,
    );
    final trial = state.trialDetail;
    final conversionStartDate = state.conversionStartDate;
    final preview = state.pricingPreview;

    if (trial == null || conversionStartDate == null) {
      return const SizedBox.shrink();
    }

    final draft = buildConversionPreviewDraft(
      trialDetail: trial,
      conversionStartDate: conversionStartDate,
      monthlyRentalValue: state.monthlyRentalValue ?? Decimal.zero,
      endDate: state.endDate,
      billingDay: state.billingDay,
      refillDay: state.refillDay,
      requestOverride: state.requestOverride,
      overrideReason: state.overrideReason,
    );
    final durationLabel = contractDurationLabel(
      l10n,
      contractDraftDurationMonths(draft),
    );
    final totalValue = contractDraftDisplayTotalValue(draft);

    final costRows = <ContractCostRow>[
      if (session != null &&
          preview != null &&
          canViewContractDeviceCost(session))
        for (final line in preview.assetLines)
          if (line.sourceUnitCost != null && line.monthlyCost != null)
            ContractCostRow(
              productName: _lineName(
                trial: trial,
                productId: line.productId,
                isAsset: true,
                languageCode: languageCode,
              ),
              quantity: Decimal.one,
              unitCost: line.sourceUnitCost!,
              monthlyCost: line.monthlyCost!,
            ),
      if (session != null && preview != null && canViewContractOilCost(session))
        for (final line in preview.consumableLines)
          if (line.sourceUnitCost != null && line.monthlyCost != null)
            ContractCostRow(
              productName: _lineName(
                trial: trial,
                productId: line.productId,
                isAsset: false,
                languageCode: languageCode,
              ),
              quantity: line.qtyPerRefill ?? line.qtyPrimary ?? Decimal.one,
              unitCost: line.sourceUnitCost!,
              monthlyCost: line.monthlyCost!,
            ),
    ];
    final totalMonthlyCost =
        session != null && preview != null && canViewContractTotalCost(session)
        ? preview.totalMonthlyCost
        : null;
    final netMonthlyProfit =
        session != null && preview != null && canViewContractProfit(session)
        ? preview.expectedMonthlyProfit
        : null;
    final canViewFinancialDetails =
        costRows.isNotEmpty ||
        totalMonthlyCost != null ||
        netMonthlyProfit != null;

    final showOverride =
        session != null &&
        canApproveContractOverride(session) &&
        preview?.requiresOverride == true;

    final rows = <InvoiceTotalsRow>[];
    if (state.monthlyRentalValue != null) {
      rows.add(
        InvoiceTotalsRow(
          l10n.contractFieldMonthlyRentalValue,
          state.monthlyRentalValue!,
        ),
      );
    }

    return InvoiceSectionCard(
      title: l10n.contractSectionValueSummary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (session != null &&
              canViewContractProfit(session) &&
              preview?.belowMinProfit == true)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: MessageBanner(
                message: l10n.contractLowProfitWarning,
                variant: MessageBannerVariant.info,
              ),
            ),
          if (durationLabel != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(child: Text(l10n.contractFieldContractDuration)),
                  Text(durationLabel),
                ],
              ),
            ),
          if (rows.isNotEmpty) InvoiceTotalsBlock(rows: rows),
          if (totalValue != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.contractFieldTotalContractValue,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  MoneyDisplay(amount: totalValue),
                ],
              ),
            ),
          if (canViewFinancialDetails)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Material(
                color: Colors.transparent,
                child: ExpansionTile(
                  key: const Key('contract-convert-financial-details'),
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: EdgeInsets.zero,
                  title: Text(l10n.contractFinancialDetails),
                  children: [
                    ContractCostBreakdown(
                      key: const Key('contract-convert-cost-breakdown'),
                      rows: costRows,
                      totalMonthlyCost: totalMonthlyCost,
                      netMonthlyProfit: netMonthlyProfit,
                    ),
                  ],
                ),
              ),
            ),
          if (canViewFinancialDetails && state.isLoadingPreview)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: LinearProgressIndicator(),
            ),
          if (showOverride) ...[
            const SizedBox(height: 12),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.contractRequestOverride),
              value: state.requestOverride,
              onChanged: (value) =>
                  controller.setRequestOverride(value ?? false),
            ),
            if (state.requestOverride)
              TextFormField(
                key: const Key('contract-convert-override-reason'),
                initialValue: state.overrideReason,
                decoration: InputDecoration(
                  labelText: l10n.contractFieldOverrideReason,
                ),
                maxLines: 2,
                onChanged: controller.setOverrideReason,
              ),
          ],
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton(
              onPressed: state.isLoadingPreview
                  ? null
                  : controller.refreshPreview,
              child: Text(l10n.contractRefreshPreview),
            ),
          ),
        ],
      ),
    );
  }
}

String _lineName({
  required ContractDetail trial,
  required String productId,
  required bool isAsset,
  required String languageCode,
}) {
  if (isAsset) {
    for (final line in trial.assetLines) {
      if (line.productId == productId) {
        return contractCustomerName(
          languageCode: languageCode,
          nameAr: line.productNameAr,
          nameEn: line.productNameEn,
        );
      }
    }
  } else {
    for (final line in trial.consumableLines) {
      if (line.productId == productId) {
        return contractCustomerName(
          languageCode: languageCode,
          nameAr: line.productNameAr,
          nameEn: line.productNameEn,
        );
      }
    }
  }
  return productId;
}

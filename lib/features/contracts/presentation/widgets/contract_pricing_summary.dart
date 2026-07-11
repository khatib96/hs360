import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../auth/presentation/auth_controller.dart';
import '../../../finance_shared/presentation/money_display.dart';
import '../../../invoices/presentation/widgets/invoice_sheet.dart';
import '../../../invoices/presentation/widgets/invoice_totals_panel.dart';
import '../../../../shared/widgets/message_banner.dart';
import '../../domain/contract_permissions.dart';
import '../../domain/contract_type.dart';
import '../contract_display_helpers.dart';
import '../contract_form_controller.dart';
import '../contract_form_draft_builder.dart';
import 'contract_cost_breakdown.dart';
import 'contract_detail_panel.dart';

class ContractPricingSummary extends ConsumerWidget {
  const ContractPricingSummary({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final languageCode = Localizations.localeOf(context).languageCode;
    final session = ref.watch(authControllerProvider).valueOrNull;
    final state = ref.watch(contractFormControllerProvider);
    final controller = ref.read(contractFormControllerProvider.notifier);
    final draft = buildContractDraft(state);
    final durationMonths = contractDraftDurationMonths(draft);
    final durationLabel = contractDurationLabel(l10n, durationMonths);
    final totalValue = contractDraftDisplayTotalValue(draft);
    final preview = state.pricingPreview;
    final assetProducts = {
      for (final line in state.assetLines)
        if (line.product != null) line.product!.id: line.product!,
    };
    final consumableProducts = {
      for (final line in state.consumableLines)
        if (line.product != null) line.product!.id: line.product!,
    };
    final costRows = <ContractCostRow>[
      if (session != null &&
          preview != null &&
          canViewContractDeviceCost(session))
        for (final line in preview.assetLines)
          if (line.sourceUnitCost != null && line.monthlyCost != null)
            ContractCostRow(
              productName: _localizedProductName(
                assetProducts[line.productId]?.nameAr,
                assetProducts[line.productId]?.nameEn,
                line.productId,
                languageCode,
              ),
              quantity: Decimal.one,
              unitCost: line.sourceUnitCost!,
              monthlyCost: line.monthlyCost!,
            ),
      if (session != null && preview != null && canViewContractOilCost(session))
        for (final line in preview.consumableLines)
          if (line.sourceUnitCost != null && line.monthlyCost != null)
            ContractCostRow(
              productName: _localizedProductName(
                consumableProducts[line.productId]?.nameAr,
                consumableProducts[line.productId]?.nameEn,
                line.productId,
                languageCode,
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

    if (state.type != ContractType.rental &&
        durationLabel == null &&
        totalValue == null) {
      return const SizedBox.shrink();
    }

    final rows = <InvoiceTotalsRow>[];
    if (state.type == ContractType.rental && state.monthlyRentalValue != null) {
      rows.add(
        InvoiceTotalsRow(
          l10n.contractFieldMonthlyRentalValue,
          state.monthlyRentalValue!,
        ),
      );
    }

    final showOverride =
        session != null &&
        canApproveContractOverride(session) &&
        preview?.requiresOverride == true;

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
            _FinancialDetails(
              title: l10n.contractFinancialDetails,
              child: ContractCostBreakdown(
                rows: costRows,
                totalMonthlyCost: totalMonthlyCost,
                netMonthlyProfit: netMonthlyProfit,
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
                key: const Key('contract-override-reason'),
                initialValue: state.overrideReason,
                decoration: InputDecoration(
                  labelText: l10n.contractFieldOverrideReason,
                ),
                maxLines: 2,
                onChanged: controller.setOverrideReason,
              ),
          ],
        ],
      ),
    );
  }
}

class _FinancialDetails extends StatelessWidget {
  const _FinancialDetails({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Material(
        color: Colors.transparent,
        child: ExpansionTile(
          key: const Key('contract-financial-details'),
          tilePadding: EdgeInsets.zero,
          childrenPadding: EdgeInsets.zero,
          title: Text(title),
          children: [child],
        ),
      ),
    );
  }
}

String _localizedProductName(
  String? nameAr,
  String? nameEn,
  String fallback,
  String languageCode,
) {
  final primary = languageCode == 'ar' ? nameAr : nameEn;
  final secondary = languageCode == 'ar' ? nameEn : nameAr;
  if (primary?.trim().isNotEmpty == true) return primary!.trim();
  if (secondary?.trim().isNotEmpty == true) return secondary!.trim();
  return fallback;
}

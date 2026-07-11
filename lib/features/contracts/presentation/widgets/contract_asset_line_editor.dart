import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../invoices/presentation/widgets/invoice_design.dart';
import '../../../invoices/presentation/widgets/invoice_sheet.dart';
import '../../../products/domain/product.dart';
import '../../../products/presentation/product_display_helpers.dart';
import '../../../products/presentation/product_unit_display_helpers.dart';
import '../contract_form_controller.dart';
import '../contract_form_state.dart';
import 'contract_product_picker_dialog.dart';

class ContractAssetLineEditor extends ConsumerWidget {
  const ContractAssetLineEditor({required this.languageCode, super.key});

  final String languageCode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(contractFormControllerProvider);
    final controller = ref.read(contractFormControllerProvider.notifier);
    final isDesktop = InvoiceDesign.isDesktop(context);

    return InvoiceSectionCard(
      title: l10n.contractSectionAssets,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (state.assetLines.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(l10n.contractAssetsEmpty),
            ),
          if (isDesktop && state.assetLines.isNotEmpty)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(
                  InvoiceDesign.headerFill,
                ),
                headingTextStyle: InvoiceDesign.columnHeaderStyle(context),
                columns: [
                  DataColumn(label: Text(l10n.contractFieldProduct)),
                  DataColumn(label: Text(l10n.contractFieldSerialNumber)),
                  DataColumn(label: Text('')),
                ],
                rows: [
                  for (var i = 0; i < state.assetLines.length; i++)
                    _assetRow(context, ref, l10n, i, state.assetLines[i]),
                ],
              ),
            )
          else
            for (var i = 0; i < state.assetLines.length; i++) ...[
              _assetCard(context, ref, l10n, i, state.assetLines[i]),
              const SizedBox(height: 8),
            ],
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              key: const Key('contract-add-asset-line'),
              onPressed: controller.addAssetLine,
              icon: const Icon(Icons.add, size: 18),
              label: Text(l10n.contractAddAssetLine),
            ),
          ),
        ],
      ),
    );
  }

  DataRow _assetRow(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    int index,
    ContractAssetLineUiState line,
  ) {
    final controller = ref.read(contractFormControllerProvider.notifier);
    return DataRow(
      cells: [
        DataCell(_productCell(context, ref, index, line.product)),
        DataCell(_unitCell(context, ref, l10n, index, line)),
        DataCell(
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18),
            onPressed: () => controller.removeAssetLine(index),
          ),
        ),
      ],
    );
  }

  Widget _assetCard(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    int index,
    ContractAssetLineUiState line,
  ) {
    final controller = ref.read(contractFormControllerProvider.notifier);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: _productCell(context, ref, index, line.product),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => controller.removeAssetLine(index),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _unitCell(context, ref, l10n, index, line),
          ],
        ),
      ),
    );
  }

  Widget _productCell(
    BuildContext context,
    WidgetRef ref,
    int index,
    Product? product,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final label = product == null
        ? l10n.invoiceFormSelectProduct
        : localizedProductName(product, languageCode);

    return InkWell(
      onTap: () => showContractProductPicker(
        context,
        ref,
        lineIndex: index,
        target: ContractProductSearchTarget.asset,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Text(label, maxLines: 2, overflow: TextOverflow.ellipsis),
      ),
    );
  }

  Widget _unitCell(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    int index,
    ContractAssetLineUiState line,
  ) {
    final controller = ref.read(contractFormControllerProvider.notifier);
    if (line.product == null) {
      return Text(
        l10n.contractSelectProductFirst,
        style: Theme.of(context).textTheme.bodySmall,
      );
    }
    if (line.isLoadingUnits) {
      return const LinearProgressIndicator();
    }
    if (line.availableUnits.isEmpty) {
      return Text(
        l10n.contractNoAvailableUnits,
        style: Theme.of(context).textTheme.bodySmall,
      );
    }

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final unit in line.availableUnits)
          FilterChip(
            key: Key('contract-unit-${unit.id}'),
            label: Text(unit.serialNumber),
            selected: line.productUnitId == unit.id,
            onSelected: (_) => controller.setAssetUnit(index, unit.id),
            avatar: Text(
              unitStatusLabel(l10n, unit.status).characters.first,
              style: const TextStyle(fontSize: 10),
            ),
          ),
      ],
    );
  }
}

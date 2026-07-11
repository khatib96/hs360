import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../invoices/presentation/widgets/invoice_design.dart';
import '../../../invoices/presentation/widgets/invoice_sheet.dart';
import '../../../products/domain/product.dart';
import '../../../products/presentation/product_display_helpers.dart';
import '../contract_form_controller.dart';
import '../contract_form_state.dart';
import 'contract_product_picker_dialog.dart';

class ContractConsumableLineEditor extends ConsumerWidget {
  const ContractConsumableLineEditor({required this.languageCode, super.key});

  final String languageCode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(contractFormControllerProvider);
    final controller = ref.read(contractFormControllerProvider.notifier);
    final isDesktop = InvoiceDesign.isDesktop(context);

    return InvoiceSectionCard(
      title: l10n.contractSectionConsumables,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (state.consumableLines.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(l10n.contractConsumablesEmpty),
            ),
          if (isDesktop && state.consumableLines.isNotEmpty)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(
                  InvoiceDesign.headerFill,
                ),
                headingTextStyle: InvoiceDesign.columnHeaderStyle(context),
                columns: [
                  DataColumn(label: Text(l10n.contractFieldProduct)),
                  DataColumn(label: Text(l10n.contractFieldQtyPerRefill)),
                  DataColumn(label: Text(l10n.contractFieldRefillFrequency)),
                  DataColumn(label: Text('')),
                ],
                rows: [
                  for (var i = 0; i < state.consumableLines.length; i++)
                    _consumableRow(
                      context,
                      ref,
                      l10n,
                      i,
                      state.consumableLines[i],
                    ),
                ],
              ),
            )
          else
            for (var i = 0; i < state.consumableLines.length; i++) ...[
              _consumableCard(context, ref, l10n, i, state.consumableLines[i]),
              const SizedBox(height: 8),
            ],
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              key: const Key('contract-add-consumable-line'),
              onPressed: controller.addConsumableLine,
              icon: const Icon(Icons.add, size: 18),
              label: Text(l10n.contractAddConsumableLine),
            ),
          ),
        ],
      ),
    );
  }

  DataRow _consumableRow(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    int index,
    ContractConsumableLineUiState line,
  ) {
    final controller = ref.read(contractFormControllerProvider.notifier);
    return DataRow(
      cells: [
        DataCell(_productCell(context, ref, index, line.product)),
        DataCell(
          SizedBox(
            width: 100,
            child: TextFormField(
              initialValue: line.qtyPerRefill.toString(),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InvoiceDesign.denseField(context),
              onChanged: (value) =>
                  controller.setConsumableQtyFromText(index, value),
            ),
          ),
        ),
        DataCell(
          SizedBox(
            width: 80,
            child: TextFormField(
              initialValue: line.refillFrequencyMonths.toString(),
              keyboardType: TextInputType.number,
              decoration: InvoiceDesign.denseField(context),
              onChanged: (value) {
                final months = int.tryParse(value.trim());
                if (months != null) {
                  controller.setConsumableFrequency(index, months);
                }
              },
            ),
          ),
        ),
        DataCell(
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18),
            onPressed: () => controller.removeConsumableLine(index),
          ),
        ),
      ],
    );
  }

  Widget _consumableCard(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    int index,
    ContractConsumableLineUiState line,
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
                  onPressed: () => controller.removeConsumableLine(index),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextFormField(
              initialValue: line.qtyPerRefill.toString(),
              decoration: InvoiceDesign.denseField(
                context,
                hint: l10n.contractFieldQtyPerRefill,
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: (value) =>
                  controller.setConsumableQtyFromText(index, value),
            ),
            const SizedBox(height: 8),
            TextFormField(
              initialValue: line.refillFrequencyMonths.toString(),
              decoration: InvoiceDesign.denseField(
                context,
                hint: l10n.contractFieldRefillFrequency,
              ),
              keyboardType: TextInputType.number,
              onChanged: (value) {
                final months = int.tryParse(value.trim());
                if (months != null) {
                  controller.setConsumableFrequency(index, months);
                }
              },
            ),
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
        target: ContractProductSearchTarget.consumable,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Text(label, maxLines: 2, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}

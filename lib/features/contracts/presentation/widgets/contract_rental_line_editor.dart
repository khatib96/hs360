import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../../core/errors/scan_exception.dart';
import '../../../invoices/presentation/widgets/invoice_design.dart';
import '../../../invoices/presentation/widgets/invoice_sheet.dart';
import '../../../products/domain/product.dart';
import '../../../products/domain/product_type.dart';
import '../../../products/presentation/product_display_helpers.dart';
import '../contract_form_controller.dart';
import '../contract_form_state.dart';
import 'contract_product_picker_dialog.dart';

class ContractRentalLineEditor extends ConsumerStatefulWidget {
  const ContractRentalLineEditor({required this.languageCode, super.key});

  final String languageCode;

  @override
  ConsumerState<ContractRentalLineEditor> createState() =>
      _ContractRentalLineEditorState();
}

class _ContractRentalLineEditorState
    extends ConsumerState<ContractRentalLineEditor> {
  final _codeController = TextEditingController();

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(contractFormControllerProvider);
    final controller = ref.read(contractFormControllerProvider.notifier);
    final isDesktop = InvoiceDesign.isDesktop(context);
    final rows = _combinedRows(state);

    return InvoiceSectionCard(
      title: l10n.contractSectionProducts,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _QuickCodeInput(
            controller: _codeController,
            onResolve: () async {
              final code = _codeController.text.trim();
              if (code.isEmpty) return;
              await controller.addRentalCode(code);
              _codeController.clear();
            },
          ),
          const SizedBox(height: 12),
          if (rows.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(l10n.contractProductsEmpty),
            ),
          if (rows.isNotEmpty && isDesktop)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(
                  InvoiceDesign.headerFill,
                ),
                headingTextStyle: InvoiceDesign.columnHeaderStyle(context),
                columns: [
                  DataColumn(label: Text(l10n.contractFieldProduct)),
                  DataColumn(label: Text(l10n.contractColumnType)),
                  DataColumn(label: Text(l10n.contractSerialOrBarcode)),
                  DataColumn(label: Text(l10n.contractFieldQuantity)),
                  DataColumn(label: Text(l10n.contractFieldFrequency)),
                  DataColumn(label: Text('')),
                ],
                rows: [for (final row in rows) _desktopRow(context, l10n, row)],
              ),
            )
          else
            for (final row in rows) ...[
              _mobileCard(context, l10n, row),
              const SizedBox(height: 8),
            ],
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              key: const Key('contract-add-rental-product'),
              onPressed: () => showContractProductPicker(
                context,
                ref,
                lineIndex: -1,
                target: ContractProductSearchTarget.rental,
              ),
              icon: const Icon(Icons.add, size: 18),
              label: Text(l10n.contractAddRentalProduct),
            ),
          ),
        ],
      ),
    );
  }

  DataRow _desktopRow(
    BuildContext context,
    AppLocalizations l10n,
    _RentalRow row,
  ) {
    return DataRow(
      cells: [
        DataCell(_productLabel(context, row.product)),
        DataCell(Text(_productTypeLabel(l10n, row.product))),
        DataCell(_serialCell(context, l10n, row)),
        DataCell(_qtyCell(context, row)),
        DataCell(_frequencyCell(context, row)),
        DataCell(_removeButton(row)),
      ],
    );
  }

  Widget _mobileCard(
    BuildContext context,
    AppLocalizations l10n,
    _RentalRow row,
  ) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: _productLabel(context, row.product)),
                Text(_productTypeLabel(l10n, row.product)),
                _removeButton(row),
              ],
            ),
            const SizedBox(height: 8),
            if (row.isAsset) _serialCell(context, l10n, row),
            if (!row.isAsset) ...[
              _qtyCell(context, row),
              const SizedBox(height: 8),
              _frequencyCell(context, row),
            ],
          ],
        ),
      ),
    );
  }

  Widget _productLabel(BuildContext context, Product product) {
    return Text(
      localizedProductName(product, widget.languageCode),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _serialCell(
    BuildContext context,
    AppLocalizations l10n,
    _RentalRow row,
  ) {
    if (!row.isAsset) return const SizedBox.shrink();
    final line = row.assetLine!;
    if (line.product?.isSerialized != true) return const Text('-');
    final controller = ref.read(contractFormControllerProvider.notifier);
    var selectedSerial = '';
    for (final unit in line.availableUnits) {
      if (unit.id == line.productUnitId) {
        selectedSerial = unit.serialNumber;
        break;
      }
    }
    final error = line.unitErrorCode == null
        ? null
        : _unitErrorMessage(l10n, line.unitErrorCode!);

    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 260, maxWidth: 360),
      child: TextFormField(
        key: Key('contract-unit-code-${row.index}'),
        initialValue: line.unitCode.isNotEmpty ? line.unitCode : selectedSerial,
        decoration:
            InvoiceDesign.denseField(
              context,
              hint: l10n.contractSerialOrBarcode,
            ).copyWith(
              errorText: error,
              suffixIcon: line.isResolvingUnit
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : IconButton(
                      tooltip: l10n.contractResolveSerial,
                      icon: const Icon(Icons.qr_code_scanner, size: 18),
                      onPressed: () =>
                          controller.resolveAssetUnitCode(row.index),
                    ),
            ),
        onChanged: (value) => controller.setAssetUnitCode(row.index, value),
        onFieldSubmitted: (_) => controller.resolveAssetUnitCode(row.index),
      ),
    );
  }

  Widget _qtyCell(BuildContext context, _RentalRow row) {
    if (row.isAsset) return const Text('1');
    final controller = ref.read(contractFormControllerProvider.notifier);
    final line = row.consumableLine!;
    return SizedBox(
      width: 120,
      child: TextFormField(
        key: Key('contract-consumable-qty-${row.index}'),
        initialValue: line.qtyPerRefill.toString(),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
        decoration: InvoiceDesign.denseField(context),
        onChanged: (value) =>
            controller.setConsumableQtyFromText(row.index, value),
      ),
    );
  }

  Widget _frequencyCell(BuildContext context, _RentalRow row) {
    if (row.isAsset) return const Text('-');
    final controller = ref.read(contractFormControllerProvider.notifier);
    final line = row.consumableLine!;
    return SizedBox(
      width: 120,
      child: TextFormField(
        key: Key('contract-consumable-frequency-${row.index}'),
        initialValue: line.refillFrequencyMonths.toString(),
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InvoiceDesign.denseField(context),
        onChanged: (value) => controller.setConsumableFrequency(
          row.index,
          int.tryParse(value) ?? 1,
        ),
      ),
    );
  }

  Widget _removeButton(_RentalRow row) {
    final controller = ref.read(contractFormControllerProvider.notifier);
    return IconButton(
      icon: const Icon(Icons.delete_outline, size: 18),
      onPressed: () {
        if (row.isAsset) {
          controller.removeAssetLine(row.index);
        } else {
          controller.removeConsumableLine(row.index);
        }
      },
    );
  }

  String _productTypeLabel(AppLocalizations l10n, Product product) {
    return switch (product.productType) {
      ProductType.assetRental => l10n.productRentalTypeAsset,
      ProductType.consumableRental => l10n.productRentalTypeConsumable,
      ProductType.saleOnly => '',
    };
  }

  String _unitErrorMessage(AppLocalizations l10n, String code) {
    return switch (code) {
      ScanException.scanNotFound => l10n.scanErrorNotFound,
      _ => l10n.financeValidationSerializedUnitRequired,
    };
  }

  List<_RentalRow> _combinedRows(ContractFormUiState state) {
    return [
      for (var i = 0; i < state.assetLines.length; i++)
        if (state.assetLines[i].product != null)
          _RentalRow.asset(i, state.assetLines[i]),
      for (var i = 0; i < state.consumableLines.length; i++)
        if (state.consumableLines[i].product != null)
          _RentalRow.consumable(i, state.consumableLines[i]),
    ];
  }
}

class _QuickCodeInput extends StatelessWidget {
  const _QuickCodeInput({required this.controller, required this.onResolve});

  final TextEditingController controller;
  final VoidCallback onResolve;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      children: [
        Expanded(
          child: TextField(
            key: const Key('contract-rental-code'),
            controller: controller,
            decoration: InvoiceDesign.denseField(
              context,
              hint: l10n.contractSerialOrBarcode,
            ),
            onSubmitted: (_) => onResolve(),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          tooltip: l10n.contractResolveSerial,
          icon: const Icon(Icons.qr_code_scanner),
          onPressed: onResolve,
        ),
      ],
    );
  }
}

class _RentalRow {
  const _RentalRow.asset(this.index, this.assetLine)
    : consumableLine = null,
      isAsset = true;

  const _RentalRow.consumable(this.index, this.consumableLine)
    : assetLine = null,
      isAsset = false;

  final int index;
  final bool isAsset;
  final ContractAssetLineUiState? assetLine;
  final ContractConsumableLineUiState? consumableLine;

  Product get product =>
      isAsset ? assetLine!.product! : consumableLine!.product!;
}

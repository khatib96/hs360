import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../invoices/presentation/widgets/invoice_design.dart';
import '../../../products/domain/product.dart';
import '../../domain/consumable_change_draft.dart';
import '../../domain/contract_detail.dart';
import '../../domain/contract_line.dart';
import '../contract_display_helpers.dart';
import '../contract_lifecycle_controller.dart';
import 'consumable_rental_product_picker_dialog.dart';
import 'contract_cycle_day_field.dart';

Future<bool?> showContractConsumableChangeDialog(
  BuildContext context,
  WidgetRef ref, {
  required ContractDetail detail,
}) {
  return showDialog<bool>(
    context: context,
    builder: (context) => _ContractConsumableChangeDialog(detail: detail),
  );
}

class _ContractConsumableChangeDialog extends ConsumerStatefulWidget {
  const _ContractConsumableChangeDialog({required this.detail});

  final ContractDetail detail;

  @override
  ConsumerState<_ContractConsumableChangeDialog> createState() =>
      _ContractConsumableChangeDialogState();
}

class _ContractConsumableChangeDialogState
    extends ConsumerState<_ContractConsumableChangeDialog> {
  late ContractConsumableLine _selectedLine;
  late DateTime _effectiveDate;
  Product? _selectedProduct;
  final _qtyController = TextEditingController(text: '1');
  final _reasonController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedLine = widget.detail.consumableLines.firstWhere(
      (line) => line.scheduledEffectiveFrom == null,
      orElse: () => widget.detail.consumableLines.first,
    );
    final now = DateTime.now();
    _effectiveDate = DateTime(now.year, now.month, now.day);
    _qtyController.text =
        (_selectedLine.currentQtyPerRefill ??
                _selectedLine.qtyPerRefill ??
                Decimal.one)
            .toString();
  }

  @override
  void dispose() {
    _qtyController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  List<ContractConsumableLine> get _eligibleLines => widget
      .detail
      .consumableLines
      .where((line) => line.scheduledEffectiveFrom == null)
      .toList();

  Future<void> _pickProduct() async {
    final product = await showConsumableRentalProductPicker(context);
    if (product != null) {
      setState(() => _selectedProduct = product);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final lifecycle = ref.watch(contractLifecycleControllerProvider);
    final controller = ref.read(contractLifecycleControllerProvider.notifier);
    final material = MaterialLocalizations.of(context);
    final languageCode = Localizations.localeOf(context).languageCode;
    final scheduled = _selectedLine.scheduledEffectiveFrom;
    final productLabel = _selectedProduct == null
        ? l10n.contractSelectProductFirst
        : contractCustomerName(
            languageCode: languageCode,
            nameAr: _selectedProduct!.nameAr,
            nameEn: _selectedProduct!.nameEn,
          );

    return AlertDialog(
      title: Text(l10n.contractScheduleConsumableAction),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (lifecycle.validationCodes.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    contractValidationMessages(
                      l10n,
                      lifecycle.validationCodes,
                    ).join('\n'),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              if (lifecycle.errorCode != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    contractErrorMessage(l10n, lifecycle.errorCode!),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              if (_eligibleLines.length > 1)
                ContractLabeledField(
                  label: l10n.contractFieldProduct,
                  child: InputDecorator(
                    decoration: InvoiceDesign.denseField(context),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: _selectedLine.id,
                        items: [
                          for (final line in _eligibleLines)
                            DropdownMenuItem(
                              value: line.id,
                              child: Text(
                                contractCustomerName(
                                  languageCode: languageCode,
                                  nameAr:
                                      line.currentOilProductNameAr ??
                                      line.productNameAr,
                                  nameEn:
                                      line.currentOilProductNameEn ??
                                      line.productNameEn,
                                ),
                              ),
                            ),
                        ],
                        onChanged: lifecycle.isSubmitting
                            ? null
                            : (value) {
                                if (value == null) return;
                                setState(() {
                                  _selectedLine = _eligibleLines.firstWhere(
                                    (line) => line.id == value,
                                  );
                                  _selectedProduct = null;
                                  _qtyController.text =
                                      (_selectedLine.currentQtyPerRefill ??
                                              _selectedLine.qtyPerRefill ??
                                              Decimal.one)
                                          .toString();
                                });
                              },
                      ),
                    ),
                  ),
                ),
              ContractLabeledField(
                label: l10n.contractConsumableCurrent,
                child: Text(
                  contractCustomerName(
                    languageCode: languageCode,
                    nameAr:
                        _selectedLine.currentOilProductNameAr ??
                        _selectedLine.productNameAr,
                    nameEn:
                        _selectedLine.currentOilProductNameEn ??
                        _selectedLine.productNameEn,
                  ),
                ),
              ),
              if (scheduled != null) ...[
                const SizedBox(height: 8),
                Text(
                  l10n.contractConsumableScheduledBanner(
                    formatContractDate(scheduled),
                  ),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.tertiary,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              ContractLabeledField(
                label: l10n.contractFieldProduct,
                child: OutlinedButton(
                  key: const Key('consumable-change-product-picker'),
                  onPressed: lifecycle.isSubmitting || scheduled != null
                      ? null
                      : _pickProduct,
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(productLabel),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ContractLabeledField(
                label: l10n.contractFieldQtyPerRefill,
                child: TextFormField(
                  controller: _qtyController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InvoiceDesign.denseField(context),
                ),
              ),
              const SizedBox(height: 12),
              ContractLabeledField(
                label: l10n.contractFieldEffectiveDate,
                child: ContractDatePickerField(
                  value: _effectiveDate,
                  firstDate: widget.detail.startDate.isAfter(DateTime.now())
                      ? widget.detail.startDate
                      : DateTime(
                          DateTime.now().year,
                          DateTime.now().month,
                          DateTime.now().day,
                        ),
                  onPick: (date) {
                    if (date != null) setState(() => _effectiveDate = date);
                  },
                ),
              ),
              const SizedBox(height: 12),
              ContractLabeledField(
                label: l10n.contractFieldChangeReason,
                child: TextFormField(
                  controller: _reasonController,
                  decoration: InvoiceDesign.denseField(context),
                  maxLines: 3,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: lifecycle.isSubmitting
              ? null
              : () => Navigator.pop(context, false),
          child: Text(material.cancelButtonLabel),
        ),
        FilledButton(
          key: const Key('consumable-change-submit'),
          onPressed:
              lifecycle.isSubmitting ||
                  scheduled != null ||
                  _selectedProduct == null
              ? null
              : () => _submit(controller),
          child: lifecycle.isSubmitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.contractScheduleConsumableAction),
        ),
      ],
    );
  }

  Future<void> _submit(ContractLifecycleController controller) async {
    final qty = Decimal.tryParse(_qtyController.text.trim());
    final product = _selectedProduct;
    if (qty == null || product == null) return;
    final draft = ConsumableChangeDraft(
      contractId: widget.detail.id,
      contractLineId: _selectedLine.id,
      newProductId: product.id,
      effectiveDate: _effectiveDate,
      qtyPerRefill: qty,
      reason: _reasonController.text,
    );
    final error = await controller.scheduleConsumableChange(
      draft: draft,
      detail: widget.detail,
      line: _selectedLine,
    );
    if (!mounted) return;
    if (error == null) {
      controller.clearTransientState();
      Navigator.pop(context, true);
    }
  }
}

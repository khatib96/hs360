import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../../core/utils/decimal_parser.dart';
import '../../../../core/utils/quantity_formatter.dart';
import '../../../../domain/validators/inventory_adjustment_document_validator.dart';
import '../../../products/domain/product_unit.dart';
import '../../../products/presentation/product_display_helpers.dart';
import '../../domain/inventory_adjustment_reason.dart';
import '../inventory_document_display_helpers.dart';
import '../inventory_document_form_controller.dart';
import '../inventory_document_form_mode.dart';
import '../inventory_document_form_state.dart';

class InventoryDocumentLineEditor extends ConsumerStatefulWidget {
  const InventoryDocumentLineEditor({
    required this.mode,
    required this.lineIndex,
    required this.line,
    required this.languageCode,
    required this.canRemove,
    super.key,
  });

  final InventoryDocumentFormMode mode;
  final int lineIndex;
  final InventoryDocumentFormLineState line;
  final String languageCode;
  final bool canRemove;

  @override
  ConsumerState<InventoryDocumentLineEditor> createState() =>
      _InventoryDocumentLineEditorState();
}

class _InventoryDocumentLineEditorState
    extends ConsumerState<InventoryDocumentLineEditor> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _syncSearchText();
  }

  @override
  void didUpdateWidget(InventoryDocumentLineEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncSearchText();
  }

  void _syncSearchText() {
    final product = widget.line.product;
    if (product != null) {
      _searchController.text = localizedProductName(
        product,
        widget.languageCode,
      );
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  InventoryDocumentFormController get _controller =>
      ref.read(inventoryDocumentFormControllerProvider(widget.mode).notifier);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final formState = ref.watch(
      inventoryDocumentFormControllerProvider(widget.mode),
    );
    final product = widget.line.product;
    final serializedBlocked =
        widget.mode.blocksSerialized && product?.isSerialized == true;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsetsDirectional.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: l10n.inventoryDocumentSelectProduct,
              ),
              onChanged: (value) {
                _debounce?.cancel();
                _debounce = Timer(const Duration(milliseconds: 300), () {
                  _controller.searchProducts(value);
                });
              },
            ),
            if (formState.productSearchResults.isNotEmpty)
              ...formState.productSearchResults
                  .take(5)
                  .map(
                    (p) => ListTile(
                      title: Text(localizedProductName(p, widget.languageCode)),
                      subtitle: Text(p.sku),
                      onTap: () {
                        _controller.selectProduct(widget.lineIndex, p);
                        _searchController.text = localizedProductName(
                          p,
                          widget.languageCode,
                        );
                      },
                    ),
                  ),
            if (serializedBlocked)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  l10n.inventoryDocumentSerializedNotSupportedYet,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            if (widget.mode == InventoryDocumentFormMode.stockCount) ...[
              const SizedBox(height: 12),
              _readOnlyField(
                l10n.inventoryDocumentSystemQty,
                widget.line.systemQty == null
                    ? '—'
                    : formatQuantity(widget.line.systemQty!),
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: widget.line.countedQty.toString(),
                decoration: InputDecoration(
                  labelText: l10n.inventoryDocumentCountedQty,
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onChanged: (value) {
                  final parsed = tryParseDecimal(value);
                  if (parsed != null) {
                    _controller.setLineCountedQty(widget.lineIndex, parsed);
                  }
                },
              ),
              const SizedBox(height: 8),
              _readOnlyField(
                l10n.inventoryDocumentDeltaQty,
                widget.line.deltaQty == null
                    ? '—'
                    : formatQuantity(widget.line.deltaQty!),
              ),
            ] else ...[
              const SizedBox(height: 12),
              TextFormField(
                initialValue: widget.line.qty.toString(),
                decoration: InputDecoration(
                  labelText: l10n.inventoryMovementQuantity,
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onChanged: (value) {
                  final parsed = tryParseDecimal(value);
                  if (parsed != null) {
                    _controller.setLineQty(widget.lineIndex, parsed);
                  }
                },
              ),
              if (widget.mode == InventoryDocumentFormMode.openingStock ||
                  widget.mode == InventoryDocumentFormMode.stockIn) ...[
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: widget.line.unitCost?.toString() ?? '',
                  decoration: InputDecoration(
                    labelText: l10n.inventoryDocumentUnitCost,
                    helperText:
                        widget.mode == InventoryDocumentFormMode.stockIn &&
                            formState.reason?.allowsWacFallback == true
                        ? l10n.inventoryDocumentWacHint
                        : null,
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  onChanged: (value) {
                    final parsed = tryParseDecimal(value);
                    _controller.setLineUnitCost(widget.lineIndex, parsed);
                  },
                ),
              ],
            ],
            if (widget.mode == InventoryDocumentFormMode.stockIn &&
                product?.isSerialized == true) ...[
              const SizedBox(height: 12),
              _SerializedInEditor(
                qty: widget.line.qty,
                serialUnits: widget.line.serialUnits,
                onChanged: (units) =>
                    _controller.setLineSerialUnits(widget.lineIndex, units),
              ),
            ],
            if (widget.mode == InventoryDocumentFormMode.stockOut &&
                product?.isSerialized == true) ...[
              const SizedBox(height: 12),
              _SerializedOutEditor(
                qty: widget.line.qty,
                availableUnits: formState.availableUnits,
                selectedIds: widget.line.unitIds,
                onChanged: (ids) =>
                    _controller.setLineUnitIds(widget.lineIndex, ids),
              ),
            ],
            if (widget.canRemove)
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton(
                  onPressed: () => _controller.removeLine(widget.lineIndex),
                  child: Text(l10n.inventoryDocumentRemoveLine),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _readOnlyField(String label, String value) {
    return InputDecorator(
      decoration: InputDecoration(labelText: label),
      child: Text(value),
    );
  }
}

class _SerializedInEditor extends StatefulWidget {
  const _SerializedInEditor({
    required this.qty,
    required this.serialUnits,
    required this.onChanged,
  });

  final Decimal qty;
  final List<SerializedUnitInput> serialUnits;
  final ValueChanged<List<SerializedUnitInput>> onChanged;

  @override
  State<_SerializedInEditor> createState() => _SerializedInEditorState();
}

class _SerializedInEditorState extends State<_SerializedInEditor> {
  late List<TextEditingController> _controllers;

  @override
  void initState() {
    super.initState();
    _controllers = _buildControllers();
  }

  @override
  void didUpdateWidget(_SerializedInEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.qty != widget.qty) {
      for (final c in _controllers) {
        c.dispose();
      }
      _controllers = _buildControllers();
    }
  }

  List<TextEditingController> _buildControllers() {
    final count = widget.qty.toBigInt().toInt().clamp(0, 100);
    return List.generate(count, (index) {
      final existing = index < widget.serialUnits.length
          ? widget.serialUnits[index].serialNumber
          : '';
      return TextEditingController(text: existing);
    });
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _emit() {
    widget.onChanged([
      for (final c in _controllers)
        SerializedUnitInput(serialNumber: c.text.trim()),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.inventoryDocumentSerialUnits),
        const SizedBox(height: 8),
        for (var i = 0; i < _controllers.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: TextFormField(
              controller: _controllers[i],
              decoration: InputDecoration(labelText: '${i + 1}'),
              onChanged: (_) => _emit(),
            ),
          ),
      ],
    );
  }
}

class _SerializedOutEditor extends StatelessWidget {
  const _SerializedOutEditor({
    required this.qty,
    required this.availableUnits,
    required this.selectedIds,
    required this.onChanged,
  });

  final Decimal qty;
  final List<ProductUnit> availableUnits;
  final List<String> selectedIds;
  final ValueChanged<List<String>> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final needed = qty.toBigInt().toInt();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.inventoryDocumentSelectUnits),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final unit in availableUnits)
              FilterChip(
                label: Text(unit.serialNumber),
                selected: selectedIds.contains(unit.id),
                onSelected: (selected) {
                  final ids = [...selectedIds];
                  final id = unit.id;
                  if (selected) {
                    if (!ids.contains(id) && ids.length < needed) {
                      ids.add(id);
                    }
                  } else {
                    ids.remove(id);
                  }
                  onChanged(ids);
                },
              ),
          ],
        ),
      ],
    );
  }
}

class InventoryDocumentReasonFields extends ConsumerWidget {
  const InventoryDocumentReasonFields({required this.mode, super.key});

  final InventoryDocumentFormMode mode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context);
    final state = ref.watch(inventoryDocumentFormControllerProvider(mode));
    final controller = ref.read(
      inventoryDocumentFormControllerProvider(mode).notifier,
    );

    if (mode == InventoryDocumentFormMode.openingStock) {
      return const SizedBox.shrink();
    }

    if (mode == InventoryDocumentFormMode.stockCount) {
      return Column(
        children: [
          _reasonDropdown(
            label: l10n.inventoryDocumentGainReason,
            value: state.gainReason,
            reasons: state.gainReasons,
            languageCode: locale.languageCode,
            onChanged: controller.setGainReason,
          ),
          const SizedBox(height: 12),
          _reasonDropdown(
            label: l10n.inventoryDocumentLossReason,
            value: state.lossReason,
            reasons: state.lossReasons,
            languageCode: locale.languageCode,
            onChanged: controller.setLossReason,
          ),
        ],
      );
    }

    return _reasonDropdown(
      label: l10n.inventoryDocumentReason,
      value: state.reason,
      reasons: state.reasons,
      languageCode: locale.languageCode,
      onChanged: controller.setReason,
    );
  }

  Widget _reasonDropdown({
    required String label,
    required InventoryAdjustmentReason? value,
    required List<InventoryAdjustmentReason> reasons,
    required String languageCode,
    required ValueChanged<InventoryAdjustmentReason?> onChanged,
  }) {
    return DropdownButtonFormField<InventoryAdjustmentReason>(
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      items: reasons
          .map(
            (reason) => DropdownMenuItem(
              value: reason,
              child: Text(inventoryReasonLabel(reason, languageCode)),
            ),
          )
          .toList(),
      onChanged: onChanged,
    );
  }
}

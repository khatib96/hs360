import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../invoices/presentation/widgets/invoice_design.dart';
import '../../domain/voucher_type.dart';
import '../voucher_form_controller.dart';

class VoucherFormHeader extends ConsumerStatefulWidget {
  const VoucherFormHeader({required this.voucherType, super.key});

  final VoucherType voucherType;

  @override
  ConsumerState<VoucherFormHeader> createState() => _VoucherFormHeaderState();
}

class _VoucherFormHeaderState extends ConsumerState<VoucherFormHeader> {
  late final TextEditingController _amountController;
  late final TextEditingController _notesController;
  late final FocusNode _amountFocusNode;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController();
    _notesController = TextEditingController();
    _amountFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    _amountFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(voucherFormControllerProvider(widget.voucherType));
    final controller = ref.read(
      voucherFormControllerProvider(widget.voucherType).notifier,
    );
    final form = state.form;

    final amountText = form.amount == Decimal.zero
        ? ''
        : form.amount.toString();
    if (!_amountFocusNode.hasFocus && _amountController.text != amountText) {
      _amountController.text = amountText;
    }
    final notesText = form.notes ?? '';
    if (_notesController.text != notesText) {
      _notesController.text = notesText;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 760;
        final fieldWidth = isWide
            ? (constraints.maxWidth - InvoiceDesign.gap) / 2
            : constraints.maxWidth;

        Widget field(Widget child, {double? width}) {
          return SizedBox(width: width ?? fieldWidth, child: child);
        }

        return Wrap(
          spacing: InvoiceDesign.gap,
          runSpacing: InvoiceDesign.gap,
          children: [
            field(
              TextFormField(
                controller: _amountController,
                focusNode: _amountFocusNode,
                decoration: InvoiceDesign.denseField(
                  context,
                  label: l10n.financeColumnAmount,
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textAlign: TextAlign.end,
                onChanged: (value) {
                  final parsed = parseVoucherAmountInput(value);
                  if (parsed != null || value.trim().isEmpty) {
                    controller.setAmount(parsed ?? Decimal.zero);
                  }
                },
              ),
            ),
            field(
              _DateField(
                label: l10n.voucherFormDate,
                value: form.date,
                onPick: controller.setDate,
              ),
            ),
            field(
              TextFormField(
                controller: _notesController,
                decoration: InvoiceDesign.denseField(
                  context,
                  label: l10n.financeColumnDescription,
                ),
                maxLines: 2,
                onChanged: controller.setNotes,
              ),
              width: constraints.maxWidth,
            ),
          ],
        );
      },
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onPick,
  });

  final String label;
  final DateTime value;
  final ValueChanged<DateTime> onPick;

  @override
  Widget build(BuildContext context) {
    final text = MaterialLocalizations.of(context).formatMediumDate(value);

    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value,
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
        );
        if (picked != null) onPick(picked);
      },
      child: InputDecorator(
        decoration: InvoiceDesign.denseField(
          context,
          label: label,
          suffixIcon: const Icon(Icons.calendar_today, size: 18),
        ),
        child: Text(text),
      ),
    );
  }
}

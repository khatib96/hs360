import 'package:flutter/material.dart';

import '../../../invoices/presentation/widgets/invoice_design.dart';
import '../contract_display_helpers.dart';

class ContractDatePickerField extends StatelessWidget {
  const ContractDatePickerField({
    required this.value,
    required this.onPick,
    this.allowClear = false,
    this.firstDate,
    this.lastDate,
    super.key,
  });

  final DateTime? value;
  final ValueChanged<DateTime?> onPick;
  final bool allowClear;
  final DateTime? firstDate;
  final DateTime? lastDate;

  @override
  Widget build(BuildContext context) {
    final display = value == null ? '—' : formatContractDate(value!);
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now(),
          firstDate: firstDate ?? DateTime(2000),
          lastDate: lastDate ?? DateTime(2100),
        );
        if (picked != null) onPick(picked);
      },
      child: InputDecorator(
        decoration: InvoiceDesign.denseField(context),
        child: Row(
          children: [
            Expanded(child: Text(display)),
            if (allowClear && value != null)
              IconButton(
                icon: const Icon(Icons.clear, size: 18),
                onPressed: () => onPick(null),
                visualDensity: VisualDensity.compact,
              ),
            const Icon(Icons.calendar_today, size: 16),
          ],
        ),
      ),
    );
  }
}

class ContractCycleDayPickerField extends StatelessWidget {
  const ContractCycleDayPickerField({
    required this.startDate,
    required this.day,
    required this.onPick,
    super.key,
  });

  final DateTime? startDate;
  final int? day;
  final ValueChanged<DateTime?> onPick;

  @override
  Widget build(BuildContext context) {
    final base = startDate ?? DateTime.now();
    final displayDay = day ?? (base.day > 28 ? 28 : base.day);
    final displayDate = DateTime(base.year, base.month, displayDay);
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: displayDate,
          firstDate: DateTime(base.year - 1),
          lastDate: DateTime(base.year + 1),
        );
        if (picked != null) onPick(picked);
      },
      child: InputDecorator(
        decoration: InvoiceDesign.denseField(context),
        child: Row(
          children: [
            Expanded(child: Text(formatContractDate(displayDate))),
            const Icon(Icons.calendar_today, size: 16),
          ],
        ),
      ),
    );
  }
}

class ContractLabeledField extends StatelessWidget {
  const ContractLabeledField({
    required this.label,
    required this.child,
    super.key,
  });

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: InvoiceDesign.fieldLabelStyle(context)),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

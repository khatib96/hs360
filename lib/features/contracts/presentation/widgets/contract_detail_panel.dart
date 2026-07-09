import 'package:flutter/material.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../invoices/presentation/widgets/invoice_sheet.dart';

class ContractDetailPanel extends StatelessWidget {
  const ContractDetailPanel({
    required this.title,
    required this.child,
    super.key,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return InvoiceSectionCard(title: title, child: child);
  }
}

class ContractInfoRow extends StatelessWidget {
  const ContractInfoRow({required this.label, required this.value, super.key});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 180,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class ContractStatusChip extends StatelessWidget {
  const ContractStatusChip({
    required this.label,
    required this.isClosed,
    super.key,
  });

  final String label;
  final bool isClosed;

  @override
  Widget build(BuildContext context) {
    final color = isClosed
        ? Theme.of(context).colorScheme.outline
        : Theme.of(context).colorScheme.primary;
    return Chip(
      label: Text(label),
      side: BorderSide(color: color.withValues(alpha: 0.4)),
      backgroundColor: color.withValues(alpha: 0.08),
      visualDensity: VisualDensity.compact,
    );
  }
}

String? contractDurationLabel(AppLocalizations l10n, int? months) {
  if (months == null || months <= 0) return null;
  return l10n.contractDurationMonths(months);
}

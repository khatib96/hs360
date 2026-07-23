import 'package:flutter/material.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../invoices/presentation/widgets/invoice_sheet.dart';
import '../../../../shared/widgets/app_detail_surface.dart';
import '../../../../shared/widgets/app_status_badge.dart';

class ContractDetailPanel extends StatelessWidget {
  const ContractDetailPanel({
    required this.title,
    required this.child,
    this.trailing,
    super.key,
  });

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return InvoiceSectionCard(title: title, trailing: trailing, child: child);
  }
}

class ContractInfoRow extends StatelessWidget {
  const ContractInfoRow({required this.label, required this.value, super.key});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return AppInfoRow(label: label, value: Text(value));
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
    return AppStatusBadge(
      label: label,
      tone: isClosed ? AppStatusTone.neutral : AppStatusTone.success,
    );
  }
}

String? contractDurationLabel(AppLocalizations l10n, int? months) {
  if (months == null || months <= 0) return null;
  return l10n.contractDurationMonths(months);
}

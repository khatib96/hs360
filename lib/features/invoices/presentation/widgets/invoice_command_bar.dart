import 'package:flutter/material.dart';

import 'invoice_design.dart';

/// Compact top command bar for invoice document screens (form/detail).
///
/// Title/number + status badge sit at the inline-start; primary/secondary
/// action buttons are grouped at the inline-end. Buttons are never full-width
/// on desktop. On mobile the actions wrap below the title.
class InvoiceCommandBar extends StatelessWidget {
  const InvoiceCommandBar({
    required this.title,
    this.subtitle,
    this.statusBadge,
    this.actions = const [],
    this.progress = false,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget? statusBadge;
  final List<Widget> actions;

  /// Thin progress line shown under the bar (loading/submitting).
  final bool progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDesktop = InvoiceDesign.isDesktop(context);

    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                title,
                style: theme.textTheme.titleLarge,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (statusBadge != null) ...[
              const SizedBox(width: 10),
              statusBadge!,
            ],
          ],
        ),
        if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            subtitle!,
            style: theme.textTheme.bodyMedium,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );

    final actionGroup = Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: actions,
    );

    final Widget bar;
    if (isDesktop) {
      bar = Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(child: titleBlock),
          const SizedBox(width: 16),
          Flexible(
            child: Align(
              alignment: AlignmentDirectional.centerEnd,
              child: actionGroup,
            ),
          ),
        ],
      );
    } else {
      bar = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          titleBlock,
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 12),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: actionGroup,
            ),
          ],
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsetsDirectional.only(
            start: 4,
            end: 4,
            bottom: 14,
          ),
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: InvoiceDesign.borderColor),
            ),
          ),
          child: bar,
        ),
        SizedBox(
          height: 3,
          child: progress
              ? const LinearProgressIndicator(minHeight: 3)
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';

class AppSensitiveActionDialog extends StatelessWidget {
  const AppSensitiveActionDialog({
    required this.title,
    required this.content,
    required this.cancelLabel,
    required this.confirmLabel,
    required this.onCancel,
    required this.onConfirm,
    this.isBusy = false,
    this.isDestructive = true,
    super.key,
  });

  final String title;
  final Widget content;
  final String cancelLabel;
  final String confirmLabel;
  final VoidCallback? onCancel;
  final VoidCallback? onConfirm;
  final bool isBusy;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      icon: Icon(
        isDestructive
            ? Icons.warning_amber_rounded
            : Icons.info_outline_rounded,
        color: isDestructive
            ? theme.colorScheme.error
            : theme.colorScheme.primary,
      ),
      title: Text(title),
      content: FocusTraversalGroup(child: content),
      actions: [
        TextButton(
          onPressed: isBusy ? null : onCancel,
          child: Text(cancelLabel),
        ),
        FilledButton(
          style: isDestructive
              ? FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.error,
                  foregroundColor: theme.colorScheme.onError,
                )
              : null,
          onPressed: isBusy ? null : onConfirm,
          child: isBusy
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(confirmLabel),
        ),
      ],
      actionsPadding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
    );
  }
}

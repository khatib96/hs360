import 'package:flutter/material.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../core/theme/app_tokens.dart';
import 'app_sensitive_action_dialog.dart';

/// Canonical confirmation surface for discard, deactivate, cancel, and
/// reversal-backed lifecycle actions.
Future<String?> showAppLifecycleActionDialog({
  required BuildContext context,
  required String title,
  required String consequence,
  required String confirmLabel,
  String? reasonLabel,
  bool reasonRequired = false,
  bool isDestructive = true,
}) {
  return showDialog<String>(
    context: context,
    builder: (context) => _AppLifecycleActionDialog(
      title: title,
      consequence: consequence,
      confirmLabel: confirmLabel,
      reasonLabel: reasonLabel,
      reasonRequired: reasonRequired,
      isDestructive: isDestructive,
    ),
  );
}

class _AppLifecycleActionDialog extends StatefulWidget {
  const _AppLifecycleActionDialog({
    required this.title,
    required this.consequence,
    required this.confirmLabel,
    required this.reasonLabel,
    required this.reasonRequired,
    required this.isDestructive,
  });

  final String title;
  final String consequence;
  final String confirmLabel;
  final String? reasonLabel;
  final bool reasonRequired;
  final bool isDestructive;

  @override
  State<_AppLifecycleActionDialog> createState() =>
      _AppLifecycleActionDialogState();
}

class _AppLifecycleActionDialogState extends State<_AppLifecycleActionDialog> {
  final _reasonController = TextEditingController();

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final material = MaterialLocalizations.of(context);
    final hasReason = _reasonController.text.trim().isNotEmpty;
    final needsReasonField =
        widget.reasonLabel != null || widget.reasonRequired;

    return AppSensitiveActionDialog(
      title: widget.title,
      cancelLabel: material.cancelButtonLabel,
      confirmLabel: widget.confirmLabel,
      isDestructive: widget.isDestructive,
      onCancel: () => Navigator.pop(context),
      onConfirm: widget.reasonRequired && !hasReason
          ? null
          : () => Navigator.pop(context, _reasonController.text.trim()),
      content: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.lifecycleConsequencesTitle,
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: AppSpacing.xs),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: AppRadii.controlRadius,
                ),
                child: Padding(
                  padding: AppSpacing.cardCompact,
                  child: Text(widget.consequence),
                ),
              ),
              if (needsReasonField) ...[
                const SizedBox(height: AppSpacing.md),
                TextField(
                  key: const Key('lifecycle-action-reason'),
                  controller: _reasonController,
                  autofocus: true,
                  maxLength: 500,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: widget.reasonLabel ?? l10n.lifecycleReasonLabel,
                    helperText: widget.reasonRequired
                        ? l10n.lifecycleReasonRequired
                        : null,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/error_banner.dart';
import '../../data/users_repository.dart';
import '../users_messages.dart';
import 'initial_password_field.dart';

/// Creates a login with an initial password. Returns true when created.
Future<bool?> showCreateUserDialog(
  BuildContext context, {
  required bool canCreateManager,
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _CreateUserDialog(canCreateManager: canCreateManager),
  );
}

class _CreateUserDialog extends ConsumerStatefulWidget {
  const _CreateUserDialog({required this.canCreateManager});

  final bool canCreateManager;

  @override
  ConsumerState<_CreateUserDialog> createState() => _CreateUserDialogState();
}

class _CreateUserDialogState extends ConsumerState<_CreateUserDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _login = TextEditingController();
  final _password = TextEditingController();
  bool _asManager = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _login.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(usersRepositoryProvider)
          .createUser(
            login: _login.text,
            password: _password.text,
            displayName: _name.text,
            asManager: _asManager,
          );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = usersErrorMessage(AppLocalizations.of(context)!, error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.usersCreateTitle),
      content: SizedBox(
        width: 440,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_error != null) ...[
                  ErrorBanner(message: _error!),
                  const SizedBox(height: AppSpacing.sm),
                ],
                AppTextField(
                  key: const Key('create-user-name'),
                  label: l10n.usersDisplayName,
                  controller: _name,
                  textInputAction: TextInputAction.next,
                  validator: (value) => (value?.trim().isEmpty ?? true)
                      ? l10n.usersFieldRequired
                      : null,
                ),
                const SizedBox(height: AppSpacing.sm),
                AppTextField(
                  key: const Key('create-user-login'),
                  label: l10n.usersLoginLabel,
                  helperText: l10n.usersLoginHint,
                  controller: _login,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  validator: (value) => validateLogin(l10n, value),
                ),
                const SizedBox(height: AppSpacing.sm),
                InitialPasswordField(
                  key: const Key('create-user-password'),
                  label: l10n.usersInitialPassword,
                  controller: _password,
                ),
                if (widget.canCreateManager) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    l10n.usersAccountTypeLabel,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  SegmentedButton<bool>(
                    key: const Key('create-user-type'),
                    segments: [
                      ButtonSegment(
                        value: false,
                        label: Text(l10n.usersTypeUser),
                      ),
                      ButtonSegment(
                        value: true,
                        label: Text(l10n.usersTypeManager),
                      ),
                    ],
                    selected: {_asManager},
                    onSelectionChanged: _busy
                        ? null
                        : (value) => setState(() => _asManager = value.first),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          key: const Key('create-user-submit'),
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.usersCreate),
        ),
      ],
    );
  }
}

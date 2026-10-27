import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/error_banner.dart';
import '../../users/data/users_repository.dart';
import '../../users/presentation/users_messages.dart';
import 'auth_controller.dart';
import 'auth_screen_background.dart';

/// Sets a new password for the signed-in user. Required after an admin
/// created the login or reset its password (`must_change_password`).
class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() =>
      _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(usersRepositoryProvider).changeOwnPassword(_password.text);
      await ref.read(authControllerProvider.notifier).refreshSession();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.changePasswordDone)));
      context.go('/');
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = usersErrorMessage(l10n, error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final forced =
        ref.watch(authControllerProvider).valueOrNull?.mustChangePassword ??
        false;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: forced
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                onPressed: () => context.go('/'),
              ),
        actions: [
          if (forced)
            TextButton.icon(
              key: const Key('change-password-sign-out'),
              onPressed: _busy
                  ? null
                  : () async {
                      await ref.read(authControllerProvider.notifier).signOut();
                      if (context.mounted) context.go(AppRoutes.login);
                    },
              icon: const Icon(Icons.logout),
              label: Text(l10n.logout),
            ),
        ],
      ),
      body: AuthScreenBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsetsDirectional.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AppBrandMark(title: l10n.appTitle),
                      const SizedBox(height: 32),
                      Text(
                        l10n.changePasswordTitle,
                        style: theme.textTheme.displaySmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        forced
                            ? l10n.changePasswordForcedSubtitle
                            : l10n.changePasswordSubtitle,
                        style: theme.textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 24),
                      if (_error != null) ...[
                        ErrorBanner(message: _error!),
                        const SizedBox(height: 16),
                      ],
                      AppTextField(
                        key: const Key('change-password-new'),
                        label: l10n.usersNewPassword,
                        controller: _password,
                        obscureText: true,
                        enablePasswordToggle: true,
                        showPasswordLabel: l10n.showPassword,
                        hidePasswordLabel: l10n.hidePassword,
                        autofillHints: const [AutofillHints.newPassword],
                        textInputAction: TextInputAction.next,
                        validator: (value) => validateNewPassword(l10n, value),
                      ),
                      const SizedBox(height: 16),
                      AppTextField(
                        key: const Key('change-password-confirm'),
                        label: l10n.usersConfirmPassword,
                        controller: _confirm,
                        obscureText: true,
                        enablePasswordToggle: true,
                        showPasswordLabel: l10n.showPassword,
                        hidePasswordLabel: l10n.hidePassword,
                        autofillHints: const [AutofillHints.newPassword],
                        onFieldSubmitted: (_) => _submit(),
                        validator: (value) => value == _password.text
                            ? null
                            : l10n.usersPasswordMismatch,
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        height: 44,
                        child: FilledButton(
                          key: const Key('change-password-submit'),
                          style: FilledButton.styleFrom(
                            foregroundColor: AppColors.pureWhite,
                          ),
                          onPressed: _busy ? null : _submit,
                          child: _busy
                              ? const SizedBox.square(
                                  dimension: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.pureWhite,
                                  ),
                                )
                              : Text(l10n.changePasswordSave),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

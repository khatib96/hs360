import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../core/errors/auth_exception.dart';
import '../../../core/network/supabase_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/error_banner.dart';
import '../../../shared/widgets/message_banner.dart';
import 'auth_screen_background.dart';
import 'auth_controller.dart';
import 'auth_error_messages.dart';
import 'login_screen.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  static const routePath = '/forgot-password';
  static const routeName = 'forgotPassword';

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  bool _success = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    final configStatus = ref.read(supabaseConfigStatusProvider);

    setState(() {
      _errorMessage = null;
      _success = false;
    });

    if (configStatus != SupabaseConfigStatus.ready) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      await ref
          .read(authControllerProvider.notifier)
          .requestPasswordReset(email: _emailController.text.trim());
      if (!mounted) return;
      setState(() {
        _success = true;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = authErrorMessage(
          l10n,
          e is AuthException ? e.code : AuthException.unknown,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final configStatus = ref.watch(supabaseConfigStatusProvider);
    final configMessage = supabaseConfigBannerMessage(l10n, configStatus);
    final canSubmit = configStatus == SupabaseConfigStatus.ready && !_isLoading;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: l10n.backToLogin,
          onPressed: () => context.go(LoginScreen.routePath),
        ),
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
                      AppBrandMark(
                        title: l10n.appTitle,
                        brandName: l10n.brandName,
                        tagline: l10n.brandTagline,
                      ),
                      const SizedBox(height: 32),
                      Text(
                        l10n.forgotPasswordTitle,
                        style: theme.textTheme.displaySmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.forgotPasswordSubtitle,
                        style: theme.textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 24),
                      if (configMessage != null) ...[
                        ErrorBanner(message: configMessage),
                        const SizedBox(height: 16),
                      ],
                      if (_errorMessage != null) ...[
                        ErrorBanner(message: _errorMessage!),
                        const SizedBox(height: 16),
                      ],
                      if (_success) ...[
                        MessageBanner(
                          variant: MessageBannerVariant.success,
                          message: l10n.resetPasswordSuccess,
                        ),
                        const SizedBox(height: 16),
                      ],
                      AppTextField(
                        label: l10n.emailLabel,
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.email],
                        onFieldSubmitted: (_) => _submit(),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return l10n.validationEmailRequired;
                          }
                          if (!isValidEmail(value)) {
                            return l10n.validationEmailInvalid;
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        height: 44,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            foregroundColor: AppColors.pureWhite,
                          ),
                          onPressed: canSubmit ? _submit : null,
                          child: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.pureWhite,
                                  ),
                                )
                              : Text(l10n.sendResetLink),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: TextButton(
                          onPressed: () => context.go(LoginScreen.routePath),
                          child: Text(l10n.backToLogin),
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

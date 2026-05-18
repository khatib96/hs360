import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../core/network/supabase_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/error_banner.dart';
import '../../dashboard/presentation/dashboard_screen.dart';
import 'auth_screen_background.dart';
import 'auth_controller.dart';
import 'auth_error_messages.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  static const routePath = '/login';
  static const routeName = 'login';

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _bannerError;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool get _isLoading {
    final auth = ref.watch(authControllerProvider);
    return auth.isLoading;
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    final configStatus = ref.read(supabaseConfigStatusProvider);

    setState(() => _bannerError = null);

    if (!_formKey.currentState!.validate()) return;
    if (configStatus != SupabaseConfigStatus.ready) return;

    await ref
        .read(authControllerProvider.notifier)
        .signIn(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );

    if (!mounted) return;

    final authState = ref.read(authControllerProvider);
    if (authState.hasError) {
      setState(
        () => _bannerError = authErrorMessage(
          l10n,
          authErrorCode(authState.error),
        ),
      );
      return;
    }
    if (authState.valueOrNull != null) {
      context.go(DashboardScreen.routePath);
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
                        l10n.loginTitle,
                        style: theme.textTheme.displaySmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.loginSubtitle,
                        style: theme.textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 24),
                      if (configMessage != null) ...[
                        ErrorBanner(message: configMessage),
                        const SizedBox(height: 16),
                      ],
                      if (_bannerError != null) ...[
                        ErrorBanner(message: _bannerError!),
                        const SizedBox(height: 16),
                      ],
                      AppTextField(
                        label: l10n.emailLabel,
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.email],
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
                      const SizedBox(height: 16),
                      AppTextField(
                        label: l10n.passwordLabel,
                        controller: _passwordController,
                        obscureText: true,
                        enablePasswordToggle: true,
                        showPasswordLabel: l10n.showPassword,
                        hidePasswordLabel: l10n.hidePassword,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.password],
                        onFieldSubmitted: (_) => _submit(),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return l10n.validationPasswordRequired;
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
                              : Text(l10n.signIn),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: TextButton(
                          onPressed: () =>
                              context.push(ForgotPasswordScreen.routePath),
                          child: Text(l10n.forgotPassword),
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

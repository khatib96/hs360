import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../core/routing/app_routes.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../../shared/widgets/message_banner.dart';
import 'auth_screen_background.dart';

/// No reset e-mails are sent: an administrator resets the password and the
/// user chooses a new one at the next sign-in.
class ForgotPasswordScreen extends StatelessWidget {
  const ForgotPasswordScreen({super.key});

  static const routePath = AppRoutes.forgotPassword;
  static const routeName = AppRoutes.forgotPasswordName;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: l10n.backToLogin,
          onPressed: () => context.go(AppRoutes.login),
        ),
      ),
      body: AuthScreenBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsetsDirectional.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppBrandMark(title: l10n.appTitle),
                    const SizedBox(height: 32),
                    Text(
                      l10n.forgotPasswordTitle,
                      style: theme.textTheme.displaySmall,
                    ),
                    const SizedBox(height: 16),
                    MessageBanner(
                      variant: MessageBannerVariant.info,
                      message: l10n.forgotPasswordSubtitle,
                    ),
                    const SizedBox(height: 24),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: TextButton(
                        onPressed: () => context.go(AppRoutes.login),
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
    );
  }
}

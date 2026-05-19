import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../core/routing/app_routes.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../../shared/widgets/message_banner.dart';
import 'widgets/authenticated_user_summary.dart';
import 'widgets/sign_out_icon_button.dart';

class BlockedScreen extends ConsumerWidget {
  const BlockedScreen({super.key});

  static const routePath = AppRoutes.blocked;
  static const routeName = AppRoutes.blockedName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;

    return AppShell(
      title: l10n.blockedTitle,
      actions: const [SignOutIconButton()],
      body: SingleChildScrollView(
        padding: const EdgeInsetsDirectional.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MessageBanner(
              variant: MessageBannerVariant.info,
              message: l10n.blockedMessage,
            ),
            const SizedBox(height: 24),
            const AuthenticatedUserSummary(),
          ],
        ),
      ),
    );
  }
}

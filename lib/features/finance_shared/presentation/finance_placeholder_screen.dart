import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../core/routing/app_routes.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../auth/domain/app_session.dart';
import '../../auth/presentation/auth_controller.dart';

typedef FinanceL10nGetter = String Function(AppLocalizations l10n);

class FinancePlaceholderScreen extends ConsumerWidget {
  const FinancePlaceholderScreen({
    required this.titleGetter,
    required this.bodyGetter,
    required this.canView,
    this.currentRoute,
    this.showBackButton = false,
    this.fallbackRoute = AppRoutes.dashboard,
    this.referenceId,
    super.key,
  });

  final FinanceL10nGetter titleGetter;
  final FinanceL10nGetter bodyGetter;
  final bool Function(AppSession session) canView;
  final String? currentRoute;
  final bool showBackButton;
  final String fallbackRoute;
  final String? referenceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final session = ref.watch(authControllerProvider).valueOrNull;
    final title = titleGetter(l10n);
    final allowed = session != null && canView(session);

    return AppShell(
      title: title,
      currentRoute: currentRoute,
      body: SingleChildScrollView(
        padding: const EdgeInsetsDirectional.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showBackButton) ...[
              BackButton(
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go(_fallbackRoute(ref, fallbackRoute));
                  }
                },
              ),
              const SizedBox(height: 12),
            ],
            Text(title, style: theme.textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(
              allowed ? bodyGetter(l10n) : l10n.financeModuleAccessUnavailable,
              style: theme.textTheme.bodyMedium,
            ),
            if (referenceId != null && referenceId!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(referenceId!, style: theme.textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );
  }
}

String _fallbackRoute(WidgetRef ref, String preferred) {
  final session = ref.read(authControllerProvider).valueOrNull;
  if (session == null) return AppRoutes.login;
  return preferred;
}

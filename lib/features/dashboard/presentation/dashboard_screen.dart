import 'package:flutter/material.dart';
import 'package:hs360/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/localization/locale_controller.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../auth/presentation/auth_error_messages.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  static const routePath = AppRoutes.dashboard;
  static const routeName = AppRoutes.dashboardName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final locale = ref.watch(localeProvider);

    return AppShell(
      title: l10n.dashboard,
      actions: [
        IconButton(
          tooltip: l10n.logout,
          icon: const Icon(LucideIcons.logOut),
          onPressed: () async {
            await ref.read(authControllerProvider.notifier).signOut();
            if (!context.mounted) return;

            final authState = ref.read(authControllerProvider);
            if (authState.hasError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    authErrorMessage(l10n, authErrorCode(authState.error)),
                  ),
                ),
              );
              return;
            }
            context.go(AppRoutes.login);
          },
        ),
        Padding(
          padding: const EdgeInsetsDirectional.only(end: 8),
          child: _LanguageMenu(
            label: l10n.language,
            locale: locale,
            onChanged: (next) => ref.read(localeProvider.notifier).state = next,
          ),
        ),
      ],
      body: Padding(
        padding: const EdgeInsetsDirectional.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppBrandMark(title: l10n.appTitle),
            const SizedBox(height: 24),
            Text(
              l10n.appTitle,
              style: Theme.of(context).textTheme.displaySmall,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.phaseZeroReady,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.offWhite,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.neutral200),
              ),
              child: Padding(
                padding: const EdgeInsetsDirectional.all(16),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        locale.languageCode == 'ar'
                            ? l10n.uiDirectionRtl
                            : l10n.uiDirectionLtr,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LanguageMenu extends StatelessWidget {
  const _LanguageMenu({
    required this.label,
    required this.locale,
    required this.onChanged,
  });

  final String label;
  final Locale locale;
  final ValueChanged<Locale> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return PopupMenuButton<Locale>(
      tooltip: label,
      initialValue: locale,
      onSelected: onChanged,
      itemBuilder: (context) => [
        PopupMenuItem(
          value: const Locale('ar'),
          child: Text(l10n.languageArabic),
        ),
        PopupMenuItem(
          value: const Locale('en'),
          child: Text(l10n.languageEnglish),
        ),
      ],
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.language),
          const SizedBox(width: 4),
          Text(label),
          const Icon(Icons.arrow_drop_down),
        ],
      ),
    );
  }
}

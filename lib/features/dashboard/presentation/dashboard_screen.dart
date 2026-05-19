import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../core/localization/locale_controller.dart';
import '../../../core/routing/app_routes.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../auth/presentation/widgets/authenticated_user_summary.dart';
import '../../auth/presentation/widgets/sign_out_icon_button.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  static const routePath = AppRoutes.dashboard;
  static const routeName = AppRoutes.dashboardName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final locale = ref.watch(localeProvider);
    final theme = Theme.of(context);

    return AppShell(
      title: l10n.dashboard,
      actions: [
        const SignOutIconButton(),
        Padding(
          padding: const EdgeInsetsDirectional.only(end: 8),
          child: _LanguageMenu(
            label: l10n.language,
            locale: locale,
            onChanged: (next) =>
                ref.read(localeControllerProvider.notifier).setLocale(next),
          ),
        ),
      ],
      body: SingleChildScrollView(
        padding: const EdgeInsetsDirectional.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppBrandMark(title: l10n.appTitle),
            const SizedBox(height: 24),
            Text(l10n.appTitle, style: theme.textTheme.displaySmall),
            const SizedBox(height: 8),
            Text(
              l10n.dashboardPhase2Subtitle,
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            const AuthenticatedUserSummary(),
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

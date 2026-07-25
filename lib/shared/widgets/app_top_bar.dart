import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../core/localization/locale_controller.dart';
import '../../core/routing/app_navigation.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_tokens.dart';
import '../../features/auth/domain/app_session.dart';

class AppTopBar extends ConsumerWidget implements PreferredSizeWidget {
  const AppTopBar({
    required this.title,
    required this.module,
    required this.session,
    this.leading,
    this.featureActions,
    super.key,
  });

  final String title;
  final AppNavigationModule? module;
  final AppSession session;
  final Widget? leading;
  final List<Widget>? featureActions;

  @override
  Size get preferredSize => const Size.fromHeight(68);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final locale = ref.watch(localeProvider);
    final compact = MediaQuery.sizeOf(context).width <= 768;
    final showSearch = canShowGlobalSearchAnchor(session);
    final showQuickCreate = canShowQuickCreateAnchor(session);
    final showNotifications = canShowNotificationsAnchor(session);
    final hasGlobalActions = showSearch || showQuickCreate || showNotifications;

    return AppBar(
      toolbarHeight: preferredSize.height,
      leading: leading,
      titleSpacing: leading == null ? AppSpacing.md : 0,
      title: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (module != null)
            Text(
              module!.label(l10n),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: AppColors.neutral600),
            ),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ],
      ),
      actions: [
        ...?featureActions,
        if (compact && hasGlobalActions)
          _GlobalActionsMenu(
            showSearch: showSearch,
            showQuickCreate: showQuickCreate,
            showNotifications: showNotifications,
          )
        else ...[
          if (showSearch)
            IconButton(
              key: const Key('shell-search-anchor'),
              tooltip: l10n.shellGlobalSearch,
              onPressed: null,
              icon: const Icon(Icons.search),
            ),
          if (showQuickCreate)
            IconButton(
              key: const Key('shell-quick-create-anchor'),
              tooltip: l10n.shellQuickCreate,
              onPressed: null,
              icon: const Icon(Icons.add_circle_outline),
            ),
          if (showNotifications)
            IconButton(
              key: const Key('shell-notifications-anchor'),
              tooltip: l10n.shellNotifications,
              onPressed: null,
              icon: const Icon(Icons.notifications_none),
            ),
        ],
        PopupMenuButton<Locale>(
          key: const Key('shell-locale-menu'),
          tooltip: l10n.language,
          initialValue: locale,
          onSelected: (next) =>
              ref.read(localeControllerProvider.notifier).setLocale(next),
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
          icon: const Icon(Icons.language),
        ),
        const SizedBox(width: AppSpacing.xs),
      ],
    );
  }
}

class _GlobalActionsMenu extends StatelessWidget {
  const _GlobalActionsMenu({
    required this.showSearch,
    required this.showQuickCreate,
    required this.showNotifications,
  });

  final bool showSearch;
  final bool showQuickCreate;
  final bool showNotifications;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return PopupMenuButton<void>(
      key: const Key('shell-global-actions-menu'),
      tooltip: l10n.shellGlobalActions,
      itemBuilder: (context) => [
        if (showSearch)
          PopupMenuItem(
            enabled: false,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.search),
              title: Text(l10n.shellGlobalSearch),
            ),
          ),
        if (showQuickCreate)
          PopupMenuItem(
            enabled: false,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.add_circle_outline),
              title: Text(l10n.shellQuickCreate),
            ),
          ),
        if (showNotifications)
          PopupMenuItem(
            enabled: false,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.notifications_none),
              title: Text(l10n.shellNotifications),
            ),
          ),
      ],
      icon: const Icon(Icons.more_vert),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../core/routing/app_navigation.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_tokens.dart';
import '../../features/auth/domain/app_session.dart';
import 'app_brand_mark.dart';
import 'app_user_card.dart';

class AppSidebar extends StatelessWidget {
  const AppSidebar({
    required this.session,
    required this.activeModule,
    required this.collapsed,
    required this.onToggleCollapsed,
    super.key,
  });

  static const expandedWidth = 240.0;
  static const collapsedWidth = 64.0;

  final AppSession session;
  final AppNavigationModule? activeModule;
  final bool collapsed;
  final VoidCallback onToggleCollapsed;

  @override
  Widget build(BuildContext context) {
    final primary = visibleNavigationModules(
      session,
      area: AppNavigationArea.primary,
    );
    final system = visibleNavigationModules(
      session,
      area: AppNavigationArea.system,
    );

    return AnimatedContainer(
      key: const Key('app-sidebar'),
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      width: collapsed ? collapsedWidth : expandedWidth,
      color: AppColors.offWhite,
      child: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: collapsed ? 76 : 104,
              child: Padding(
                padding: EdgeInsetsDirectional.symmetric(
                  horizontal: collapsed ? 10 : 18,
                  vertical: collapsed ? 12 : 8,
                ),
                child: collapsed
                    ? const Center(child: AppCompactBrand())
                    : const AppSidebarBrand(),
              ),
            ),
            const Divider(height: 1, color: AppColors.neutral100),
            Expanded(
              child: ListView(
                padding: const EdgeInsetsDirectional.symmetric(vertical: 10),
                children: [
                  for (final module in primary)
                    _ModuleTile(
                      module: module,
                      session: session,
                      active: module.id == activeModule?.id,
                      collapsed: collapsed,
                    ),
                ],
              ),
            ),
            if (system.isNotEmpty) ...[
              const Divider(height: 1, color: AppColors.neutral100),
              for (final module in system)
                _ModuleTile(
                  module: module,
                  session: session,
                  active: module.id == activeModule?.id,
                  collapsed: collapsed,
                ),
            ],
            const Divider(height: 1, color: AppColors.neutral100),
            AppUserCard(session: session, collapsed: collapsed),
            _CollapseButton(collapsed: collapsed, onPressed: onToggleCollapsed),
          ],
        ),
      ),
    );
  }
}

class AppNavigationDrawer extends StatelessWidget {
  const AppNavigationDrawer({
    required this.session,
    required this.activeModule,
    super.key,
  });

  final AppSession session;
  final AppNavigationModule? activeModule;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final primary = visibleNavigationModules(
      session,
      area: AppNavigationArea.primary,
    );
    final system = visibleNavigationModules(
      session,
      area: AppNavigationArea.system,
    );
    return Drawer(
      key: const Key('app-navigation-drawer'),
      backgroundColor: AppColors.offWhite,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: AppBrandMark(title: l10n.appTitle, width: 170),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsetsDirectional.symmetric(vertical: 10),
                children: [
                  for (final module in primary)
                    _ModuleTile(
                      module: module,
                      session: session,
                      active: module.id == activeModule?.id,
                      collapsed: false,
                      closeDrawer: true,
                    ),
                  if (system.isNotEmpty) ...[
                    const Padding(
                      padding: EdgeInsetsDirectional.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.xs,
                      ),
                      child: Divider(),
                    ),
                    for (final module in system)
                      _ModuleTile(
                        module: module,
                        session: session,
                        active: module.id == activeModule?.id,
                        collapsed: false,
                        closeDrawer: true,
                      ),
                  ],
                ],
              ),
            ),
            const Divider(height: 1),
            AppUserCard(session: session),
          ],
        ),
      ),
    );
  }
}

class _ModuleTile extends StatelessWidget {
  const _ModuleTile({
    required this.module,
    required this.session,
    required this.active,
    required this.collapsed,
    this.closeDrawer = false,
  });

  final AppNavigationModule module;
  final AppSession session;
  final bool active;
  final bool collapsed;
  final bool closeDrawer;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final label = module.label(l10n);
    final foreground = active ? AppColors.charcoal : AppColors.neutral600;
    final tile = Material(
      color: active ? AppColors.goldSoft : Colors.transparent,
      borderRadius: AppRadii.controlRadius,
      child: InkWell(
        key: Key('shell-module-${module.id.name}'),
        borderRadius: AppRadii.controlRadius,
        onTap: () {
          if (closeDrawer) Navigator.pop(context);
          context.go(module.landingRoute(session));
        },
        child: SizedBox(
          height: 44,
          child: Row(
            mainAxisAlignment: collapsed
                ? MainAxisAlignment.center
                : MainAxisAlignment.start,
            children: [
              SizedBox(
                width: collapsed ? 44 : 46,
                child: Icon(module.icon, color: foreground, size: 21),
              ),
              if (!collapsed)
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: foreground,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
              if (!collapsed) const SizedBox(width: AppSpacing.xs),
            ],
          ),
        ),
      ),
    );

    return Padding(
      padding: EdgeInsetsDirectional.symmetric(
        horizontal: collapsed ? 10 : 12,
        vertical: 3,
      ),
      child: collapsed ? Tooltip(message: label, child: tile) : tile,
    );
  }
}

class _CollapseButton extends StatelessWidget {
  const _CollapseButton({required this.collapsed, required this.onPressed});

  final bool collapsed;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final tooltip = collapsed
        ? l10n.shellExpandSidebar
        : l10n.shellCollapseSidebar;
    final icon = collapsed
        ? (rtl ? Icons.chevron_left : Icons.chevron_right)
        : (rtl ? Icons.chevron_right : Icons.chevron_left);
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(8, 0, 8, 8),
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          key: const Key('shell-sidebar-toggle'),
          borderRadius: AppRadii.controlRadius,
          onTap: onPressed,
          child: SizedBox(
            height: 40,
            child: Row(
              mainAxisAlignment: collapsed
                  ? MainAxisAlignment.center
                  : MainAxisAlignment.start,
              children: [
                SizedBox(width: 44, child: Icon(icon, size: AppSizes.icon)),
                if (!collapsed)
                  Expanded(
                    child: Text(
                      tooltip,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

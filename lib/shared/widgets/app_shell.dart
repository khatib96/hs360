import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/routing/app_navigation.dart';
import '../../core/theme/app_theme.dart';
import '../../features/auth/domain/app_session.dart';
import '../../features/auth/presentation/auth_controller.dart';
import 'app_contextual_navigation.dart';
import 'app_shell_controller.dart';
import 'app_sidebar.dart';
import 'app_top_bar.dart';

export 'app_brand_mark.dart';

class AppShell extends ConsumerWidget {
  const AppShell({
    required this.title,
    required this.body,
    this.actions,
    this.currentRoute,
    this.floatingActionButton,
    super.key,
  });

  final String title;
  final Widget body;
  final List<Widget>? actions;
  final String? currentRoute;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authControllerProvider).valueOrNull;
    if (session == null) {
      return Scaffold(
        appBar: AppBar(title: Text(title), actions: actions),
        body: SafeArea(child: body),
        floatingActionButton: floatingActionButton,
      );
    }

    final actualUri = _routerUri(context);
    final navigationUri = actualUri.path.isEmpty
        ? Uri(path: currentRoute ?? '')
        : actualUri;
    final module = resolveNavigationModule(
      navigationUri,
      session,
      hintedPath: currentRoute,
    );
    final destination = resolveNavigationDestination(
      navigationUri,
      session,
      module,
      hintedPath: currentRoute,
    );
    final showBack = shouldShowShellBackButton(navigationUri, destination);
    final backTarget = shellBackTarget(navigationUri, session, module);
    final leading = showBack
        ? BackButton(
            key: const Key('shell-back-button'),
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go(backTarget);
              }
            },
          )
        : null;
    final isDesktop = MediaQuery.sizeOf(context).width > 768;

    if (!isDesktop) {
      return Scaffold(
        appBar: AppTopBar(
          title: title,
          module: module,
          session: session,
          leading: leading,
          featureActions: actions,
        ),
        drawer: showBack
            ? null
            : AppNavigationDrawer(session: session, activeModule: module),
        body: SafeArea(
          child: _ShellContent(
            module: module,
            destination: destination,
            session: session,
            body: body,
          ),
        ),
        floatingActionButton: floatingActionButton,
      );
    }

    final collapsed = ref.watch(appSidebarCollapsedProvider);
    return Scaffold(
      body: Row(
        children: [
          AppSidebar(
            session: session,
            activeModule: module,
            collapsed: collapsed,
            onToggleCollapsed: () {
              ref.read(appSidebarCollapsedProvider.notifier).state = !collapsed;
            },
          ),
          const VerticalDivider(width: 1, color: AppColors.neutral200),
          Expanded(
            child: Scaffold(
              appBar: AppTopBar(
                title: title,
                module: module,
                session: session,
                leading: leading,
                featureActions: actions,
              ),
              body: SafeArea(
                child: _ShellContent(
                  module: module,
                  destination: destination,
                  session: session,
                  body: body,
                ),
              ),
              floatingActionButton: floatingActionButton,
            ),
          ),
        ],
      ),
    );
  }
}

class _ShellContent extends StatelessWidget {
  const _ShellContent({
    required this.module,
    required this.destination,
    required this.session,
    required this.body,
  });

  final AppNavigationModule? module;
  final AppNavigationDestination? destination;
  final AppSession session;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (module != null)
          AppContextualNavigation(
            module: module!,
            activeDestination: destination,
            session: session,
          ),
        Expanded(child: body),
      ],
    );
  }
}

Uri _routerUri(BuildContext context) {
  try {
    return GoRouterState.of(context).uri;
  } catch (_) {
    return Uri();
  }
}

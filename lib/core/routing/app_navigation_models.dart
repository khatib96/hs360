import 'package:flutter/material.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../features/auth/domain/app_session.dart';

typedef NavigationLabel = String Function(AppLocalizations l10n);
typedef NavigationVisibility = bool Function(AppSession session);

enum AppModuleId {
  dashboard,
  dailyActivity,
  appointments,
  contracts,
  parties,
  finance,
  inventory,
  settings,
}

enum AppNavigationArea { primary, system }

@immutable
class AppNavigationDestination {
  const AppNavigationDestination({
    required this.id,
    required this.label,
    required this.icon,
    required this.route,
    required this.isVisible,
    this.matchChildren = false,
    this.additionalPrefixes = const [],
  });

  final String id;
  final NavigationLabel label;
  final IconData icon;
  final String route;
  final NavigationVisibility isVisible;
  final bool matchChildren;
  final List<String> additionalPrefixes;

  bool matches(String path) {
    if (path == route) return true;
    if (matchChildren && path.startsWith('$route/')) return true;
    return additionalPrefixes.any(path.startsWith);
  }
}

@immutable
class AppNavigationModule {
  const AppNavigationModule({
    required this.id,
    required this.label,
    required this.icon,
    required this.destinations,
    this.area = AppNavigationArea.primary,
  });

  final AppModuleId id;
  final NavigationLabel label;
  final IconData icon;
  final List<AppNavigationDestination> destinations;
  final AppNavigationArea area;

  List<AppNavigationDestination> visibleDestinations(AppSession session) {
    return destinations
        .where((destination) => destination.isVisible(session))
        .toList(growable: false);
  }

  bool isVisible(AppSession session) => visibleDestinations(session).isNotEmpty;

  String landingRoute(AppSession session) =>
      visibleDestinations(session).first.route;
}

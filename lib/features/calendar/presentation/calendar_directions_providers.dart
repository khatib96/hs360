import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'calendar_directions_launcher.dart';
import 'calendar_map_app_resolver.dart';

/// Override in tests to stub [CalendarMapAppResolver.canLaunch].
final calendarMapAppResolverProvider = Provider<CalendarMapAppResolver>(
  (ref) => const CalendarMapAppResolver(),
);

/// Override in tests to stub URI launches without opening external apps.
final calendarDirectionsLauncherProvider = Provider<CalendarDirectionsLauncher>(
  (ref) => const CalendarDirectionsLauncher(),
);

import 'package:flutter/foundation.dart' show TargetPlatform;

/// One chooser row in the in-app "Open with" sheet (Phase 7 M10 corrective).
enum CalendarMapAppKind { appleMaps, googleMaps, waze, systemMaps, browser }

/// A launchable maps option with a pre-built [uri] (never auto-launched).
class CalendarMapAppOption {
  const CalendarMapAppOption({
    required this.kind,
    required this.uri,
    required this.platform,
  });

  final CalendarMapAppKind kind;
  final Uri uri;
  final TargetPlatform platform;

  String get debugLabel => kind.name;
}

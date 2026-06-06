import 'package:hs360/l10n/app_localizations.dart';

import '../domain/service_location_coordinates.dart';

String coordinateResolutionSourceLabel(
  AppLocalizations l10n,
  CoordinateResolutionSource source,
) {
  return switch (source) {
    CoordinateResolutionSource.mapPick =>
      l10n.serviceLocationCoordinateSourceMapPick,
    CoordinateResolutionSource.deviceGps =>
      l10n.serviceLocationCoordinateSourceDeviceGps,
    CoordinateResolutionSource.url => l10n.serviceLocationCoordinateSourceUrl,
    CoordinateResolutionSource.manual =>
      l10n.serviceLocationCoordinateSourceManual,
  };
}

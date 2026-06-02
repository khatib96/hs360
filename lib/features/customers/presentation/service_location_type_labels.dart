import 'package:hs360/l10n/app_localizations.dart';

import '../domain/service_location_type.dart';

String serviceLocationTypeLabel(
  AppLocalizations l10n,
  ServiceLocationType type,
) {
  return switch (type) {
    ServiceLocationType.branch => l10n.serviceLocationTypeBranch,
    ServiceLocationType.office => l10n.serviceLocationTypeOffice,
    ServiceLocationType.warehouse => l10n.serviceLocationTypeWarehouse,
    ServiceLocationType.home => l10n.serviceLocationTypeHome,
    ServiceLocationType.installationSite =>
      l10n.serviceLocationTypeInstallationSite,
    ServiceLocationType.other => l10n.serviceLocationTypeOther,
  };
}

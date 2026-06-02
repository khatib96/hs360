/// Service location kind from [service_location_type] enum.
enum ServiceLocationType {
  branch,
  office,
  warehouse,
  home,
  installationSite,
  other;

  String toDb() => switch (this) {
        ServiceLocationType.branch => 'branch',
        ServiceLocationType.office => 'office',
        ServiceLocationType.warehouse => 'warehouse',
        ServiceLocationType.home => 'home',
        ServiceLocationType.installationSite => 'installation_site',
        ServiceLocationType.other => 'other',
      };

  static ServiceLocationType fromDb(String? value) {
    return switch (value) {
      'office' => ServiceLocationType.office,
      'warehouse' => ServiceLocationType.warehouse,
      'home' => ServiceLocationType.home,
      'installation_site' => ServiceLocationType.installationSite,
      'other' => ServiceLocationType.other,
      _ => ServiceLocationType.branch,
    };
  }
}

enum CoordinateResolutionSource {
  mapPick,
  deviceGps,
  url,
  manual;

  String toDb() {
    return switch (this) {
      CoordinateResolutionSource.mapPick => 'map_pick',
      CoordinateResolutionSource.deviceGps => 'device_gps',
      CoordinateResolutionSource.url => 'url',
      CoordinateResolutionSource.manual => 'manual',
    };
  }

  static CoordinateResolutionSource? fromDb(String? value) {
    return switch (value) {
      'map_pick' => CoordinateResolutionSource.mapPick,
      'device_gps' => CoordinateResolutionSource.deviceGps,
      'url' => CoordinateResolutionSource.url,
      'manual' => CoordinateResolutionSource.manual,
      _ => null,
    };
  }
}

enum CoordinateResolutionStatus {
  resolved,
  pending,
  failed;

  String toDb() => name;

  static CoordinateResolutionStatus? fromDb(String? value) {
    return switch (value) {
      'resolved' => CoordinateResolutionStatus.resolved,
      'pending' => CoordinateResolutionStatus.pending,
      'failed' => CoordinateResolutionStatus.failed,
      _ => null,
    };
  }
}

class CapturedServiceLocationCoordinates {
  const CapturedServiceLocationCoordinates({
    required this.latitude,
    required this.longitude,
    required this.accuracyM,
    required this.capturedAt,
  });

  final double latitude;
  final double longitude;
  final double accuracyM;
  final DateTime capturedAt;
}

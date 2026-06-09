/// Locked golden comparison constants (M3 plan §11.3).
abstract final class GoldenPolicy {
  static const int dpi = 150;

  /// Pixel differs when any RGBA channel delta exceeds this value.
  static const int channelDeltaTolerance = 1;

  /// Maximum allowed different-pixel percentage.
  static const double maxDifferentPixelPercent = 0.5;

  static const int a4WidthPx = 1240;
  static const int a4HeightPx = 1754;

  static const int thermalWidthPx = 472;

  static const int labelWidthPx = 295;
  static const int labelHeightPx = 177;

  static int thermalHeightPx(double thermalHeightMm) {
    return (thermalHeightMm / 25.4 * dpi).round();
  }

  static int mmToPx(double mm) => (mm / 25.4 * dpi).round();
}

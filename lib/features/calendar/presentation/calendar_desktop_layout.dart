/// Calendar layout breakpoints (Phase 7 M6 desktop + M9 mobile).
///
/// Calendar mobile vs desktop is decided from the **calendar content width**
/// reported by [LayoutBuilder] inside AppShell chrome — never from raw window
/// width alone. AppShell keeps its own independent chrome rule
/// (`window width > 768` ⇒ desktop nav) and must not import this type.
///
/// Content rules (inclusive mobile at the breakpoint):
/// - content ≤ [mobileBreakpoint] → mobile calendar
/// - content > [mobileBreakpoint] → desktop calendar
///
/// Typical pairings with AppShell (`> 768` ⇒ desktop shell):
/// - window 767 → mobile shell + mobile calendar
/// - window 768 → mobile shell + mobile calendar
/// - window 769 → desktop shell + mobile calendar (content ≈ 528)
/// - window ≳ 1009 → desktop shell + desktop calendar (content ≥ 769)
abstract final class CalendarLayout {
  /// Content width at or below this uses the mobile calendar presentation.
  static const double mobileBreakpoint = 768;

  /// Desktop content width at or above this = normal desktop density.
  static const double narrowBreakpoint = 1100;

  /// Non-scrolling slot under the mobile list for the create FAB
  /// (FAB 56 + outer margins; keeps the control fully outside the list).
  static const double mobileFabClearance = 88;

  /// Mobile calendar when [contentWidth] is at most [mobileBreakpoint].
  static bool isMobileWidth(double contentWidth) =>
      contentWidth <= mobileBreakpoint;

  static bool isDesktopWidth(double contentWidth) =>
      !isMobileWidth(contentWidth);

  /// Narrow desktop density for content strictly above mobile and below
  /// [narrowBreakpoint].
  static bool isNarrowDesktopWidth(double contentWidth) =>
      contentWidth > mobileBreakpoint && contentWidth < narrowBreakpoint;
}

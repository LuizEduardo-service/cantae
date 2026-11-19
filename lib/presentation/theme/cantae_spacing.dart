/// Spacing scale from `docs/design/DESIGN_SYSTEM.md` §4. Base unit: 4 pt.
abstract final class CantaeSpacing {
  static const double space1 = 4;
  static const double space2 = 8;
  static const double space3 = 12;
  static const double space4 = 16;
  static const double space5 = 20;
  static const double space6 = 24;
  static const double safeTop = 52;
  static const double safeBottom = 28;
}

/// Corner radii from `docs/design/DESIGN_SYSTEM.md` §5.
abstract final class CantaeRadii {
  static const double radiusXs = 6;
  static const double radiusSegment = 9;
  static const double radiusSm = 12;
  static const double radiusMd = 14;
  static const double radiusLg = 16;
  static const double radiusXl = 20;
  static const double radiusSheet = 28;

  /// §5: "altura ÷ 2" — pill radius is relational to the control's own height,
  /// not a fixed value, so it is a function rather than a constant.
  static double radiusPill(double height) => height / 2;
}

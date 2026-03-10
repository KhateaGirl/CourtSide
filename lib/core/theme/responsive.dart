import 'package:flutter/material.dart';

/// Breakpoints for mobile-first responsive layout.
class Responsive {
  Responsive._();

  /// Narrow phone: single column, stacked controls.
  static const double narrow = 400;

  /// Tablet / wide phone: 2-column where applicable.
  static const double tablet = 600;

  /// Desktop: side-by-side, full layout.
  static const double desktop = 900;

  static bool isNarrow(BuildContext context) =>
      MediaQuery.sizeOf(context).width < narrow;

  static bool isTabletOrWider(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= tablet;

  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= desktop;

  static double width(BuildContext context) => MediaQuery.sizeOf(context).width;
}

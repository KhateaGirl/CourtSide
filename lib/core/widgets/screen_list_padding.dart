import 'package:flutter/material.dart';

import '../theme/app_design_system.dart';
import '../theme/responsive.dart';

/// Responsive horizontal and vertical padding for list content on screens.
/// Use for consistent layout readability (narrow = sm, wide = md).
class ScreenListPadding extends StatelessWidget {
  const ScreenListPadding({
    super.key,
    required this.child,
    this.horizontal,
    this.vertical,
  });

  final Widget child;
  final double? horizontal;
  final double? vertical;

  @override
  Widget build(BuildContext context) {
    final isNarrow = Responsive.isNarrow(context);
    final h = horizontal ?? (isNarrow ? AppSpacing.sm : AppSpacing.md);
    final v = vertical ?? AppSpacing.sm;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: h, vertical: v),
      child: child,
    );
  }
}

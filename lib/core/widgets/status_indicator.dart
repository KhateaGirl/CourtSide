import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radius.dart';

/// Vertical bar showing reservation status color. Use as ListTile leading.
class StatusIndicator extends StatelessWidget {
  const StatusIndicator({
    super.key,
    required this.status,
    this.width = 4,
    this.height = 48,
  });

  final String status;
  final double width;
  final double height;

  static Color colorFor(String status) {
    switch (status.toUpperCase()) {
      case 'PENDING':
        return AppColors.pending;
      case 'APPROVED':
        return AppColors.approved;
      case 'CANCELLED':
      case 'REJECTED':
        return AppColors.cancelled;
      default:
        return AppColors.neutral600;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: colorFor(status),
        borderRadius: AppRadius.radiusXs,
      ),
    );
  }
}

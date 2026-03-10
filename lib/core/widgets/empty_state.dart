import 'package:flutter/material.dart';

import '../theme/app_design_system.dart';

/// Shown when a list or data set is empty. Icon + title + optional subtitle.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.iconSize = 64,
    this.iconColor,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final double iconSize;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final color = iconColor ?? AppColors.neutral400;
    return Center(
      child: Padding(
        padding: AppSpacing.paddingLg,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: iconSize, color: color),
            SizedBox(height: AppSpacing.md),
            Text(
              title,
              style: AppTypography.titleMedium.copyWith(
                color: AppColors.neutral700,
              ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null && subtitle!.isNotEmpty) ...[
              SizedBox(height: AppSpacing.sm),
              Text(
                subtitle!,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.neutral500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

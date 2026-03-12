import 'package:flutter/material.dart';

import '../theme/app_design_system.dart';

/// Reusable card row for a reservation: title, subtitle, optional leading, trailing actions.
/// Use in admin and schedule screens for consistent layout.
class ReservationListCard extends StatelessWidget {
  const ReservationListCard({
    super.key,
    required this.title,
    required this.subtitle,
    this.leading,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget? leading;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: ListTile(
        leading: leading,
        title: Text(
          title,
          style: AppTypography.titleMedium,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          subtitle,
          style: AppTypography.bodySmall,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: trailing,
      ),
    );
  }
}

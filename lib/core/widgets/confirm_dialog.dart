import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_design_system.dart';
import '../theme/responsive.dart';
import 'glass_card.dart';

/// Great-looking confirmation modal for add / update / delete / submit.
/// Returns true if user confirmed, false if cancelled.
class ConfirmDialog extends StatelessWidget {
  const ConfirmDialog({
    super.key,
    required this.title,
    this.message,
    this.confirmLabel = 'Confirm',
    this.cancelLabel = 'Cancel',
    this.isDanger = false,
    this.icon,
  });

  final String title;
  final String? message;
  final String confirmLabel;
  final String cancelLabel;
  final bool isDanger;
  final IconData? icon;

  /// Show the dialog. Returns true if confirmed, false otherwise.
  static Future<bool> show(
    BuildContext context, {
    required String title,
    String? message,
    String confirmLabel = 'Confirm',
    String cancelLabel = 'Cancel',
    bool isDanger = false,
    IconData? icon,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => ConfirmDialog(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        isDanger: isDanger,
        icon: icon,
      ),
    );
    return result == true;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = isDanger ? AppColors.rejected : (isDark ? AppColors.cyan400 : AppColors.blue600);
    final defaultIcon = isDanger ? Icons.warning_amber_rounded : Icons.help_outline_rounded;

    // Web/tablet: cap width and shrink padding/icon. Mobile: full width with margin.
    final width = MediaQuery.sizeOf(context).width;
    final isCompact = Responsive.isTabletOrWider(context);
    final maxW = isCompact ? 420.0 : width - 48;
    final padding = isCompact ? AppSpacing.md : 24.0;
    final iconSize = isCompact ? 40.0 : 48.0;
    final horizontalMargin = isCompact ? 48.0 : 24.0;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: EdgeInsets.symmetric(horizontal: horizontalMargin),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxW),
        child: GlassCard(
          padding: EdgeInsets.all(padding),
          margin: EdgeInsets.zero,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon ?? defaultIcon,
                size: iconSize,
                color: accentColor,
              ),
              SizedBox(height: isCompact ? AppSpacing.sm : AppSpacing.md),
              Text(
                title,
                style: AppTypography.titleLarge.copyWith(
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.neutral900Dark : AppColors.neutral900,
                  fontSize: isCompact ? 20 : null,
                ),
                textAlign: TextAlign.center,
              ),
              if (message != null && message!.isNotEmpty) ...[
                SizedBox(height: isCompact ? AppSpacing.xs : AppSpacing.sm),
                Text(
                  message!,
                  style: AppTypography.bodyMedium.copyWith(
                    color: isDark ? AppColors.neutral800Dark : AppColors.neutral700,
                    fontSize: isCompact ? 14 : null,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              SizedBox(height: isCompact ? AppSpacing.md : AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: Text(cancelLabel),
                    ),
                  ),
                  SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: FilledButton.styleFrom(
                        backgroundColor: isDanger ? AppColors.rejected : null,
                      ),
                      child: Text(confirmLabel),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../../core/theme/app_design_system.dart';
import '../../data/reservation_change_request_model.dart';

/// Full-detail modal for a reservation change request: court, date, original vs proposed time, admin message, Accept/Reject.
class ReservationChangeModal extends StatelessWidget {
  const ReservationChangeModal({
    super.key,
    required this.request,
    this.courtName,
    this.reservationDate,
    required this.onAccept,
    required this.onReject,
  });

  final ReservationChangeRequest request;
  final String? courtName;
  final DateTime? reservationDate;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  static Future<void> show(
    BuildContext context, {
    required ReservationChangeRequest request,
    String? courtName,
    DateTime? reservationDate,
    required VoidCallback onAccept,
    required VoidCallback onReject,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => ReservationChangeModal(
        request: request,
        courtName: courtName,
        reservationDate: reservationDate,
        onAccept: () {
          Navigator.pop(ctx);
          onAccept();
        },
        onReject: () {
          Navigator.pop(ctx);
          onReject();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = request;
    final expired = r.isExpired || r.expiresAt.isBefore(DateTime.now());
    final remaining = r.expiresAt.difference(DateTime.now());
    final countdown = expired
        ? 'Change request expired'
        : 'Expires in: ${remaining.inHours}h ${remaining.inMinutes % 60}m';

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.sm,
        right: AppSpacing.sm,
        top: AppSpacing.sm,
        bottom: MediaQuery.of(context).viewPadding.bottom + AppSpacing.sm,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Reservation Change Request',
            style: AppTypography.titleLarge,
          ),
          const SizedBox(height: AppSpacing.sm),
          if (courtName != null)
            Text('Court: $courtName', style: AppTypography.bodyMedium),
          if (reservationDate != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Date: ${reservationDate!.year}-${reservationDate!.month.toString().padLeft(2, '0')}-${reservationDate!.day.toString().padLeft(2, '0')}',
              style: AppTypography.bodyMedium,
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Original time: ${r.oldStartTime} – ${r.oldEndTime}',
            style: AppTypography.bodyMedium,
          ),
          Text(
            'Proposed time: ${r.newStartTime} – ${r.newEndTime}',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.blue600,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (r.message != null && r.message!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Message from Admin:',
              style: AppTypography.labelMedium,
            ),
            Text(
              r.message!,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.neutral600,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Text(
            countdown,
            style: AppTypography.bodySmall.copyWith(
              color: expired ? AppColors.rejected : AppColors.neutral600,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: expired ? null : onReject,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.rejected,
                  ),
                  child: const Text('Reject Change'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: ElevatedButton(
                  onPressed: expired ? null : onAccept,
                  child: const Text('Accept Change'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

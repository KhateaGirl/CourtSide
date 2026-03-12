import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_design_system.dart';
import '../../../reservation_change/data/reservation_change_request_model.dart';
import '../../data/notification_model.dart';

/// Reusable card for a single notification. Handles reservation_change_request (Accept/Reject), admin-edit (Get it / Cancel), and mark read.
class NotificationCard extends StatelessWidget {
  const NotificationCard({
    super.key,
    required this.notification,
    required this.onCancel,
    required this.onGetIt,
    required this.onMarkRead,
    this.changeRequest,
    this.changeRequestLoading = false,
    this.onAccept,
    this.onReject,
  });

  final AppNotification notification;
  final VoidCallback onCancel;
  final VoidCallback onGetIt;
  final VoidCallback onMarkRead;
  final ReservationChangeRequest? changeRequest;
  final bool changeRequestLoading;
  final VoidCallback? onAccept;
  final VoidCallback? onReject;

  @override
  Widget build(BuildContext context) {
    final n = notification;
    final isChangeRequest = n.type == 'reservation_change_request' &&
        n.changeRequestId != null &&
        !n.isRead;
    final isAdminEdit = n.type == 'RESERVATION_ADMIN_EDIT' &&
        !n.isRead &&
        n.reservationId != null;

    Widget trailing;
    if (isChangeRequest && changeRequestLoading) {
      trailing = const SizedBox(
        height: 24,
        width: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    } else if (isChangeRequest && changeRequest != null && onAccept != null && onReject != null) {
      final req = changeRequest!;
      final expired = req.isExpired || req.expiresAt.isBefore(DateTime.now());
      trailing = Wrap(
        spacing: AppSpacing.xs,
        children: [
          if (expired)
            Text(
              'Change request expired',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.rejected,
                fontStyle: FontStyle.italic,
              ),
            )
          else ...[
            TextButton(
              onPressed: onReject,
              child: const Text(
                'Reject',
                style: TextStyle(color: AppColors.rejected),
              ),
            ),
            ElevatedButton(
              onPressed: onAccept,
              child: const Text('Accept'),
            ),
          ],
        ],
      );
    } else if (isAdminEdit) {
      trailing = Wrap(
        spacing: AppSpacing.xs,
        children: [
          TextButton(
            onPressed: onCancel,
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.rejected),
            ),
          ),
          ElevatedButton(
            onPressed: onGetIt,
            child: const Text('Get it'),
          ),
        ],
      );
    } else {
      trailing = n.isRead
          ? Icon(Icons.done, color: AppColors.approved)
          : TextButton(
              onPressed: onMarkRead,
              child: const Text('Mark read'),
            );
    }

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              n.title,
              style: AppTypography.titleMedium,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              n.message,
              style: AppTypography.bodySmall,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            if (isChangeRequest && changeRequest != null) ...[
              const SizedBox(height: AppSpacing.sm),
              _ChangeRequestDetails(
                courtName: n.courtName ?? 'Court',
                request: changeRequest!,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Reject = decline the change (your reservation stays as is).',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.neutral600,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            if (isAdminEdit) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Get it = agree to reschedule. Cancel = decline.',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.neutral600,
                  fontStyle: FontStyle.italic,
                ),
                maxLines: 2,
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            const SizedBox(height: AppSpacing.xs),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [trailing],
            ),
          ],
        ),
      ),
    );
  }
}

/// Details (court, old/new time) and countdown for a change request.
class _ChangeRequestDetails extends StatefulWidget {
  const _ChangeRequestDetails({
    required this.courtName,
    required this.request,
  });

  final String courtName;
  final ReservationChangeRequest request;

  @override
  State<_ChangeRequestDetails> createState() => _ChangeRequestDetailsState();
}

class _ChangeRequestDetailsState extends State<_ChangeRequestDetails> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.request;
    final expired = r.isExpired || r.expiresAt.isBefore(DateTime.now());
    final remaining = r.expiresAt.difference(DateTime.now());

    String countdownText;
    if (expired) {
      countdownText = 'Change request expired';
    } else if (remaining.inHours >= 1) {
      countdownText = 'Expires in: ${remaining.inHours}h ${remaining.inMinutes % 60}m';
    } else if (remaining.inMinutes >= 1) {
      countdownText = 'Expires in: ${remaining.inMinutes}m';
    } else {
      countdownText = 'Expires very soon';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Court: ${widget.courtName}',
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.neutral600,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Old Time: ${r.oldStartTime} – ${r.oldEndTime}',
          style: AppTypography.bodySmall,
        ),
        Text(
          'New Time: ${r.newStartTime} – ${r.newEndTime}',
          style: AppTypography.bodySmall,
        ),
        if (r.message != null && r.message!.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Message from Admin: ${r.message}',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.neutral600,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.xs),
        Text(
          countdownText,
          style: AppTypography.bodySmall.copyWith(
            color: expired ? AppColors.rejected : AppColors.neutral600,
            fontWeight: expired ? FontWeight.w600 : null,
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Business logic for when and what to notify. Inserts go to notifications table.
/// Per spec: notifications for reservation_created, reservation_approved, reservation_rejected, etc.
class NotificationService {
  final SupabaseClient _client;

  NotificationService(this._client);

  /// After a reservation is created (player or admin).
  /// RPC/notif disabled – manual notif page only.
  Future<void> notifyReservationCreated({
    required String userId,
    required bool createAsAdmin,
  }) async {
    // await _client.from('notifications').insert({
    //   'user_id': userId,
    //   'title': 'Reservation created',
    //   'message': createAsAdmin
    //       ? 'Admin reservation created. You can edit it in Admin.'
    //       : 'Your reservation is pending approval.',
    // });
  }

  /// After user reschedules an approved reservation (needs re-approval).
  /// RPC/notif disabled – manual notif page only.
  Future<void> notifyRescheduleSubmitted({
    required String userId,
  }) async {
    // await _client.from('notifications').insert({
    //   'user_id': userId,
    //   'title': 'Reschedule submitted',
    //   'message':
    //       'Your change requires admin approval again. You will be notified when it is reviewed.',
    // });
  }

  /// After admin edits a user's reservation; user can Get it or Cancel.
  /// RPC/notif disabled – manual notif page only.
  Future<void> notifyAdminEdit({
    required String userId,
    required String reservationId,
  }) async {
    // await _client.from('notifications').insert({
    //   'user_id': userId,
    //   'title': 'Reservation rescheduled by admin',
    //   'message':
    //       'An admin rescheduled your reservation. Open Notifications and tap Get it to agree or Cancel to decline.',
    //   'type': 'RESERVATION_ADMIN_EDIT',
    //   'reservation_id': reservationId,
    // });
  }

  /// When admin creates a reservation change request. Player sees it in Notifications with Accept/Reject.
  Future<void> notifyReservationChangeRequest({
    required String userId,
    required String reservationId,
    required String changeRequestId,
    required String courtName,
    required String oldStartTime,
    required String oldEndTime,
    required String newStartTime,
    required String newEndTime,
    String? message,
  }) async {
    final body = message != null && message.isNotEmpty
        ? 'Admin requested a new schedule. Message: $message'
        : 'Admin requested to change your reservation schedule.';
    final payload = {
      'user_id': userId,
      'title': 'Reservation Change Request',
      'message': body,
      'type': 'reservation_change_request',
      'reservation_id': reservationId,
      'change_request_id': changeRequestId,
      'court_name': courtName,
    };
    try {
      await _client.from('notifications').insert(payload);
      debugPrint('[CourtSide] Notification inserted: reservation_change_request for user $userId');
    } catch (e, st) {
      debugPrint('[CourtSide] Notification insert failed: $e');
      debugPrint('[CourtSide] Stack: $st');
      rethrow;
    }
  }
}

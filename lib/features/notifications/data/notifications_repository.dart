import 'package:supabase_flutter/supabase_flutter.dart';

import 'notification_model.dart';

class NotificationsRepository {
  final SupabaseClient _client;

  NotificationsRepository(this._client);

  Future<List<AppNotification>> getMyNotifications() async {
    final uid = _client.auth.currentUser!.id;
    final res = await _client
        .from('notifications')
        .select()
        .eq('user_id', uid)
        .order('created_at', ascending: false);
    return (res as List)
        .map((e) => AppNotification.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> markAsRead(String id) async {
    await _client
        .from('notifications')
        .update({'is_read': true}).eq('id', id);
  }

  /// Handle a reservation edit proposed by admin.
  /// If [accept] is true, reservation becomes APPROVED; otherwise it is CANCELLED.
  /// In both cases the notification is marked as read.
  Future<void> handleAdminEditDecision({
    required String notificationId,
    required String reservationId,
    required bool accept,
  }) async {
    final status = accept ? 'APPROVED' : 'CANCELLED';
    await _client.from('reservations').update({
      'status': status,
    }).eq('id', reservationId);

    await _client
        .from('notifications')
        .update({'is_read': true}).eq('id', notificationId);
  }

  RealtimeChannel subscribeToNotifications(void Function() onChange) {
    final userId = _client.auth.currentUser!.id;
    final channel = _client
        .channel('public:notifications:user_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) => onChange(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) => onChange(),
        )
        .subscribe();
    return channel;
  }
}


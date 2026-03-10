import 'package:supabase_flutter/supabase_flutter.dart';

import 'reservation_model.dart';

class ReservationsRepository {
  final SupabaseClient _client;

  ReservationsRepository(this._client);

  /// Normalize time for RPC (PostgreSQL time): "HH:mm" or "HH:mm:ss" -> "HH:mm:00" so PostgREST accepts it.
  static String _normalizeTimeForRpc(String t) {
    final s = t.trim();
    if (s.length == 5 && s[2] == ':') return '$s:00'; // HH:mm -> HH:mm:00
    return s;
  }

  Future<List<Reservation>> getMyReservations() async {
    final res = await _client
        .from('reservations')
        .select()
        .order('date', ascending: false)
        .order('start_time', ascending: false);
    return (res as List)
        .map((e) => Reservation.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<Reservation>> getCourtReservations(
    String courtId,
    DateTime day,
  ) async {
    final res = await _client
        .from('reservations')
        .select()
        .eq('court_id', courtId)
        .eq('date', day.toIso8601String().substring(0, 10))
        .order('start_time');
    return (res as List)
        .map((e) => Reservation.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  /// Fetches occupied time ranges for a court/date (for availability). Uses RPC so players can see slots.
  Future<List<({String start, String end})>> getOccupiedSlots(
    String courtId,
    DateTime day,
  ) async {
    final res = await _client.rpc(
      'get_occupied_slots',
      params: {
        'p_court_id': courtId,
        'p_date': day.toIso8601String().substring(0, 10),
      },
    );
    if (res == null) return [];
    return (res as List)
        .map((e) {
          final m = e as Map<String, dynamic>;
          final start = m['start_time'] as String? ?? '';
          final end = m['end_time'] as String? ?? '';
          return (start: start.length >= 5 ? start.substring(0, 5) : start, end: end.length >= 5 ? end.substring(0, 5) : end);
        })
        .toList();
  }

  /// Creates a reservation via direct Supabase (no Edge Function), avoiding gateway 401/JWT issues.
  /// With one court, courtId should be the single venue; categoryId is the activity category (Basketball, Volleyball, etc.).
  /// When [createAsAdmin] is true, status is set to 'ADMIN' (admin-created; admin can edit it later).
  Future<Reservation> createReservation({
    required String courtId,
    required String? categoryId,
    required DateTime date,
    required String startTime,
    required String endTime,
    required String eventType,
    required int playersCount,
    bool createAsAdmin = false,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw AuthException('Not signed in. Please log in again.');
    }

    final dateStr = date.toIso8601String().substring(0, 10);

    final overlapRes = await _client.rpc(
      'check_reservation_overlap',
      params: {
        'p_court_id': courtId,
        'p_date': dateStr,
        'p_start': _normalizeTimeForRpc(startTime),
        'p_end': _normalizeTimeForRpc(endTime),
      },
    );
    if (overlapRes == null) {
      throw Exception('Could not check availability');
    }
    if (overlapRes != true) {
      throw Exception('Time slot already booked');
    }

    final priceRes = await _client.rpc(
      'calculate_booking_price',
      params: {
        'p_date': dateStr,
        'p_start': startTime,
        'p_end': endTime,
      },
    );
    final price = (priceRes is num) ? priceRes : 0.0;

    final status = createAsAdmin ? 'ADMIN' : 'PENDING';
    final insertPayload = <String, dynamic>{
      'user_id': userId,
      'court_id': courtId,
      'date': dateStr,
      'start_time': startTime,
      'end_time': endTime,
      'event_type': eventType,
      'players_count': playersCount,
      'price': price,
      'status': status,
    };
    if (categoryId != null) insertPayload['category_id'] = categoryId;

    final insertRes = await _client
        .from('reservations')
        .insert(insertPayload)
        .select()
        .single();

    final reservation = Reservation.fromMap(insertRes);

    await _client.from('notifications').insert({
      'user_id': userId,
      'title': 'Reservation created',
      'message': createAsAdmin
          ? 'Admin reservation created. You can edit it in Admin.'
          : 'Your reservation is pending approval.',
    });

    return reservation;
  }

  Future<void> cancelReservation(String id) async {
    await _client
        .from('reservations')
        .update({'status': 'CANCELLED'}).eq('id', id);
  }

  /// Updates reservation details. When [currentStatus] is APPROVED, also sets status to PENDING
  /// and inserts a notification so admin must re-approve (reschedule-after-approval flow).
  /// [courtId] is required to validate the new slot does not overlap others (current reservation excluded).
  Future<void> updateReservation({
    required String id,
    required String courtId,
    required DateTime date,
    required String startTime,
    required String endTime,
    required String eventType,
    required int playersCount,
    String? currentStatus,
  }) async {
    final dateStr = date.toIso8601String().substring(0, 10);
    final overlapRes = await _client.rpc(
      'check_reservation_overlap',
      params: {
        'p_court_id': courtId,
        'p_date': dateStr,
        'p_start': _normalizeTimeForRpc(startTime),
        'p_end': _normalizeTimeForRpc(endTime),
        'p_exclude_reservation_id': id,
      },
    );
    if (overlapRes == null) {
      throw Exception('Could not check availability');
    }
    if (overlapRes != true) {
      throw Exception('Time slot already booked');
    }

    final payload = <String, dynamic>{
      'date': dateStr,
      'start_time': startTime,
      'end_time': endTime,
      'event_type': eventType,
      'players_count': playersCount,
    };
    final wasApproved = currentStatus?.toUpperCase() == 'APPROVED';
    if (wasApproved) {
      payload['status'] = 'PENDING';
    }
    await _client.from('reservations').update(payload).eq('id', id);

    if (wasApproved) {
      final userId = _client.auth.currentUser?.id;
      if (userId != null) {
        await _client.from('notifications').insert({
          'user_id': userId,
          'title': 'Reschedule submitted',
          'message': 'Your change requires admin approval again. You will be notified when it is reviewed.',
        });
      }
    }
  }

  RealtimeChannel subscribeToMyReservationsChanges(void Function() onChange) {
    final userId = _client.auth.currentUser!.id;
    final channel = _client
        .channel('public:reservations:user_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'reservations',
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
          table: 'reservations',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) => onChange(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'reservations',
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


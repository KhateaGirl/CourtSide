import 'package:supabase_flutter/supabase_flutter.dart';

import 'reservation_model.dart';

class ReservationsRepository {
  final SupabaseClient _client;

  ReservationsRepository(this._client);

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

  Future<Reservation> createReservation({
    required String courtId,
    required DateTime date,
    required String startTime,
    required String endTime,
    required String eventType,
    required int playersCount,
  }) async {
    final res = await _client.functions.invoke(
      'create_reservation',
      body: {
        'court_id': courtId,
        'date': date.toIso8601String().substring(0, 10),
        'start_time': startTime,
        'end_time': endTime,
        'event_type': eventType,
        'players_count': playersCount,
      },
    );

    final data = (res.data as Map<String, dynamic>)['reservation']
        as Map<String, dynamic>;
    return Reservation.fromMap(data);
  }

  Future<void> cancelReservation(String id) async {
    await _client
        .from('reservations')
        .update({'status': 'CANCELLED'}).eq('id', id);
  }

  Future<void> updateReservation({
    required String id,
    required DateTime date,
    required String startTime,
    required String endTime,
    required String eventType,
    required int playersCount,
  }) async {
    await _client.from('reservations').update({
      'date': date.toIso8601String().substring(0, 10),
      'start_time': startTime,
      'end_time': endTime,
      'event_type': eventType,
      'players_count': playersCount,
    }).eq('id', id);
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
        .subscribe();
    return channel;
  }
}


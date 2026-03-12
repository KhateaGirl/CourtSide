import 'package:supabase_flutter/supabase_flutter.dart';

import 'reservation_change_request_model.dart';

class ReservationChangeRequestsRepository {
  final SupabaseClient _client;

  ReservationChangeRequestsRepository(this._client);

  /// Create a change request. Caller must be admin. Enforces one PENDING per reservation via unique index.
  Future<ReservationChangeRequest> create({
    required String reservationId,
    required String playerId,
    required String adminId,
    required String oldStartTime,
    required String oldEndTime,
    required String newStartTime,
    required String newEndTime,
    String? message,
    required DateTime expiresAt,
  }) async {
    final norm = _normTime;
    final res = await _client
        .from('reservation_change_requests')
        .insert({
          'reservation_id': reservationId,
          'player_id': playerId,
          'admin_id': adminId,
          'old_start_time': norm(oldStartTime),
          'old_end_time': norm(oldEndTime),
          'new_start_time': norm(newStartTime),
          'new_end_time': norm(newEndTime),
          'message': message,
          'status': 'PENDING',
          'expires_at': expiresAt.toUtc().toIso8601String(),
        })
        .select()
        .single();
    return ReservationChangeRequest.fromMap(res as Map<String, dynamic>);
  }

  static String _normTime(String t) {
    final s = t.trim();
    if (s.length == 5 && s[2] == ':') return '$s:00';
    return s;
  }

  /// Get the single PENDING request for a reservation, if any.
  Future<ReservationChangeRequest?> getPendingByReservation(String reservationId) async {
    final res = await _client
        .from('reservation_change_requests')
        .select()
        .eq('reservation_id', reservationId)
        .eq('status', 'PENDING')
        .maybeSingle();
    if (res == null) return null;
    return ReservationChangeRequest.fromMap(res as Map<String, dynamic>);
  }

  Future<ReservationChangeRequest?> getById(String id) async {
    final res = await _client
        .from('reservation_change_requests')
        .select()
        .eq('id', id)
        .maybeSingle();
    if (res == null) return null;
    return ReservationChangeRequest.fromMap(res as Map<String, dynamic>);
  }

  /// All change requests for the current user (player).
  Future<List<ReservationChangeRequest>> getByPlayerId(String playerId) async {
    final res = await _client
        .from('reservation_change_requests')
        .select()
        .eq('player_id', playerId)
        .order('created_at', ascending: false);
    return (res as List)
        .map((e) => ReservationChangeRequest.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  /// PENDING requests for the current user (for banner on reservation cards).
  /// First marks as EXPIRED any PENDING requests past expires_at, then returns current PENDING list.
  Future<List<ReservationChangeRequest>> getPendingByPlayerId(String playerId) async {
    await expirePendingWhereExpired();
    final res = await _client
        .from('reservation_change_requests')
        .select()
        .eq('player_id', playerId)
        .eq('status', 'PENDING');
    return (res as List)
        .map((e) => ReservationChangeRequest.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  /// Set status to ACCEPTED or REJECTED. Allowed only when current status is PENDING.
  Future<void> updateStatus(String id, String status) async {
    await _client
        .from('reservation_change_requests')
        .update({'status': status})
        .eq('id', id)
        .eq('status', 'PENDING');
  }

  /// Mark PENDING requests as EXPIRED where expires_at < now. Returns count updated.
  Future<int> expirePendingWhereExpired() async {
    final now = DateTime.now().toUtc().toIso8601String();
    final res = await _client
        .from('reservation_change_requests')
        .update({'status': 'EXPIRED'})
        .eq('status', 'PENDING')
        .lt('expires_at', now)
        .select('id');
    return (res as List).length;
  }
}

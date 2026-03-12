/// Normalize time from DB ("HH:mm" or "HH:mm:ss") to "HH:mm".
String _timeToHhMm(dynamic v) {
  if (v == null) return '--:--';
  final s = v.toString().trim();
  if (s.length >= 5) return s.substring(0, 5);
  return s;
}

class ReservationChangeRequest {
  final String id;
  final String reservationId;
  final String playerId;
  final String adminId;
  final String oldStartTime;
  final String oldEndTime;
  final String newStartTime;
  final String newEndTime;
  final String? message;
  final String status;
  final DateTime expiresAt;
  final DateTime createdAt;

  ReservationChangeRequest({
    required this.id,
    required this.reservationId,
    required this.playerId,
    required this.adminId,
    required this.oldStartTime,
    required this.oldEndTime,
    required this.newStartTime,
    required this.newEndTime,
    this.message,
    required this.status,
    required this.expiresAt,
    required this.createdAt,
  });

  factory ReservationChangeRequest.fromMap(Map<String, dynamic> map) {
    return ReservationChangeRequest(
      id: map['id'] as String,
      reservationId: map['reservation_id'] as String,
      playerId: map['player_id'] as String,
      adminId: map['admin_id'] as String,
      oldStartTime: _timeToHhMm(map['old_start_time']),
      oldEndTime: _timeToHhMm(map['old_end_time']),
      newStartTime: _timeToHhMm(map['new_start_time']),
      newEndTime: _timeToHhMm(map['new_end_time']),
      message: map['message'] as String?,
      status: map['status'] as String,
      expiresAt: DateTime.parse(map['expires_at'] as String),
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  bool get isPending => status == 'PENDING';
  bool get isExpired => status == 'EXPIRED';
}

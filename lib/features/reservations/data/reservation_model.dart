class Reservation {
  final String id;
  final String courtId;
  final String userId;
  final String eventType;
  final int playersCount;
  final DateTime date;
  final String status;
  final double price;
  final String startTime;
  final String endTime;

  Reservation({
    required this.id,
    required this.courtId,
    required this.userId,
    required this.eventType,
    required this.playersCount,
    required this.date,
    required this.status,
    required this.price,
    required this.startTime,
    required this.endTime,
  });

  factory Reservation.fromMap(Map<String, dynamic> map) => Reservation(
        id: map['id'] as String,
        courtId: map['court_id'] as String,
        userId: map['user_id'] as String,
        eventType: map['event_type'] as String,
        playersCount: map['players_count'] as int,
        date: DateTime.parse(map['date'] as String),
        status: map['status'] as String,
        price: (map['price'] as num).toDouble(),
        startTime: map['start_time'] as String,
        endTime: map['end_time'] as String,
      );
}


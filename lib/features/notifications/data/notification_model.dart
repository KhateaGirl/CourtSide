class AppNotification {
  final String id;
  final String title;
  final String message;
  final bool isRead;
  final DateTime createdAt;
  final String? type;
  final String? reservationId;
  final String? changeRequestId;
  final String? courtName;

  AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.isRead,
    required this.createdAt,
    this.type,
    this.reservationId,
    this.changeRequestId,
    this.courtName,
  });

  factory AppNotification.fromMap(Map<String, dynamic> map) => AppNotification(
        id: map['id'] as String,
        title: map['title'] as String,
        message: map['message'] as String,
        isRead: map['is_read'] as bool,
        createdAt: DateTime.parse(map['created_at'] as String),
        type: map['type'] as String?,
        reservationId: map['reservation_id'] as String?,
        changeRequestId: map['change_request_id'] as String?,
        courtName: map['court_name'] as String?,
      );
}


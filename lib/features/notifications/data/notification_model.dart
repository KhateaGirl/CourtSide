class AppNotification {
  final String id;
  final String title;
  final String message;
  final bool isRead;
  final DateTime createdAt;

  AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.isRead,
    required this.createdAt,
  });

  factory AppNotification.fromMap(Map<String, dynamic> map) => AppNotification(
        id: map['id'] as String,
        title: map['title'] as String,
        message: map['message'] as String,
        isRead: map['is_read'] as bool,
        createdAt: DateTime.parse(map['created_at'] as String),
      );
}


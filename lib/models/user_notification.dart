class UserNotification {
  final String id;
  final String title;
  final String body;
  final DateTime timestamp;
  final bool isRead;
  final String type; // 'welcome', 'system', 'digest', 'streak', 'download'
  final String? bookId;

  const UserNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.timestamp,
    this.isRead = false,
    this.type = 'system',
    this.bookId,
  });

  UserNotification copyWith({
    String? id,
    String? title,
    String? body,
    DateTime? timestamp,
    bool? isRead,
    String? type,
    String? bookId,
  }) {
    return UserNotification(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      type: type ?? this.type,
      bookId: bookId ?? this.bookId,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'timestamp': timestamp.toIso8601String(),
      'isRead': isRead,
      'type': type,
      'bookId': bookId,
    };
  }

  factory UserNotification.fromJson(Map<String, dynamic> json) {
    return UserNotification(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'] as String) ?? DateTime.now()
          : DateTime.now(),
      isRead: json['isRead'] as bool? ?? false,
      type: json['type'] as String? ?? 'system',
      bookId: json['bookId'] as String?,
    );
  }
}

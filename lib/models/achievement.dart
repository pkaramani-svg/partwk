import '../core/utils/safe_parser.dart';

class Achievement {
  final String id;
  final Map<String, String> title;
  final Map<String, String> description;
  final String badgeIcon; // Icon key or image path
  final DateTime? unlockedAt;

  Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.badgeIcon,
    this.unlockedAt,
  });

  String getTitle(String langCode) => title[langCode] ?? title['en'] ?? '';
  String getDescription(String langCode) => description[langCode] ?? description['en'] ?? '';
  bool get isUnlocked => unlockedAt != null;

  factory Achievement.fromMap(String id, Map<String, dynamic> data, {DateTime? unlockedAt}) {
    return Achievement(
      id: id,
      title: SafeParser.asMapStringString(data['title']),
      description: SafeParser.asMapStringString(data['description']),
      badgeIcon: data['badgeIcon'] ?? 'emoji_events',
      unlockedAt: unlockedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'badgeIcon': badgeIcon,
    };
  }
}

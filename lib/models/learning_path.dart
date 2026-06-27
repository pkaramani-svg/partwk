import '../core/utils/safe_parser.dart';

class LearningPath {
  final String id;
  final Map<String, String> title;
  final Map<String, String> description;
  final List<String> bookIds;
  final String category;

  LearningPath({
    required this.id,
    required this.title,
    required this.description,
    required this.bookIds,
    required this.category,
  });

  String getTitle(String langCode) => title[langCode] ?? title['en'] ?? '';
  String getDescription(String langCode) => description[langCode] ?? description['en'] ?? '';

  factory LearningPath.fromMap(String id, Map<String, dynamic> data) {
    return LearningPath(
      id: id,
      title: SafeParser.asMapStringString(data['title']),
      description: SafeParser.asMapStringString(data['description']),
      bookIds: SafeParser.asListString(data['bookIds']),
      category: data['category'] ?? 'General',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'bookIds': bookIds,
      'category': category,
    };
  }
}

import '../core/utils/safe_parser.dart';

class Category {
  final String id;
  // Localized names
  final Map<String, String> name;
  final String iconName; // e.g., 'business', 'psychology', 'science'

  Category({
    required this.id,
    required this.name,
    required this.iconName,
  });

  String getName(String langCode) => name[langCode] ?? name['en'] ?? '';

  factory Category.fromMap(String id, Map<String, dynamic> data) {
    return Category(
      id: id,
      name: SafeParser.asMapStringString(data['name']),
      iconName: data['iconName'] ?? 'book',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'iconName': iconName,
    };
  }
}

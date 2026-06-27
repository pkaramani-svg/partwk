class Highlight {
  final String id;
  final String userId;
  final String bookId;
  final String bookTitle;
  final String text;
  final int colorValue; // Hex integer value of highlight color
  final DateTime createdAt;

  Highlight({
    required this.id,
    required this.userId,
    required this.bookId,
    required this.bookTitle,
    required this.text,
    required this.colorValue,
    required this.createdAt,
  });

  factory Highlight.fromMap(String id, Map<String, dynamic> data) {
    return Highlight(
      id: id,
      userId: data['userId'] ?? '',
      bookId: data['bookId'] ?? '',
      bookTitle: data['bookTitle'] ?? '',
      text: data['text'] ?? '',
      colorValue: data['colorValue'] ?? 0xFFFFEB3B, // Default yellow
      createdAt: data['createdAt'] != null ? DateTime.parse(data['createdAt']) : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'bookId': bookId,
      'bookTitle': bookTitle,
      'text': text,
      'colorValue': colorValue,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}

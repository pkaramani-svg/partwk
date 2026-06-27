class Flashcard {
  final String id;
  final String bookId;
  final String langCode;
  final String front;
  final String back;

  Flashcard({
    required this.id,
    required this.bookId,
    required this.langCode,
    required this.front,
    required this.back,
  });

  factory Flashcard.fromMap(String id, Map<String, dynamic> data) {
    return Flashcard(
      id: id,
      bookId: data['bookId'] ?? '',
      langCode: data['langCode'] ?? 'en',
      front: data['front'] ?? '',
      back: data['back'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'bookId': bookId,
      'langCode': langCode,
      'front': front,
      'back': back,
    };
  }
}

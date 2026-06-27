class Note {
  final String id;
  final String userId;
  final String bookId;
  final String bookTitle;
  final String noteText;
  final DateTime createdAt;

  Note({
    required this.id,
    required this.userId,
    required this.bookId,
    required this.bookTitle,
    required this.noteText,
    required this.createdAt,
  });

  factory Note.fromMap(String id, Map<String, dynamic> data) {
    return Note(
      id: id,
      userId: data['userId'] ?? '',
      bookId: data['bookId'] ?? '',
      bookTitle: data['bookTitle'] ?? '',
      noteText: data['noteText'] ?? '',
      createdAt: data['createdAt'] != null ? DateTime.parse(data['createdAt']) : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'bookId': bookId,
      'bookTitle': bookTitle,
      'noteText': noteText,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}

class Quiz {
  final String id;
  final String bookId;
  final String langCode;
  final List<QuizQuestion> questions;

  Quiz({
    required this.id,
    required this.bookId,
    required this.langCode,
    required this.questions,
  });

  factory Quiz.fromMap(String id, Map<String, dynamic> data) {
    return Quiz(
      id: id,
      bookId: data['bookId'] ?? '',
      langCode: data['langCode'] ?? 'en',
      questions: (data['questions'] as List?)
              ?.map((e) => QuizQuestion.fromMap(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'bookId': bookId,
      'langCode': langCode,
      'questions': questions.map((e) => e.toMap()).toList(),
    };
  }
}

class QuizQuestion {
  final String questionText;
  final List<String> choices;
  final int correctOptionIndex;

  QuizQuestion({
    required this.questionText,
    required this.choices,
    required this.correctOptionIndex,
  });

  factory QuizQuestion.fromMap(Map<String, dynamic> data) {
    return QuizQuestion(
      questionText: data['questionText'] ?? '',
      choices: List<String>.from(data['choices'] ?? []),
      correctOptionIndex: data['correctOptionIndex'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'questionText': questionText,
      'choices': choices,
      'correctOptionIndex': correctOptionIndex,
    };
  }
}

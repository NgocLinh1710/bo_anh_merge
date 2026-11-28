enum QuizAnswerResult { correct, incorrect, locked }

class QuizAnswer {
  final DateTime? date;
  final int? optionIndex;

  const QuizAnswer.date(this.date) : optionIndex = null;
  const QuizAnswer.option(this.optionIndex) : date = null;
}

class CollectionQuiz {
  final String question;
  final DateTime? correctDate;
  final List<String> options;
  final int? correctOptionIndex;

  const CollectionQuiz.date({required this.question, required this.correctDate})
    : options = const [],
      correctOptionIndex = null;

  const CollectionQuiz.choice({
    required this.question,
    required this.options,
    required this.correctOptionIndex,
  }) : correctDate = null;

  bool get isDateQuestion => correctDate != null;

  bool isValidAnswer(QuizAnswer answer) => isDateQuestion
      ? answer.date != null &&
            answer.date!.year == 2026 &&
            answer.optionIndex == null
      : answer.date == null &&
            answer.optionIndex != null &&
            answer.optionIndex! >= 0 &&
            answer.optionIndex! < options.length;

  bool isCorrect(QuizAnswer answer) {
    if (!isValidAnswer(answer)) return false;
    if (!isDateQuestion) return answer.optionIndex == correctOptionIndex;
    final date = answer.date!;
    return date.year == correctDate!.year &&
        date.month == correctDate!.month &&
        date.day == correctDate!.day;
  }

  static final byCollection = <String, CollectionQuiz>{
    'collection_7': CollectionQuiz.date(
      question:
          'Ngày 14 Casper chính thức có danh phận ở hành trình ATVNCG 2026 là ngày nào?',
      correctDate: DateTime(2026, 5, 18),
    ),
    'collection_8': const CollectionQuiz.choice(
      question: 'Món ăn gì được Tiên tử kết hợp khi ăn lẩu kim chi?',
      options: [
        'A. Bánh ngọt',
        'B. Panna cotta chanh',
        'C. Sữa chua Hy lạp',
        'D. Khoai mì hấp cốt dừa',
      ],
      correctOptionIndex: 1,
    ),
  };
}

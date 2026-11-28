import 'package:bo_anh/models/collection_quiz.dart';

void _check(bool value, String message) {
  if (!value) throw StateError(message);
}

void main() {
  runQuizChecks();
  // ignore: avoid_print
  print('Quiz checks passed: date, choice, missing and invalid answers.');
}

void runQuizChecks() {
  final date = CollectionQuiz.byCollection['collection_7']!;
  _check(
    date.isCorrect(QuizAnswer.date(DateTime(2026, 5, 18))),
    '18/05/2026 must pass',
  );
  _check(
    date.isCorrect(QuizAnswer.date(DateTime(2026, 5, 18, 23))),
    'Only the calendar date matters',
  );
  _check(
    !date.isCorrect(QuizAnswer.date(DateTime(2026, 5, 17))),
    'Wrong day must fail',
  );
  _check(
    !date.isCorrect(QuizAnswer.date(DateTime(2026, 6, 18))),
    'Wrong month must fail',
  );
  _check(
    !date.isCorrect(QuizAnswer.date(DateTime(2025, 5, 18))),
    'Wrong year cannot pass',
  );
  _check(
    !date.isValidAnswer(const QuizAnswer.date(null)),
    'Empty date must not be submitted',
  );
  _check(
    !date.isValidAnswer(const QuizAnswer.option(1)),
    'Choice cannot answer a date question',
  );
  final choice = CollectionQuiz.byCollection['collection_8']!;
  for (var i = 0; i < 4; i++) {
    _check(
      choice.isCorrect(QuizAnswer.option(i)) == (i == 1),
      'Only option B passes',
    );
  }
  _check(
    !choice.isValidAnswer(const QuizAnswer.option(null)),
    'Empty choice must not be submitted',
  );
  _check(
    !choice.isValidAnswer(const QuizAnswer.option(-1)),
    'Negative choice is invalid',
  );
  _check(
    !choice.isValidAnswer(const QuizAnswer.option(4)),
    'Out-of-range choice is invalid',
  );
  _check(
    CollectionQuiz.byCollection.length == 2,
    'Only versions 7 and 8 have a quiz',
  );
}

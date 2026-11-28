import 'dart:async';

import 'package:bo_anh/models/collection_quiz.dart';
import 'package:bo_anh/widgets/collection_quiz_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> openQuiz(
  WidgetTester tester,
  String id,
  Future<QuizAnswerResult> Function(QuizAnswer) submit, {
  ValueChanged<bool?>? onClosed,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              final result = await showDialog<bool>(
                context: context,
                barrierDismissible: false,
                builder: (_) => CollectionQuizDialog(
                  collectionName: id,
                  price: id == 'collection_7' ? 111 : 142,
                  quiz: CollectionQuiz.byCollection[id]!,
                  onSubmit: submit,
                ),
              );
              onClosed?.call(result);
            },
            child: const Text('Mở câu hỏi'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Mở câu hỏi'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'date question starts empty and opens a calendar without submitting',
    (tester) async {
      var calls = 0;
      await openQuiz(tester, 'collection_7', (_) async {
        calls++;
        return QuizAnswerResult.correct;
      });
      expect(find.text('--/--/2026'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      await tester.tap(find.text('--/--/2026'));
      await tester.pumpAndSettle();
      expect(find.byType(DatePickerDialog), findsOneWidget);
      await tester.tap(find.text('Hủy'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Để sau'));
      await tester.pumpAndSettle();
      expect(calls, 0);
    },
  );

  testWidgets(
    'one choice is submitted once and correct answer closes the dialog',
    (tester) async {
      final pending = Completer<QuizAnswerResult>();
      var calls = 0;
      bool? passed;
      await openQuiz(tester, 'collection_8', (answer) {
        calls++;
        expect(answer.optionIndex, 1);
        return pending.future;
      }, onClosed: (result) => passed = result);
      await tester.tap(find.text('B. Panna cotta chanh'));
      await tester.tap(find.text('Trả lời'));
      await tester.pump();
      expect(find.text('Đang lưu...'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      pending.complete(QuizAnswerResult.correct);
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(passed, isTrue);
      expect(find.byType(CollectionQuizDialog), findsNothing);
    },
  );

  testWidgets('wrong answer requires a new unlock and cannot resubmit', (
    tester,
  ) async {
    var calls = 0;
    await openQuiz(tester, 'collection_8', (_) async {
      calls++;
      return QuizAnswerResult.incorrect;
    });
    await tester.tap(find.text('A. Bánh ngọt'));
    await tester.tap(find.text('Trả lời'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Ver đã khóa lại'), findsOneWidget);
    expect(find.textContaining('142 xu'), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
    expect(calls, 1);
  });

  testWidgets('failed persistence retains the selected answer for retry', (
    tester,
  ) async {
    var calls = 0;
    await openQuiz(tester, 'collection_8', (_) async {
      if (++calls == 1) throw StateError('write failed');
      return QuizAnswerResult.correct;
    });
    await tester.tap(find.text('B. Panna cotta chanh'));
    await tester.tap(find.text('Trả lời'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Chưa xác nhận'), findsOneWidget);
    await tester.tap(find.text('Trả lời'));
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(find.byType(CollectionQuizDialog), findsNothing);
  });
}

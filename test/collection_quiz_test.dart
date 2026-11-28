import 'package:bo_anh/models/collection_quiz.dart';
import 'package:bo_anh/models/game_state.dart';
import 'package:bo_anh/services/game_storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/quiz_checks.dart' as checks;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(
    () => SharedPreferences.setMockInitialValues({'player_total_coins': 500}),
  );

  test('quiz answer keys and validation', checks.runQuizChecks);

  test(
    'wrong answer locks access; repurchase charges once and keeps progress',
    () async {
      await GameStorageService.saveGame(
        'collection_8',
        GameState(
          board: List.filled(9, 4),
          score: 30,
          moves: 7,
          firstWinMoves: 7,
          cleanFirstWin: true,
          maxLevelCelebrations: 1,
        ),
      );
      expect(
        await GameStorageService.unlockCollection('collection_8', 142),
        isTrue,
      );
      expect(await GameStorageService.loadTotalCoins(), 358);
      expect(
        await GameStorageService.answerCollectionQuiz(
          'collection_8',
          const QuizAnswer.option(0),
        ),
        QuizAnswerResult.incorrect,
      );
      expect(
        await GameStorageService.loadUnlockedCollections(),
        isNot(contains('collection_8')),
      );
      expect(await GameStorageService.loadTotalCoins(), 358);
      final repeated = await GameStorageService.answerCollectionQuiz(
        'collection_8',
        const QuizAnswer.option(1),
      );
      expect(repeated, QuizAnswerResult.locked);
      await Future.wait([
        GameStorageService.unlockCollection('collection_8', 142),
        GameStorageService.unlockCollection('collection_8', 142),
      ]);
      expect(await GameStorageService.loadTotalCoins(), 216);
      expect((await GameStorageService.loadGame('collection_8'))!.score, 30);
      expect(
        (await GameStorageService.loadAchievement('collection_8')).bestMoves,
        7,
      );
    },
  );

  test(
    'correct answers charge nothing; a later wrong entry still relocks',
    () async {
      await GameStorageService.unlockCollection('collection_8', 142);
      for (var n = 0; n < 2; n++) {
        expect(
          await GameStorageService.answerCollectionQuiz(
            'collection_8',
            const QuizAnswer.option(1),
          ),
          QuizAnswerResult.correct,
        );
      }
      expect(await GameStorageService.loadTotalCoins(), 358);
      expect(
        await GameStorageService.answerCollectionQuiz(
          'collection_8',
          const QuizAnswer.option(3),
        ),
        QuizAnswerResult.incorrect,
      );
      expect(
        await GameStorageService.loadUnlockedCollections(),
        isNot(contains('collection_8')),
      );
    },
  );

  test(
    'date question accepts the supplied date and locks on a different day',
    () async {
      await GameStorageService.unlockCollection('collection_7', 111);
      expect(
        await GameStorageService.answerCollectionQuiz(
          'collection_7',
          QuizAnswer.date(DateTime(2026, 5, 18)),
        ),
        QuizAnswerResult.correct,
      );
      expect(
        await GameStorageService.answerCollectionQuiz(
          'collection_7',
          QuizAnswer.date(DateTime(2026, 5, 19)),
        ),
        QuizAnswerResult.incorrect,
      );
      expect(await GameStorageService.loadTotalCoins(), 389);
    },
  );

  test('empty answers do not revoke access or charge coins', () async {
    await GameStorageService.unlockCollection('collection_8', 142);
    await expectLater(
      GameStorageService.answerCollectionQuiz(
        'collection_8',
        const QuizAnswer.option(null),
      ),
      throwsArgumentError,
    );
    expect(
      await GameStorageService.loadUnlockedCollections(),
      contains('collection_8'),
    );
    expect(await GameStorageService.loadTotalCoins(), 358);
  });

  test(
    'relock survives reload and backup; insufficient coins cannot reopen',
    () async {
      SharedPreferences.setMockInitialValues({'player_total_coins': 142});
      await GameStorageService.unlockCollection('collection_8', 142);
      await GameStorageService.answerCollectionQuiz(
        'collection_8',
        const QuizAnswer.option(0),
      );
      final prefs = await SharedPreferences.getInstance();
      final committed = prefs.getString(GameStorageService.playerDataKey)!;
      SharedPreferences.setMockInitialValues({
        GameStorageService.playerDataKey: committed,
      });
      expect(
        await GameStorageService.loadUnlockedCollections(),
        isNot(contains('collection_8')),
      );
      final backup = await GameStorageService.exportBackup();
      SharedPreferences.setMockInitialValues({});
      await GameStorageService.restoreBackup(backup, {});
      expect(
        await GameStorageService.unlockCollection('collection_8', 142),
        isFalse,
      );
      expect(await GameStorageService.loadTotalCoins(), 0);
    },
  );
}

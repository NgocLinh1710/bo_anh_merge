import 'package:bo_anh/models/collection_achievement.dart';
import 'package:bo_anh/models/game_state.dart';
import 'package:bo_anh/models/spawn_config.dart';
import 'package:bo_anh/utils/game_logic.dart';

void _check(bool condition, String description) {
  if (!condition) throw StateError(description);
}

/// Also runnable with the Dart executable, without Flutter platform bindings.
void main() {
  runGameplayChecks();
  // Standalone CLI feedback when Flutter's SDK cache is unavailable.
  // ignore: avoid_print
  print('Gameplay checks passed: rescue, first completion and badge records.');
}

void runGameplayChecks() {
  final blocked = GameState(
    board: [1, 2, 3, 4, 5, 6, 7, 8, 9],
    score: 42,
    moves: 12,
    pairsMerged: 12,
    highestDiscoveredLevel: 9,
    isGameOver: true,
  );
  final rescued = GameLogic.rescue(blocked, 8, 9);
  _check(
    rescued.rescueUsed && !rescued.isGameOver,
    'Rescue must revive a blocked board',
  );
  _check(
    rescued.board[8] == 1 && blocked.board[8] == 9,
    'Only the chosen tile changes, immutably',
  );
  _check(
    rescued.score == 42 && rescued.moves == 12 && rescued.pairsMerged == 12,
    'Rescue must not grant a move, score or reward progress',
  );
  _check(rescued.highestDiscoveredLevel == 9, 'Rescue must preserve discovery');
  _check(
    identical(GameLogic.rescue(rescued, 7, 9), rescued),
    'Rescue can only be used once',
  );
  _check(
    identical(GameLogic.rescue(blocked, -1, 9), blocked),
    'Invalid selection must not consume rescue',
  );
  final noPair = GameState(board: List.filled(9, 1));
  _check(
    identical(GameLogic.rescue(noPair, 0, 9), noPair),
    'No useful replacement must not consume rescue',
  );

  final ready = GameState(board: [8, 8, 1, 1, 2, 2, 3, 3, 4], moves: 10);
  final won = GameLogic.merge(ready, 0, 1, 9, spawnConfig: const SpawnConfig());
  _check(
    won.firstWinMoves == 11 && won.cleanFirstWin,
    'First final-image merge must freeze completion',
  );
  final continued = GameLogic.merge(
    won,
    2,
    3,
    9,
    spawnConfig: const SpawnConfig(),
  );
  _check(
    continued.firstWinMoves == 11 && continued.cleanFirstWin,
    'Continued play must not change completion',
  );
  final assisted = GameLogic.merge(ready.copyWith(rescueUsed: true), 0, 1, 9);
  _check(
    assisted.rescueUsed && !assisted.cleanFirstWin,
    'Assisted completion must not earn clean badge',
  );
  final oldWin = GameLogic.merge(
    ready.copyWith(maxLevelCelebrations: 1),
    0,
    1,
    9,
  );
  _check(
    oldWin.firstWinMoves == null && !oldWin.cleanFirstWin,
    'Legacy completed games cannot claim a later merge as their first win',
  );
  _check(!GameLogic.createNewGame(9).rescueUsed, 'New games restore rescue');

  var record = const CollectionAchievement().recordWin(100, false, 90);
  _check(
    record.bestMoves == 100 &&
        !record.recordBreaker &&
        !record.speedWinner &&
        !record.cleanWinner,
    'First completion sets baseline without awarding record-breaker',
  );
  record = record.recordWin(100, true, 90);
  _check(
    record.cleanWinner && !record.recordBreaker,
    'A tie earns clean badge but is not a record',
  );
  record = record.recordWin(90, false, 90);
  _check(
    record.bestMoves == 90 &&
        record.recordBreaker &&
        record.speedWinner &&
        record.cleanWinner,
    'Strictly faster completion earns record and threshold badge, retaining old badges',
  );
  record = record.recordWin(120, false, 90);
  _check(
    record.bestMoves == 90,
    'Slower replay must not replace personal best',
  );
  _check(
    CollectionAchievement.fromJson(record.toJson()).toJson().toString() ==
        record.toJson().toString(),
    'Achievements must round-trip',
  );
  _check(
    ChallengeGoals.targetMoves.length == 8,
    'Every version has a challenge target',
  );
}

import 'dart:convert';

import 'package:bo_anh/models/game_mode.dart';
import 'package:bo_anh/models/game_state.dart';
import 'package:bo_anh/services/game_storage_service.dart';
import 'package:bo_anh/utils/game_logic.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  GameState win(int moves, {bool clean = true}) => GameState(
    board: [3, 1, 1, 1, 1, 1, 1, 1, 1],
    moves: moves,
    firstWinMoves: moves,
    maxLevelCelebrations: 1,
    cleanFirstWin: clean,
    rescueUsed: !clean,
  );

  test(
    'merge, coins, completion and badges commit together and survive reload',
    () async {
      final state = win(3);
      await GameStorageService.recordMergeAndSaveGame(
        'collection_7',
        state,
        pairs: 14,
      );
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(GameStorageService.playerDataKey)!;
      SharedPreferences.setMockInitialValues({
        GameStorageService.playerDataKey: raw,
      });
      final saved = (await GameStorageService.loadGame('collection_7'))!;
      final badges = await GameStorageService.loadAchievement('collection_7');
      expect(saved.firstWinMoves, 3);
      expect(saved.cleanFirstWin, isTrue);
      expect(badges.bestMoves, 3);
      expect(badges.speedWinner, isTrue);
      expect(badges.cleanWinner, isTrue);
      expect(badges.recordBreaker, isFalse);
      expect(await GameStorageService.loadTotalCoins(), 11);
    },
  );

  test(
    'rescue persists once without earning coins, then restart resets it',
    () async {
      final blocked = GameState(
        board: [1, 2, 3, 4, 5, 6, 7, 8, 9],
        isGameOver: true,
      );
      final rescue = GameLogic.rescue(blocked, 8, 9);
      await GameStorageService.saveGame('collection_1', rescue);
      final loaded = (await GameStorageService.loadGame('collection_1'))!;
      expect(loaded.rescueUsed, isTrue);
      expect(loaded.isGameOver, isFalse);
      expect(identical(GameLogic.rescue(loaded, 7, 9), loaded), isTrue);
      expect(await GameStorageService.loadTotalCoins(), 0);
      expect(await GameStorageService.loadTotalPairs(), 0);
      await GameStorageService.saveGame(
        'collection_1',
        GameLogic.createNewGame(9),
      );
      expect(
        (await GameStorageService.loadGame('collection_1'))!.rescueUsed,
        isFalse,
      );
    },
  );

  test(
    'strict improvements persist; restart retains badges; timed games stay separate',
    () async {
      await GameStorageService.saveGame('collection_7', win(5));
      await GameStorageService.clearGame('collection_7');
      expect(
        (await GameStorageService.loadAchievement('collection_7')).bestMoves,
        5,
      );
      await GameStorageService.saveGame('collection_7', win(2, clean: false));
      await GameStorageService.saveGame(
        'collection_7',
        win(1),
        mode: GameMode.timed,
      );
      final badges = await GameStorageService.loadAchievement('collection_7');
      expect(badges.bestMoves, 2);
      expect(badges.recordBreaker, isTrue);
      expect(badges.cleanWinner, isTrue);
      expect(badges.speedWinner, isTrue);
    },
  );

  test(
    'legacy games default to unused rescue without inventing completion',
    () async {
      SharedPreferences.setMockInitialValues({
        'game_collection_1': jsonEncode({
          'board': List.filled(9, 1),
          'moves': 40,
          'maxLevelCelebrations': 1,
        }),
      });
      final state = (await GameStorageService.loadGame('collection_1'))!;
      expect(state.rescueUsed, isFalse);
      expect(state.firstWinMoves, isNull);
      expect(
        (await GameStorageService.loadAchievement('collection_1')).bestMoves,
        isNull,
      );
    },
  );

  test(
    'backup restores versions 7/8, rescue, records and badges together',
    () async {
      await GameStorageService.unlockCollection('collection_8', 0);
      await GameStorageService.saveGame('collection_7', win(3, clean: false));
      await GameStorageService.saveGame('collection_8', win(7));
      final raw = await GameStorageService.exportBackup();
      GameStorageService.validateBackup(raw);
      SharedPreferences.setMockInitialValues({});
      await GameStorageService.restoreBackup(raw, {});
      expect(
        (await GameStorageService.loadGame('collection_7'))!.rescueUsed,
        isTrue,
      );
      expect(
        (await GameStorageService.loadAchievement('collection_8')).speedWinner,
        isTrue,
      );
      expect(
        await GameStorageService.loadUnlockedCollections(),
        contains('collection_8'),
      );
      final corrupt = jsonDecode(raw) as Map<String, dynamic>;
      corrupt['achievements']['collection_8']['bestMoves'] = -1;
      expect(
        () => GameStorageService.validateBackup(jsonEncode(corrupt)),
        throwsFormatException,
      );
    },
  );

  test('old version-1 backups without achievements remain readable', () async {
    final old =
        jsonDecode(await GameStorageService.exportBackup())
            as Map<String, dynamic>;
    old.remove('achievements');
    await GameStorageService.restoreBackup(jsonEncode(old), {});
    expect(
      (await GameStorageService.loadAchievement('collection_1')).bestMoves,
      isNull,
    );
  });

  test(
    'backup permits progress and scores for all eight versions and both modes',
    () async {
      for (var n = 1; n <= 8; n++) {
        for (final mode in GameMode.values) {
          await GameStorageService.saveGame(
            'collection_$n',
            GameState(board: List.filled(9, 1), score: 10),
            mode: mode,
          );
        }
      }
      final backup = GameStorageService.validateBackup(
        await GameStorageService.exportBackup(),
      );
      expect(backup['games'], hasLength(16));
      expect(backup['highScores'], hasLength(16));
    },
  );
}

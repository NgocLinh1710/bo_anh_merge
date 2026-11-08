import 'dart:convert';

import 'package:bo_anh/models/game_mode.dart';
import 'package:bo_anh/models/game_state.dart';
import 'package:bo_anh/services/game_storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'earned coins and unlocked collections survive closing and reopening local state',
    () async {
      SharedPreferences.setMockInitialValues({'player_total_coins': 200});
      expect(
        await GameStorageService.recordMergedPairs(
          17,
          collectionId: 'collection_1',
        ),
        11,
      );
      expect(
        await GameStorageService.unlockCollection('collection_2', 111),
        true,
      );
      final prefs = await SharedPreferences.getInstance();
      final committed = prefs.getString(GameStorageService.playerDataKey)!;
      // No page-exit handler or network request is needed to restore the record.
      SharedPreferences.setMockInitialValues({
        GameStorageService.playerDataKey: committed,
      });
      expect(await GameStorageService.loadTotalCoins(), 100);
      expect(await GameStorageService.loadCoinProgress(), 3);
      expect(await GameStorageService.loadTotalPairs(), 17);
      expect(await GameStorageService.loadUnlockedCollections(), {
        'collection_2',
      });
      expect(
        await GameStorageService.recordMergedPairs(
          11,
          collectionId: 'collection_2',
        ),
        14,
      );
      expect(await GameStorageService.loadTotalCoins(), 114);
    },
  );

  test(
    'rapid concurrent rewards retain every pair and every earned coin',
    () async {
      final earned = await Future.wait(
        List.generate(
          140,
          (_) => GameStorageService.recordMergedPairs(
            1,
            collectionId: 'collection_1',
          ),
        ),
      );
      expect(earned.reduce((a, b) => a + b), 110);
      expect(await GameStorageService.loadTotalCoins(), 110);
      expect(await GameStorageService.loadTotalPairs(), 140);
      expect(await GameStorageService.loadCoinProgress(), 0);
    },
  );

  test('duplicate unlock attempts deduct the price only once', () async {
    SharedPreferences.setMockInitialValues({'player_total_coins': 200});
    final results = await Future.wait(
      List.generate(
        20,
        (_) => GameStorageService.unlockCollection('collection_2', 111),
      ),
    );
    expect(results.every((v) => v), true);
    expect(await GameStorageService.loadTotalCoins(), 89);
    expect(await GameStorageService.loadUnlockedCollections(), {
      'collection_2',
    });
  });

  test(
    'concurrent purchases never spend more than the wallet balance',
    () async {
      SharedPreferences.setMockInitialValues({'player_total_coins': 200});
      final results = await Future.wait([
        GameStorageService.unlockCollection('collection_2', 111),
        GameStorageService.unlockCollection('collection_3', 142),
        GameStorageService.spendCoins(100),
      ]);
      expect(results, [true, false, false]);
      expect(await GameStorageService.loadTotalCoins(), 89);
    },
  );

  test(
    'legacy wallet, unlocks, free and timed games migrate once without deleting originals',
    () async {
      final game = jsonEncode({'board': List.filled(9, 1), 'score': 50});
      SharedPreferences.setMockInitialValues({
        'player_total_coins': 150,
        'player_coin_progress': 13,
        'player_total_pairs': 41,
        'unlocked_collections': ['collection_2'],
        'game_collection_2': game,
        'game_collection_2_timed': game,
        'high_score_collection_2': 100,
      });
      expect(await GameStorageService.loadTotalCoins(), 150);
      expect((await GameStorageService.loadGame('collection_2'))!.score, 50);
      expect(
        (await GameStorageService.loadGame(
          'collection_2',
          mode: GameMode.timed,
        ))!.score,
        50,
      );
      expect(await GameStorageService.loadHighScore('collection_2'), 100);
      await GameStorageService.recordMergedPairs(
        1,
        collectionId: 'collection_2',
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      expect(prefs.getInt('player_total_coins'), 150);
      final saved = jsonDecode(
        prefs.getString(GameStorageService.playerDataKey)!,
      );
      expect(saved['coins'], 164);
      expect(saved['coinProgress'], 0);
      expect(saved['totalPairs'], 42);
      expect(saved['unlocked'], ['collection_2']);
      // A new service read must not re-import the legacy 150 coins.
      expect(await GameStorageService.loadTotalCoins(), 164);
    },
  );

  test(
    'board, reward progress and coins are stored in one committed record',
    () async {
      SharedPreferences.setMockInitialValues({'player_coin_progress': 13});
      final state = GameState(
        board: List.filled(9, 2),
        score: 22,
        moves: 14,
        pairsMerged: 14,
      );
      expect(
        await GameStorageService.recordMergeAndSaveGame(
          'collection_3',
          state,
          pairs: 1,
        ),
        22,
      );
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(GameStorageService.playerDataKey)!;
      final saved = jsonDecode(raw);
      expect(saved['coins'], 22);
      expect(saved['coinProgress'], 0);
      expect(jsonDecode(saved['games']['game_collection_3'])['moves'], 14);
      // Simulate a fresh page with only the durable new record available.
      SharedPreferences.setMockInitialValues({
        GameStorageService.playerDataKey: raw,
      });
      expect(await GameStorageService.loadTotalCoins(), 22);
      expect(
        (await GameStorageService.loadGame('collection_3'))!.board,
        state.board,
      );
      expect(await GameStorageService.loadHighScore('collection_3'), 22);
    },
  );

  test(
    'timed reward uses the captured move rather than a later board state',
    () async {
      final state = GameState(board: List.filled(9, 2), timedRewardProgress: 5);
      expect(
        await GameStorageService.recordMergeAndSaveGame(
          'collection_1',
          state,
          pairs: 1,
          mode: GameMode.timed,
        ),
        10,
      );
      expect(await GameStorageService.loadCoinProgress(), 0);
      expect(
        (await GameStorageService.loadGame(
          'collection_1',
          mode: GameMode.timed,
        ))!.timedRewardProgress,
        5,
      );
    },
  );

  test(
    'corrupt player data is preserved and failed reads do not poison the queue',
    () async {
      SharedPreferences.setMockInitialValues({
        GameStorageService.playerDataKey: '{broken',
      });
      await expectLater(
        GameStorageService.recordMergedPairs(14, collectionId: 'collection_1'),
        throwsFormatException,
      );
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(GameStorageService.playerDataKey), '{broken');
      SharedPreferences.setMockInitialValues({'player_total_coins': 77});
      expect(await GameStorageService.loadTotalCoins(), 77);
    },
  );

  test('clearing a game preserves wallet, unlocks and high score', () async {
    SharedPreferences.setMockInitialValues({'player_total_coins': 200});
    await GameStorageService.unlockCollection('collection_2', 111);
    await GameStorageService.saveGame(
      'collection_2',
      GameState(board: List.filled(9, 1), score: 80),
    );
    await GameStorageService.clearGame('collection_2');
    expect(await GameStorageService.loadGame('collection_2'), isNull);
    expect(await GameStorageService.loadTotalCoins(), 89);
    expect(await GameStorageService.loadUnlockedCollections(), {
      'collection_2',
    });
    expect(await GameStorageService.loadHighScore('collection_2'), 80);
  });
}

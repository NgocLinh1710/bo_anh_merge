import 'dart:convert';
import 'dart:math';

import 'package:bo_anh/models/game_state.dart';
import 'package:bo_anh/models/spawn_config.dart';
import 'package:bo_anh/services/game_storage_service.dart';
import 'package:bo_anh/utils/game_logic.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'free-play seeded simulations stay within balance targets and progress in order',
    () {
      const levels = [9, 9, 10, 11, 14, 22];
      var previousMedian = 0;
      for (var collection = 1; collection <= 6; collection++) {
        final moves = <int>[];
        final maxLevel = levels[collection - 1];
        final config = SpawnConfig.collections['collection_$collection']!;
        for (var seed = 0; seed < 100; seed++) {
          final rng = Random(seed);
          var state = GameLogic.createNewGame(
            maxLevel,
            random: rng,
            spawnConfig: config,
          );
          while (!state.isGameOver &&
              state.maxLevelCelebrations == 0 &&
              state.moves < 1000) {
            int? from;
            int? to;
            for (var i = 0; i < 9; i++) {
              for (var j = i + 1; j < 9; j++) {
                if (GameLogic.canMerge(state.board, i, j, maxLevel) &&
                    (from == null || state.board[i]! < state.board[from]!)) {
                  from = i;
                  to = j;
                }
              }
            }
            expect(from, isNotNull);
            final before = state;
            state = GameLogic.merge(
              state,
              from!,
              to!,
              maxLevel,
              random: rng,
              spawnConfig: config,
            );
            // The initial pool is levels 1-3; later images require merging.
            expect(state.board[from]!, lessThan(maxLevel));
            expect(
              state.board[from]!,
              lessThanOrEqualTo(max(3, before.highestDiscoveredLevel)),
            );
            expect(
              state.highestDiscoveredLevel,
              greaterThanOrEqualTo(before.highestDiscoveredLevel),
            );
            expect(
              state.highestDiscoveredLevel,
              lessThanOrEqualTo(max(3, before.highestDiscoveredLevel + 1)),
            );
            expect(state.board.whereType<int>(), hasLength(9));
            expect(state.pairsMerged, before.pairsMerged + 1);
          }
          expect(
            state.maxLevelCelebrations,
            1,
            reason: 'collection $collection, seed $seed',
          );
          moves.add(state.moves);
        }
        moves.sort();
        final median = moves[moves.length ~/ 2];
        expect(median, greaterThan(previousMedian));
        if (collection == 1) expect(median, inInclusiveRange(120, 150));
        if (collection == 6) expect(median, inInclusiveRange(250, 320));
        previousMedian = median;
      }
    },
  );

  test(
    'timed refill stays at original levels even with high discovery progress',
    () {
      for (var seed = 0; seed < 200; seed++) {
        final current = GameState(
          board: [7, 7, 1, 2, 3, 4, 5, 6, 8],
          highestDiscoveredLevel: 8,
        );
        final next = GameLogic.merge(current, 0, 1, 22, random: Random(seed));
        expect(next.board[0], inInclusiveRange(1, 3));
      }
    },
  );

  test('support branch helps the lowest leftover image', () {
    final state = GameState(
      board: [6, 6, 1, 2, 3, 4, 5, 7, 8],
      highestDiscoveredLevel: 8,
    );
    final next = GameLogic.merge(
      state,
      0,
      1,
      22,
      random: Random(1),
      spawnConfig: const SpawnConfig(supportChance: 1),
    );
    expect(next.board[0], 1);
  });

  test(
    'discovery survives save, copy and reload; restart begins at initial levels',
    () async {
      SharedPreferences.setMockInitialValues({});
      final state = GameState(
        board: List.filled(9, 2),
        highestDiscoveredLevel: 12,
      );
      await GameStorageService.saveGame(
        'collection_6',
        state.copyWith(score: 10),
      );
      final loaded = await GameStorageService.loadGame('collection_6');
      expect(loaded!.highestDiscoveredLevel, 12);
      final restarted = GameLogic.createNewGame(
        22,
        random: Random(1),
        spawnConfig: SpawnConfig.collections['collection_6'],
      );
      expect(restarted.highestDiscoveredLevel, inInclusiveRange(1, 3));
    },
  );

  test(
    'old saves without discovery progress continue from highest image on board',
    () async {
      SharedPreferences.setMockInitialValues({
        'game_collection_1': jsonEncode({
          'board': [1, 1, 2, 2, 3, 4, 5, 6, 7],
          'score': 20,
        }),
      });
      final loaded = await GameStorageService.loadGame('collection_1');
      expect(loaded!.highestDiscoveredLevel, 7);
      expect(loaded.score, 20);
    },
  );
}

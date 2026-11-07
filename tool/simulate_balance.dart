import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:bo_anh/models/spawn_config.dart';
import 'package:bo_anh/utils/game_logic.dart';

void main() {
  const levels = [9, 9, 10, 11, 14, 22];
  for (var n = 0; n < levels.length; n++) {
    for (final strategy in ['lowest', 'highest', 'random']) {
      final wins = <int>[];
      for (var seed = 0; seed < 500; seed++) {
        final rng = Random(seed);
        final choices = Random(seed + 10000);
        final config = SpawnConfig.collections['collection_${n + 1}']!;
        var state = GameLogic.createNewGame(
          levels[n],
          random: rng,
          spawnConfig: config,
        );
        while (!state.isGameOver &&
            state.maxLevelCelebrations == 0 &&
            state.moves < 3000) {
          final pairs = <(int, int)>[];
          for (var i = 0; i < 9; i++) {
            for (var j = i + 1; j < 9; j++) {
              if (GameLogic.canMerge(state.board, i, j, levels[n])) {
                pairs.add((i, j));
              }
            }
          }
          if (pairs.isEmpty) break;
          pairs.sort(
            (a, b) => state.board[a.$1]!.compareTo(state.board[b.$1]!),
          );
          final pair = strategy == 'lowest'
              ? pairs.first
              : strategy == 'highest'
              ? pairs.last
              : pairs[choices.nextInt(pairs.length)];
          state = GameLogic.merge(
            state,
            pair.$1,
            pair.$2,
            levels[n],
            random: rng,
            spawnConfig: config,
          );
        }
        if (state.maxLevelCelebrations > 0) wins.add(state.moves);
      }
      wins.sort();
      int? percentile(double p) =>
          wins.isEmpty ? null : wins[((wins.length - 1) * p).round()];
      stdout.writeln(
        jsonEncode({
          'collection': n + 1,
          'strategy': strategy,
          'runs': 500,
          'wins': wins.length,
          'p10': percentile(.1),
          'median': percentile(.5),
          'p90': percentile(.9),
        }),
      );
    }
  }
}

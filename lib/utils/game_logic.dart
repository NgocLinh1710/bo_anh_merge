import 'dart:math';

import '../models/game_state.dart';
import '../models/spawn_config.dart';

class GameLogic {
  static const int boardSize = 3;
  static const int boardCapacity = boardSize * boardSize;

  static final Random _random = Random();

  // Thời gian ban đầu của chế độ Thử thách thời gian
  static const int initialTimeSeconds = 14;

  // Tạo bàn chơi ban đầu với đủ 9 ảnh
  static GameState createNewGame(
    int maxLevel, {
    Random? random,
    SpawnConfig? spawnConfig,
  }) {
    final rng = random ?? _random;
    final board = List<int?>.filled(boardCapacity, null);

    for (int i = 0; i < boardCapacity; i++) {
      board[i] = _randomStartLevel(
        maxLevel,
        rng,
        allowFinal: spawnConfig == null,
      );
    }

    // Bảo đảm có ít nhất một cặp ghép được
    if (maxLevel >= 2) {
      final possibleLevels = [
        for (int level = 1; level < maxLevel && level <= 3; level++) level,
      ];

      final guaranteedLevel =
          possibleLevels[rng.nextInt(possibleLevels.length)];

      final positions = List<int>.generate(boardCapacity, (i) => i)
        ..shuffle(rng);

      board[positions[0]] = guaranteedLevel;
      board[positions[1]] = guaranteedLevel;
    }

    return GameState(
      board: board,
      highestDiscoveredLevel: board.whereType<int>().reduce(max),
      score: 0,
      moves: 0,
      pairsMerged: 0,
      maxLevelCelebrations: 0,
      maxLevelNoticeShownFor: 0,
      isGameOver: isGameOver(board, maxLevel),
      remainingSeconds: initialTimeSeconds,
      timedRewardProgress: 0,
    );
  }

  // Sinh cấp độ ảnh ngẫu nhiên
  static int _randomStartLevel(
    int maxLevel,
    Random random, {
    bool allowFinal = true,
  }) {
    if (maxLevel <= 1) return 1;

    final roll = random.nextInt(100);

    int level;

    if (roll < 78) {
      level = 1;
    } else if (roll < 96) {
      level = 2;
    } else {
      level = 3;
    }

    return min(level, allowFinal ? maxLevel : maxLevel - 1);
  }

  static List<int> _emptyCells(List<int?> board) {
    return [
      for (int i = 0; i < board.length; i++)
        if (board[i] == null) i,
    ];
  }

  static bool _spawnTile(
    List<int?> board,
    int maxLevel,
    int highest,
    Random random,
    SpawnConfig? config,
  ) {
    final empty = _emptyCells(board);

    if (empty.isEmpty) return false;

    final position = empty[random.nextInt(empty.length)];
    if (config == null || highest < 5) {
      board[position] = _randomStartLevel(
        maxLevel,
        random,
        allowFinal: config == null,
      );
    } else {
      final eligible = board
          .whereType<int>()
          .where((level) => level < highest && level < maxLevel)
          .toList();
      if (eligible.isNotEmpty && random.nextDouble() < config.supportChance) {
        board[position] = eligible.reduce(min);
      } else {
        final lag = random.nextDouble() < config.closerSpawnChance ? 3 : 4;
        final base = max(1, highest - lag);
        final roll = random.nextDouble();
        final offset = roll < config.lowWeight
            ? 0
            : roll < config.lowWeight + config.middleWeight
            ? 1
            : 2;
        board[position] = min(min(highest - 1, maxLevel - 1), base + offset);
      }
    }

    return true;
  }

  static bool canMerge(List<int?> board, int from, int to, int maxLevel) {
    if (from < 0 ||
        to < 0 ||
        from >= boardCapacity ||
        to >= boardCapacity ||
        from == to) {
      return false;
    }

    final first = board[from];
    final second = board[to];

    return first != null &&
        second != null &&
        first == second &&
        first < maxLevel;
  }

  // Lấp đầy tất cả ô trống sau khi ghép thành công
  static void _refillBoard(
    List<int?> board,
    int maxLevel,
    int highest,
    Random random,
    SpawnConfig? config,
  ) {
    while (_emptyCells(board).isNotEmpty) {
      if (!_spawnTile(board, maxLevel, highest, random, config)) break;
    }
  }

  static GameState merge(
    GameState current,
    int from,
    int to,
    int maxLevel, {
    Random? random,
    SpawnConfig? spawnConfig,
  }) {
    if (current.isGameOver || !canMerge(current.board, from, to, maxLevel)) {
      return current;
    }

    final board = List<int?>.from(current.board);

    final currentLevel = board[from]!;

    // Xóa ảnh nguồn và nâng cấp ảnh đích lên một cấp
    board[from] = null;
    board[to] = currentLevel + 1;

    final newLevel = currentLevel + 1;
    final highest = max(
      current.highestDiscoveredLevel,
      max(newLevel, current.board.whereType<int>().fold<int>(1, max)),
    );
    final gainedScore = newLevel;

    // Mỗi thao tác chỉ tính một cặp ghép thành công
    const mergedPairs = 1;

    final maxLevelCelebrations =
        current.maxLevelCelebrations + (newLevel == maxLevel ? 1 : 0);

    final timedRewardProgress = current.timedRewardProgress + mergedPairs;

    _refillBoard(board, maxLevel, highest, random ?? _random, spawnConfig);

    return GameState(
      board: board,
      highestDiscoveredLevel: max(
        highest,
        board.whereType<int>().fold<int>(1, max),
      ),
      score: current.score + gainedScore,
      moves: current.moves + 1,
      pairsMerged: current.pairsMerged + mergedPairs,
      maxLevelCelebrations: maxLevelCelebrations,
      maxLevelNoticeShownFor: current.maxLevelNoticeShownFor,
      isGameOver: isGameOver(board, maxLevel),
      remainingSeconds: current.remainingSeconds,
      timedRewardProgress: timedRewardProgress,
    );
  }

  // Bàn chơi kết thúc khi không còn cặp ảnh nào có thể ghép
  static bool isGameOver(List<int?> board, int maxLevel) {
    if (board.length != boardCapacity || board.any((tile) => tile == null)) {
      return false;
    }

    for (int i = 0; i < board.length; i++) {
      for (int j = i + 1; j < board.length; j++) {
        if (canMerge(board, i, j, maxLevel)) {
          return false;
        }
      }
    }

    return true;
  }

  // Kiểm tra bàn chơi có ảnh cấp tối đa hay không
  static bool containsMaxLevel(List<int?> board, int maxLevel) {
    return board.any((tile) => tile == maxLevel);
  }
}

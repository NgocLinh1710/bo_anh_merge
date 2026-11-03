import 'dart:math';

import '../models/game_state.dart';

class GameLogic {
  static const int boardSize = 3;
  static const int boardCapacity = boardSize * boardSize;

  static final Random _random = Random();

  // Tạo bàn chơi ban đầu với đủ 9 ảnh
  static GameState createNewGame(int maxLevel) {
    final board = List<int?>.filled(boardCapacity, null);

    for (int i = 0; i < boardCapacity; i++) {
      board[i] = _randomStartLevel(maxLevel);
    }

    // Bảo đảm có ít nhất một cặp ghép được
    if (maxLevel >= 2) {
      final possibleLevels = [
        for (int level = 1; level < maxLevel && level <= 3; level++) level,
      ];

      final guaranteedLevel =
          possibleLevels[_random.nextInt(possibleLevels.length)];

      final positions = List<int>.generate(boardCapacity, (i) => i)
        ..shuffle(_random);

      board[positions[0]] = guaranteedLevel;
      board[positions[1]] = guaranteedLevel;
    }

    return GameState(
      board: board,
      score: 0,
      moves: 0,
      pairsMerged: 0,
      maxLevelCelebrations: 0,
      isGameOver: isGameOver(board, maxLevel),
    );
  }

  // Sinh cấp độ ảnh ngẫu nhiên
  static int _randomStartLevel(int maxLevel) {
    if (maxLevel <= 1) return 1;

    final roll = _random.nextInt(100);

    int level;

    if (roll < 78) {
      level = 1;
    } else if (roll < 96) {
      level = 2;
    } else {
      level = 3;
    }

    return min(level, maxLevel);
  }

  static List<int> _emptyCells(List<int?> board) {
    return [
      for (int i = 0; i < board.length; i++)
        if (board[i] == null) i,
    ];
  }

  static bool _spawnTile(List<int?> board, int maxLevel) {
    final empty = _emptyCells(board);

    if (empty.isEmpty) return false;

    final position = empty[_random.nextInt(empty.length)];
    board[position] = _randomStartLevel(maxLevel);

    return true;
  }

  // Ảnh cấp tối đa không thể ghép, kể cả với ảnh cùng cấp
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

  static List<int> _findAdjacentMatches(
    List<int?> board,
    int position,
    int level,
  ) {
    final row = position ~/ boardSize;
    final col = position % boardSize;

    final neighbors = <int>[];

    if (row > 0) neighbors.add(position - boardSize);
    if (row < boardSize - 1) neighbors.add(position + boardSize);
    if (col > 0) neighbors.add(position - 1);
    if (col < boardSize - 1) neighbors.add(position + 1);

    return neighbors.where((index) => board[index] == level).toList();
  }

  static void _refillBoard(List<int?> board, int maxLevel) {
    while (_emptyCells(board).isNotEmpty) {
      if (!_spawnTile(board, maxLevel)) break;
    }
  }

  // Ghép ảnh và xử lý chain merge
  static GameState merge(GameState current, int from, int to, int maxLevel) {
    if (current.isGameOver || !canMerge(current.board, from, to, maxLevel)) {
      return current;
    }

    final board = List<int?>.from(current.board);

    final currentLevel = board[from]!;

    board[from] = null;
    board[to] = currentLevel + 1;

    int gainedScore = currentLevel + 1;
    int mergedPairs = 1;
    int maxLevelCelebrations = current.maxLevelCelebrations;

    int currentPosition = to;
    int newLevel = currentLevel + 1;

    // Nếu lần ghép đầu tiên tạo ra ảnh cấp tối đa
    if (newLevel == maxLevel) {
      maxLevelCelebrations++;
    }

    // Chain merge với ảnh cùng cấp độ nằm cạnh nhau
    while (newLevel < maxLevel) {
      final matches = _findAdjacentMatches(board, currentPosition, newLevel);

      if (matches.isEmpty) break;

      final matchedPosition = matches.first;

      board[matchedPosition] = null;
      board[currentPosition] = newLevel + 1;

      newLevel++;
      mergedPairs++;
      gainedScore += newLevel;

      // Mỗi lần tạo ảnh cấp tối đa đều ghi nhận một sự kiện
      if (newLevel == maxLevel) {
        maxLevelCelebrations++;
      }
    }

    // Lấp đầy tất cả ô trống sau khi xử lý chain merge
    _refillBoard(board, maxLevel);

    final result = GameState(
      board: board,
      score: current.score + gainedScore,
      moves: current.moves + 1,
      pairsMerged: current.pairsMerged + mergedPairs,
      maxLevelCelebrations: maxLevelCelebrations,
      maxLevelNoticeShownFor: current.maxLevelNoticeShownFor,
      isGameOver: isGameOver(board, maxLevel),
    );

    return result;
  }

  // Kiểm tra game đã kết thúc chưa
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

  static bool containsMaxLevel(List<int?> board, int maxLevel) {
    return board.any((tile) => tile == maxLevel);
  }
}

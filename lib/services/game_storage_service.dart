import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/game_state.dart';

class GameStorageService {
  static String _gameKey(String collectionId) {
    return 'game_$collectionId';
  }

  static String _highScoreKey(String collectionId) {
    return 'high_score_$collectionId';
  }

  // Lưu trạng thái hiện tại của trò chơi
  static Future<void> saveGame(String collectionId, GameState state) async {
    final prefs = await SharedPreferences.getInstance();

    final data = {
      'board': state.board,
      'score': state.score,
      'moves': state.moves,
      'maxLevelNoticeShownFor': state.maxLevelNoticeShownFor,
      'isGameOver': state.isGameOver,
    };

    await prefs.setString(_gameKey(collectionId), jsonEncode(data));

    final currentHighScore = prefs.getInt(_highScoreKey(collectionId)) ?? 0;

    if (state.score > currentHighScore) {
      await prefs.setInt(_highScoreKey(collectionId), state.score);
    }
  }

  // Đọc trạng thái trò chơi đã lưu
  static Future<GameState?> loadGame(String collectionId) async {
    final prefs = await SharedPreferences.getInstance();

    final jsonString = prefs.getString(_gameKey(collectionId));

    if (jsonString == null) return null;

    try {
      final data = jsonDecode(jsonString) as Map<String, dynamic>;

      final board = (data['board'] as List)
          .map<int?>((value) => value == null ? null : value as int)
          .toList();

      if (board.length != 9) return null;

      return GameState(
        board: board,
        score: data['score'] as int? ?? 0,
        moves: data['moves'] as int? ?? 0,
        maxLevelNoticeShownFor: data['maxLevelNoticeShownFor'] as int? ?? 0,
        isGameOver: data['isGameOver'] as bool? ?? false,
      );
    } catch (_) {
      return null;
    }
  }

  // Lấy điểm cao nhất của từng bộ sưu tập
  static Future<int> loadHighScore(String collectionId) async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.getInt(_highScoreKey(collectionId)) ?? 0;
  }

  // Xóa ván chơi hiện tại, không xóa điểm cao nhất
  static Future<void> clearGame(String collectionId) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove(_gameKey(collectionId));
  }
}

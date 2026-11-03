import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/game_state.dart';

class GameStorageService {
  static const int pairsPerReward = 14;
  static const int coinsPerReward = 11;

  static String _gameKey(String collectionId) {
    return 'game_$collectionId';
  }

  static String _highScoreKey(String collectionId) {
    return 'high_score_$collectionId';
  }

  static const String _totalCoinsKey = 'player_total_coins';
  static const String _coinProgressKey = 'player_coin_progress';
  static const String _totalPairsKey = 'player_total_pairs';
  static const String _unlockedCollectionsKey = 'unlocked_collections';

  static Future<void> saveGame(String collectionId, GameState state) async {
    final prefs = await SharedPreferences.getInstance();

    final data = {
      'board': state.board,
      'score': state.score,
      'moves': state.moves,
      'pairsMerged': state.pairsMerged,
      'maxLevelCelebrations': state.maxLevelCelebrations,
      'maxLevelNoticeShownFor': state.maxLevelNoticeShownFor,
      'isGameOver': state.isGameOver,
    };

    await prefs.setString(_gameKey(collectionId), jsonEncode(data));

    final currentHighScore = prefs.getInt(_highScoreKey(collectionId)) ?? 0;

    if (state.score > currentHighScore) {
      await prefs.setInt(_highScoreKey(collectionId), state.score);
    }
  }

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
        pairsMerged: data['pairsMerged'] as int? ?? 0,
        maxLevelCelebrations: data['maxLevelCelebrations'] as int? ?? 0,
        maxLevelNoticeShownFor: data['maxLevelNoticeShownFor'] as int? ?? 0,
        isGameOver: data['isGameOver'] as bool? ?? false,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<int> recordMergedPairs(int pairs) async {
    if (pairs <= 0) return 0;

    final prefs = await SharedPreferences.getInstance();

    final oldProgress = prefs.getInt(_coinProgressKey) ?? 0;
    final oldTotalPairs = prefs.getInt(_totalPairsKey) ?? 0;
    final oldCoins = prefs.getInt(_totalCoinsKey) ?? 0;

    final newProgress = oldProgress + pairs;
    final rewards = newProgress ~/ pairsPerReward;
    final remainingProgress = newProgress % pairsPerReward;
    final earnedCoins = rewards * coinsPerReward;

    await prefs.setInt(_coinProgressKey, remainingProgress);
    await prefs.setInt(_totalPairsKey, oldTotalPairs + pairs);
    await prefs.setInt(_totalCoinsKey, oldCoins + earnedCoins);

    return earnedCoins;
  }

  static Future<int> loadTotalCoins() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_totalCoinsKey) ?? 0;
  }

  static Future<int> loadCoinProgress() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_coinProgressKey) ?? 0;
  }

  static Future<int> loadTotalPairs() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_totalPairsKey) ?? 0;
  }

  static Future<bool> spendCoins(int amount) async {
    if (amount < 0) return false;

    final prefs = await SharedPreferences.getInstance();
    final currentCoins = prefs.getInt(_totalCoinsKey) ?? 0;

    if (currentCoins < amount) return false;

    await prefs.setInt(_totalCoinsKey, currentCoins - amount);
    return true;
  }

  // Lấy danh sách bộ sưu tập đã mở khóa
  static Future<Set<String>> loadUnlockedCollections() async {
    final prefs = await SharedPreferences.getInstance();

    return (prefs.getStringList(_unlockedCollectionsKey) ?? []).toSet();
  }

  // Mở khóa và trừ xu
  // Trả về false nếu không đủ xu
  static Future<bool> unlockCollection(String collectionId, int price) async {
    if (price < 0) return false;

    final prefs = await SharedPreferences.getInstance();

    final unlocked = (prefs.getStringList(_unlockedCollectionsKey) ?? [])
        .toSet();

    if (unlocked.contains(collectionId)) return true;

    final currentCoins = prefs.getInt(_totalCoinsKey) ?? 0;

    if (currentCoins < price) return false;

    unlocked.add(collectionId);

    await prefs.setInt(_totalCoinsKey, currentCoins - price);
    await prefs.setStringList(_unlockedCollectionsKey, unlocked.toList());

    return true;
  }

  static Future<int> loadHighScore(String collectionId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_highScoreKey(collectionId)) ?? 0;
  }

  static Future<void> clearGame(String collectionId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_gameKey(collectionId));
  }
}

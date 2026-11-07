import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/game_mode.dart';
import '../models/game_state.dart';

class GameStorageService {
  // Phần thưởng Chơi tự do
  static const int pairsPerReward = 14;
  static const Map<String, int> collectionRewardCoins = {
    'collection_1': 11,
    'collection_2': 14,
    'collection_3': 22,
    'collection_4': 24,
    'collection_5': 28,
    'collection_6': 30,
  };

  static int coinsPerReward(String collectionId) {
    return collectionRewardCoins[collectionId] ?? 11;
  }

  // Phần thưởng Thử thách thời gian
  static const int timedPairsPerReward = 5;
  static const int timedCoinsPerReward = 10;

  static String _gameKey(String collectionId, [GameMode mode = GameMode.free]) {
    if (mode == GameMode.free) {
      return 'game_$collectionId';
    }

    return 'game_${collectionId}_${mode.storageKey}';
  }

  static String _highScoreKey(
    String collectionId, [
    GameMode mode = GameMode.free,
  ]) {
    if (mode == GameMode.free) {
      return 'high_score_$collectionId';
    }

    return 'high_score_${collectionId}_${mode.storageKey}';
  }

  static const String _totalCoinsKey = 'player_total_coins';
  static const String _coinProgressKey = 'player_coin_progress';
  static const String _totalPairsKey = 'player_total_pairs';
  static const String _unlockedCollectionsKey = 'unlocked_collections';

  static Future<void> saveGame(
    String collectionId,
    GameState state, {
    GameMode mode = GameMode.free,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    final data = {
      'board': state.board,
      'score': state.score,
      'moves': state.moves,
      'highestDiscoveredLevel': state.highestDiscoveredLevel,
      'pairsMerged': state.pairsMerged,
      'maxLevelCelebrations': state.maxLevelCelebrations,
      'maxLevelNoticeShownFor': state.maxLevelNoticeShownFor,
      'isGameOver': state.isGameOver,
      'remainingSeconds': state.remainingSeconds,
      'timedRewardProgress': state.timedRewardProgress,
    };

    await prefs.setString(_gameKey(collectionId, mode), jsonEncode(data));

    final highScoreKey = _highScoreKey(collectionId, mode);
    final currentHighScore = prefs.getInt(highScoreKey) ?? 0;

    if (state.score > currentHighScore) {
      await prefs.setInt(highScoreKey, state.score);
    }
  }

  static Future<GameState?> loadGame(
    String collectionId, {
    GameMode mode = GameMode.free,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_gameKey(collectionId, mode));

    if (jsonString == null) return null;

    try {
      final data = jsonDecode(jsonString) as Map<String, dynamic>;

      final board = (data['board'] as List)
          .map<int?>((value) => value == null ? null : value as int)
          .toList();

      if (board.length != 9) return null;

      // Old saves derive progress from the board without discarding the game.
      final boardHighest = board.whereType<int>().fold<int>(
        1,
        (a, b) => a > b ? a : b,
      );
      final savedHighest =
          data['highestDiscoveredLevel'] as int? ?? boardHighest;

      return GameState(
        board: board,
        score: data['score'] as int? ?? 0,
        moves: data['moves'] as int? ?? 0,
        highestDiscoveredLevel: savedHighest > boardHighest
            ? savedHighest
            : boardHighest,
        pairsMerged: data['pairsMerged'] as int? ?? 0,
        maxLevelCelebrations: data['maxLevelCelebrations'] as int? ?? 0,
        maxLevelNoticeShownFor: data['maxLevelNoticeShownFor'] as int? ?? 0,
        isGameOver: data['isGameOver'] as bool? ?? false,
        remainingSeconds: data['remainingSeconds'] as int? ?? 14,
        timedRewardProgress: data['timedRewardProgress'] as int? ?? 0,
      );
    } catch (_) {
      return null;
    }
  }

  // Thưởng Chơi tự do: đủ 14 cặp nhận xu theo collection đang chơi.
  static Future<int> recordMergedPairs(
    int pairs, {
    required String collectionId,
  }) async {
    if (pairs <= 0) return 0;

    final prefs = await SharedPreferences.getInstance();

    final oldProgress = prefs.getInt(_coinProgressKey) ?? 0;
    final oldTotalPairs = prefs.getInt(_totalPairsKey) ?? 0;
    final oldCoins = prefs.getInt(_totalCoinsKey) ?? 0;

    final newProgress = oldProgress + pairs;
    final rewards = newProgress ~/ pairsPerReward;
    final remainingProgress = newProgress % pairsPerReward;
    final earnedCoins = rewards * coinsPerReward(collectionId);

    await prefs.setInt(_coinProgressKey, remainingProgress);
    await prefs.setInt(_totalPairsKey, oldTotalPairs + pairs);
    await prefs.setInt(_totalCoinsKey, oldCoins + earnedCoins);

    return earnedCoins;
  }

  // Thưởng Thử thách thời gian: mỗi mốc 5 cặp nhận 10 xu
  static Future<int> recordTimedMergedPair({
    required int pairs,
    required bool reward,
  }) async {
    if (pairs <= 0) return 0;

    final prefs = await SharedPreferences.getInstance();

    final oldTotalPairs = prefs.getInt(_totalPairsKey) ?? 0;
    final oldCoins = prefs.getInt(_totalCoinsKey) ?? 0;

    final earnedCoins = reward ? timedCoinsPerReward : 0;

    await prefs.setInt(_totalPairsKey, oldTotalPairs + pairs);

    if (earnedCoins > 0) {
      await prefs.setInt(_totalCoinsKey, oldCoins + earnedCoins);
    }

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

  static Future<Set<String>> loadUnlockedCollections() async {
    final prefs = await SharedPreferences.getInstance();

    return (prefs.getStringList(_unlockedCollectionsKey) ?? []).toSet();
  }

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

  // Đọc kỷ lục riêng theo bộ ảnh và chế độ
  static Future<int> loadHighScore(
    String collectionId, {
    GameMode mode = GameMode.free,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.getInt(_highScoreKey(collectionId, mode)) ?? 0;
  }

  static Future<void> clearGame(
    String collectionId, {
    GameMode mode = GameMode.free,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_gameKey(collectionId, mode));
  }
}

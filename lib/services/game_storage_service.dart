import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/game_mode.dart';
import '../models/game_state.dart';

class GameStorageService {
  static const int pairsPerReward = 14;
  static const Map<String, int> collectionRewardCoins = {
    'collection_1': 11,
    'collection_2': 14,
    'collection_3': 22,
    'collection_4': 24,
    'collection_5': 28,
    'collection_6': 30,
  };
  static int coinsPerReward(String collectionId) =>
      collectionRewardCoins[collectionId] ?? 11;
  static const int timedPairsPerReward = 5;
  static const int timedCoinsPerReward = 10;

  static const String playerDataKey = 'player_data_v1';
  static Future<void> _pending = Future<void>.value();

  static String _gameKey(String id, [GameMode mode = GameMode.free]) =>
      mode == GameMode.free ? 'game_$id' : 'game_${id}_${mode.storageKey}';
  static String _highScoreKey(String id, [GameMode mode = GameMode.free]) =>
      mode == GameMode.free
      ? 'high_score_$id'
      : 'high_score_${id}_${mode.storageKey}';

  /// All reads and writes share one queue. A failed save does not poison it.
  /// Commit one JSON value, never separate wallet/progress/unlock writes.
  static Future<T> _access<T>(
    T Function(_PlayerData data) action, {
    bool write = false,
  }) {
    final result = Completer<T>();
    _pending = _pending.then((_) async {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.reload();
        final raw = prefs.getString(playerDataKey);
        final data = raw == null
            ? _PlayerData.fromLegacy(prefs)
            : _PlayerData.decode(raw);
        final value = action(data);
        if (write || raw == null) {
          final saved = await prefs.setString(
            playerDataKey,
            jsonEncode(data.toJson()),
          );
          if (!saved) throw StateError('Không lưu được tiến độ trên thiết bị.');
        }
        result.complete(value);
      } catch (error, stack) {
        result.completeError(error, stack);
      }
    });
    return result.future;
  }

  static void _saveGame(
    _PlayerData data,
    String id,
    GameState state,
    GameMode mode,
  ) {
    data.games[_gameKey(id, mode)] = jsonEncode({
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
    });
    final key = _highScoreKey(id, mode);
    if (state.score > (data.highScores[key] ?? 0)) {
      data.highScores[key] = state.score;
    }
  }

  static Future<void> saveGame(
    String collectionId,
    GameState state, {
    GameMode mode = GameMode.free,
  }) => _access(
    (data) => _saveGame(data, collectionId, state, mode),
    write: true,
  );

  static Future<GameState?> loadGame(
    String collectionId, {
    GameMode mode = GameMode.free,
  }) => _access((data) {
    final raw = data.games[_gameKey(collectionId, mode)];
    if (raw == null) return null;
    try {
      final game = jsonDecode(raw) as Map<String, dynamic>;
      final board = (game['board'] as List)
          .map<int?>((v) => v == null ? null : v as int)
          .toList();
      if (board.length != 9) return null;
      final highest = board.whereType<int>().fold<int>(
        1,
        (a, b) => a > b ? a : b,
      );
      final savedHighest = game['highestDiscoveredLevel'] as int? ?? highest;
      return GameState(
        board: board,
        score: game['score'] as int? ?? 0,
        moves: game['moves'] as int? ?? 0,
        highestDiscoveredLevel: savedHighest > highest ? savedHighest : highest,
        pairsMerged: game['pairsMerged'] as int? ?? 0,
        maxLevelCelebrations: game['maxLevelCelebrations'] as int? ?? 0,
        maxLevelNoticeShownFor: game['maxLevelNoticeShownFor'] as int? ?? 0,
        isGameOver: game['isGameOver'] as bool? ?? false,
        remainingSeconds: game['remainingSeconds'] as int? ?? 14,
        timedRewardProgress: game['timedRewardProgress'] as int? ?? 0,
      );
    } catch (_) {
      return null;
    }
  });

  static int _reward(
    _PlayerData data,
    int pairs,
    String collectionId,
    GameMode mode,
    bool timedReward,
  ) {
    if (pairs <= 0) return 0;
    data.totalPairs += pairs;
    final int earned;
    if (mode == GameMode.free) {
      final progress = data.coinProgress + pairs;
      earned = (progress ~/ pairsPerReward) * coinsPerReward(collectionId);
      data.coinProgress = progress % pairsPerReward;
    } else {
      earned = timedReward ? timedCoinsPerReward : 0;
    }
    data.coins += earned;
    return earned;
  }

  /// Save the board and its reward together; use the captured move's state.
  static Future<int> recordMergeAndSaveGame(
    String collectionId,
    GameState state, {
    required int pairs,
    GameMode mode = GameMode.free,
  }) => _access((data) {
    final earned = _reward(
      data,
      pairs,
      collectionId,
      mode,
      state.timedRewardProgress > 0 &&
          state.timedRewardProgress % timedPairsPerReward == 0,
    );
    _saveGame(data, collectionId, state, mode);
    return earned;
  }, write: true);

  static Future<int> recordMergedPairs(
    int pairs, {
    required String collectionId,
  }) {
    if (pairs <= 0) return Future.value(0);
    return _access(
      (data) => _reward(data, pairs, collectionId, GameMode.free, false),
      write: true,
    );
  }

  static Future<int> recordTimedMergedPair({
    required int pairs,
    required bool reward,
  }) {
    if (pairs <= 0) return Future.value(0);
    return _access(
      (data) => _reward(data, pairs, '', GameMode.timed, reward),
      write: true,
    );
  }

  static Future<int> loadTotalCoins() => _access((data) => data.coins);
  static Future<int> loadCoinProgress() => _access((data) => data.coinProgress);
  static Future<int> loadTotalPairs() => _access((data) => data.totalPairs);
  static Future<Set<String>> loadUnlockedCollections() =>
      _access((data) => {...data.unlocked});

  static Future<bool> spendCoins(int amount) {
    if (amount < 0) return Future.value(false);
    return _access((data) {
      if (data.coins < amount) return false;
      data.coins -= amount;
      return true;
    }, write: true);
  }

  static Future<bool> unlockCollection(String collectionId, int price) {
    if (price < 0) return Future.value(false);
    return _access((data) {
      if (data.unlocked.contains(collectionId)) return true;
      if (data.coins < price) return false;
      data.coins -= price;
      data.unlocked.add(collectionId);
      return true;
    }, write: true);
  }

  static Future<int> loadHighScore(
    String collectionId, {
    GameMode mode = GameMode.free,
  }) => _access(
    (data) => data.highScores[_highScoreKey(collectionId, mode)] ?? 0,
  );
  static Future<void> clearGame(
    String collectionId, {
    GameMode mode = GameMode.free,
  }) => _access<void>((data) {
    data.games.remove(_gameKey(collectionId, mode));
  }, write: true);

  // Recovery credentials stay on this device and are never part of a backup.
  static Future<String> exportBackup() =>
      _access((data) => jsonEncode(data.toJson(includeBackupLink: false)));

  static Future<Map<String, dynamic>?> loadBackupLink() => _access(
    (data) => data.backupLink == null
        ? null
        : jsonDecode(jsonEncode(data.backupLink)) as Map<String, dynamic>,
  );

  static Future<void> saveBackupLink(Map<String, dynamic>? link) =>
      _access<void>((data) {
        data.backupLink = link == null
            ? null
            : jsonDecode(jsonEncode(link)) as Map<String, dynamic>;
      }, write: true);

  static Map<String, dynamic> validateBackup(String raw) {
    if (utf8.encode(raw).length > 16384) {
      throw const FormatException('Bản sao lưu quá lớn.');
    }
    final data = _PlayerData.decode(raw);
    if (data.coins > 999999999999999 ||
        data.totalPairs > 999999999999999 ||
        data.unlocked.any((id) => !collectionRewardCoins.containsKey(id)) ||
        data.games.length > 12 ||
        data.highScores.length > 12) {
      throw const FormatException('Bản sao lưu không hợp lệ.');
    }
    for (final entry in data.games.entries) {
      if (!RegExp(r'^game_collection_[1-6](_timed)?$').hasMatch(entry.key)) {
        throw const FormatException('Bộ ảnh không hợp lệ.');
      }
      final game = jsonDecode(entry.value) as Map<String, dynamic>;
      final board = game['board'] as List;
      if (board.length != 9 ||
          board.any((v) => v != null && (v is! int || v < 1 || v > 256))) {
        throw const FormatException('Bàn chơi không hợp lệ.');
      }
      for (final key in [
        'score',
        'moves',
        'pairsMerged',
        'highestDiscoveredLevel',
        'maxLevelCelebrations',
        'maxLevelNoticeShownFor',
        'remainingSeconds',
        'timedRewardProgress',
      ]) {
        final value = game[key];
        if (value != null &&
            (value is! int || value < 0 || value > 999999999999999)) {
          throw const FormatException('Tiến độ không hợp lệ.');
        }
      }
      if (game['isGameOver'] != null && game['isGameOver'] is! bool) {
        throw const FormatException('Trạng thái ván không hợp lệ.');
      }
    }
    for (final entry in data.highScores.entries) {
      if (!RegExp(
            r'^high_score_collection_[1-6](_timed)?$',
          ).hasMatch(entry.key) ||
          entry.value < 0) {
        throw const FormatException('Kỷ lục không hợp lệ.');
      }
    }
    return data.toJson(includeBackupLink: false);
  }

  static Future<void> restoreBackup(String raw, Map<String, dynamic> link) {
    final restored = _PlayerData.decode(jsonEncode(validateBackup(raw)));
    return _access<void>((data) {
      data.coins = restored.coins;
      data.coinProgress = restored.coinProgress;
      data.totalPairs = restored.totalPairs;
      data.unlocked
        ..clear()
        ..addAll(restored.unlocked);
      data.games
        ..clear()
        ..addAll(restored.games);
      data.highScores
        ..clear()
        ..addAll(restored.highScores);
      data.backupLink = jsonDecode(jsonEncode(link)) as Map<String, dynamic>;
    }, write: true);
  }
}

class _PlayerData {
  Map<String, dynamic>? backupLink;
  int coins;
  int coinProgress;
  int totalPairs;
  final Set<String> unlocked;
  final Map<String, String> games;
  final Map<String, int> highScores;

  _PlayerData({
    required this.coins,
    required this.coinProgress,
    required this.totalPairs,
    required this.unlocked,
    required this.games,
    required this.highScores,
    this.backupLink,
  });

  factory _PlayerData.fromLegacy(SharedPreferences prefs) => _PlayerData(
    coins: prefs.getInt('player_total_coins') ?? 0,
    coinProgress: prefs.getInt('player_coin_progress') ?? 0,
    totalPairs: prefs.getInt('player_total_pairs') ?? 0,
    unlocked: (prefs.getStringList('unlocked_collections') ?? []).toSet(),
    games: {
      for (final key in prefs.getKeys())
        if (key.startsWith('game_collection_')) key: prefs.getString(key)!,
    },
    highScores: {
      for (final key in prefs.getKeys())
        if (key.startsWith('high_score_collection_')) key: prefs.getInt(key)!,
    },
  );

  factory _PlayerData.decode(String raw) {
    // Never replace corrupt or unknown-version player data with an empty wallet.
    final json = jsonDecode(raw) as Map<String, dynamic>;
    if (json['version'] != 1) {
      throw const FormatException('Phiên bản lưu chưa được hỗ trợ.');
    }
    final data = _PlayerData(
      coins: json['coins'] as int,
      coinProgress: json['coinProgress'] as int,
      totalPairs: json['totalPairs'] as int,
      unlocked: (json['unlocked'] as List).cast<String>().toSet(),
      games: Map<String, String>.from(json['games'] as Map),
      highScores: Map<String, int>.from(json['highScores'] as Map),
      backupLink: json['backupLink'] == null
          ? null
          : Map<String, dynamic>.from(json['backupLink'] as Map),
    );
    if (data.coins < 0 ||
        data.coinProgress < 0 ||
        data.coinProgress >= GameStorageService.pairsPerReward ||
        data.totalPairs < 0) {
      throw const FormatException('Dữ liệu tiến độ không hợp lệ.');
    }
    return data;
  }

  Map<String, Object> toJson({bool includeBackupLink = true}) => {
    'version': 1,
    'coins': coins,
    'coinProgress': coinProgress,
    'totalPairs': totalPairs,
    'unlocked': unlocked.toList()..sort(),
    'games': games,
    'highScores': highScores,
    if (includeBackupLink && backupLink != null) 'backupLink': backupLink!,
  };
}

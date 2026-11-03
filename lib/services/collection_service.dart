import 'package:flutter/services.dart';

import '../models/game_collection.dart';

class CollectionService {
  // Những bộ sưu tập miễn phí
  static const Set<String> freeCollections = {
    'collection_1',
    'collection_test',
  };

  // Giá mở khóa riêng cho từng bộ sưu tập
  static const Map<String, int> collectionPrices = {'collection_2': 26};

  // Tên hiển thị của từng bộ sưu tập
  static const Map<String, String> collectionNames = {
    'collection_1': 'ATVNCG',
    'collection_2': 'by cacaomewmew',
    'collection_test': 'test',
  };

  // Kiểm tra bộ sưu tập có miễn phí không
  static bool isFree(String collectionId) {
    return freeCollections.contains(collectionId);
  }

  // Lấy giá mở khóa riêng
  static int? unlockPrice(String collectionId) {
    return collectionPrices[collectionId];
  }

  // Tải danh sách bộ sưu tập từ AssetManifest
  static Future<List<GameCollection>> loadCollections() async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final assets = manifest.listAssets();

    final Map<String, Set<int>> collectionLevels = {};

    // Nhận diện collection_1, collection_2, collection_test,...
    final pattern = RegExp(
      r'^assets/collections/(collection_[^/]+)/(\d+)\.jpg$',
    );

    for (final asset in assets) {
      final match = pattern.firstMatch(asset);

      if (match == null) continue;

      final collectionId = match.group(1)!;
      final fileNumber = int.parse(match.group(2)!);

      collectionLevels.putIfAbsent(collectionId, () => <int>{}).add(fileNumber);
    }

    final collections = collectionLevels.entries.map((entry) {
      final levels = entry.value;
      final collectionId = entry.key;
      final collectionNumber = collectionId.split('_').last;

      return GameCollection(
        id: collectionId,
        name: collectionNames[collectionId] ?? 'Bộ ảnh $collectionNumber',
        maxLevel: levels.length,
        availableLevels: levels,
      );
    }).toList();

    collections.sort((a, b) => a.id.compareTo(b.id));

    return collections;
  }
}

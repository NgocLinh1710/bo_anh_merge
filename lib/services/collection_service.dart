import 'package:flutter/services.dart';

import '../models/game_collection.dart';

class CollectionService {
  // Đặt tên riêng cho từng bộ ảnh
  static const Map<String, String> collectionNames = {
    'collection_1': 'ATVNCG',
    'collection_2': 'by cacaomewmew',
  };

  static Future<List<GameCollection>> loadCollections() async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final assets = manifest.listAssets();

    final Map<String, Set<int>> collectionLevels = {};

    final pattern = RegExp(r'^assets/collections/(collection_\d+)/(\d+)\.jpg$');

    for (final asset in assets) {
      final match = pattern.firstMatch(asset);

      if (match == null) continue;

      final collectionId = match.group(1)!;
      final fileNumber = int.parse(match.group(2)!);

      collectionLevels.putIfAbsent(collectionId, () => <int>{});

      collectionLevels[collectionId]!.add(fileNumber);
    }

    final collections = collectionLevels.entries.map((entry) {
      final levels = entry.value;

      final collectionNumber = entry.key.split('_').last;

      return GameCollection(
        id: entry.key,
        name: collectionNames[entry.key] ?? 'Bộ ảnh $collectionNumber',
        maxLevel: levels.length,
        availableLevels: levels,
      );
    }).toList();

    collections.sort((a, b) => a.id.compareTo(b.id));

    return collections;
  }
}

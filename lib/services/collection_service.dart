import 'package:flutter/services.dart';

import '../models/game_collection.dart';
import '../models/game_mode.dart';

class CollectionService {
  // Những ver free
  static const Set<String> freeCollections = {'collection_2'};

  // Giá mở khóa riêng cho từng ver
  static const Map<String, int> collectionPrices = {
    'collection_3': 110,
    'collection_4': 1110,
    'collection_5': 111,
    'collection_8': 1402,
  };

  // Tên hiển thị của từng ver
  static const Map<String, String> collectionNames = {
    'collection_2': 'Bơ sticker',
    'collection_3': 'Bơ chinh',
    'collection_4': 'Bơ bad',
    'collection_5': 'Bơ meme',
    'collection_8': 'Bơ sticker promax',
  };

  // Cấu hình các chế độ được phép chơi
  static const Map<String, List<GameMode>> collectionModes = {
    'collection_2': [GameMode.free, GameMode.timed],
    'collection_3': [GameMode.free, GameMode.timed],
    'collection_4': [GameMode.free, GameMode.timed],
    'collection_5': [GameMode.free, GameMode.timed],
    'collection_8': [GameMode.free],
  };

  // Cấu hình nhóm âm thanh chiến thắng
  static const Map<String, String> collectionSoundGroups = {
    'collection_2': 'sound_1',
    'collection_3': 'sound_1',
    'collection_4': 'sound_1',
    'collection_5': 'sound_2',
    'collection_8': 'sound_2',
  };

  static const Set<String> supportedExtensions = {
    '.jpg',
    '.jpeg',
    '.png',
    '.webp',
  };

  static bool isFree(String collectionId) {
    return freeCollections.contains(collectionId);
  }

  static int? unlockPrice(String collectionId) {
    return collectionPrices[collectionId];
  }

  static List<GameMode> availableModes(String collectionId) {
    return collectionModes[collectionId] ?? const [GameMode.free];
  }

  static String victorySoundGroup(String collectionId) {
    return collectionSoundGroups[collectionId] ?? 'sound_1';
  }

  static Future<List<GameCollection>> loadCollections() async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final assets = manifest.listAssets();

    // Lưu danh sách đường dẫn ảnh theo từng ver
    final Map<String, List<String>> collectionImages = {};

    for (final asset in assets) {
      final parts = asset.split('/');

      if (parts.length != 4) continue;
      if (parts[0] != 'assets' || parts[1] != 'collections') {
        continue;
      }

      final collectionId = parts[2];
      final fileName = parts[3];

      if (!collectionId.startsWith('collection_')) {
        continue;
      }

      final extension = fileName.contains('.')
          ? fileName.substring(fileName.lastIndexOf('.')).toLowerCase()
          : '';

      if (!supportedExtensions.contains(extension)) {
        continue;
      }

      collectionImages.putIfAbsent(collectionId, () => <String>[]).add(asset);
    }

    final collections = collectionImages.entries.map((entry) {
      final collectionId = entry.key;
      final images = entry.value;

      // Sắp xếp theo tên file để thứ tự cấp độ ổn định
      images.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

      // Tạo cấp độ tuần tự từ 1 đến số ảnh
      final Map<int, String> imagePaths = {};

      for (int i = 0; i < images.length; i++) {
        imagePaths[i + 1] = images[i];
      }

      final levels = imagePaths.keys.toSet();

      final collectionNumber = collectionId.split('_').last;

      return GameCollection(
        id: collectionId,
        name: collectionNames[collectionId] ?? 'Bộ ảnh $collectionNumber',
        maxLevel: images.length,
        availableLevels: levels,
        imagePaths: imagePaths,
        availableModes: availableModes(collectionId),
        victorySoundGroup: victorySoundGroup(collectionId),
      );
    }).toList();

    collections.sort((a, b) {
      final numberA = int.tryParse(a.id.split('_').last) ?? 0;
      final numberB = int.tryParse(b.id.split('_').last) ?? 0;
      return numberA.compareTo(numberB);
    });

    return collections;
  }
}

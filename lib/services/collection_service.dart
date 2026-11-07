import 'package:flutter/services.dart';

import '../models/game_collection.dart';
import '../models/game_mode.dart';

class CollectionService {
  // Những ver free
  static const Set<String> freeCollections = {'collection_1'};

  // Giá mở khóa riêng cho từng ver
  static const Map<String, int> collectionPrices = {
    'collection_2': 111,
    'collection_3': 142,
    'collection_4': 250,
    'collection_5': 350,
    'collection_6': 1402,
  };

  // Tên hiển thị của từng ver
  static const Map<String, String> collectionNames = {
    'collection_1': 'BƠ VƯỢT GAI',
    'collection_2': 'BƠ BẠN TRAI',
    'collection_3': 'BƠ CHINH',
    'collection_4': 'BƠ NGẦU ĐÉT',
    'collection_5': 'BƠ MEME',
    'collection_6': 'BƠ 52 LÁ',
  };

  static const Map<String, String> collectionDescriptions = {
    'collection_1': 'Chương trình 6 chữ',
    'collection_2': 'Người phụ nữ của anh',
    'collection_3': 'Một nụ cười bằng 14 Casper',
    'collection_4': 'Em bảo bọn anh trông như nào ấy nhở?',
    'collection_5': 'Anh không gà đâu!?',
    'collection_6': 'Lá bài phép thuật',
  };

  // Cấu hình các chế độ được phép chơi
  static const Map<String, List<GameMode>> collectionModes = {
    'collection_1': [GameMode.free, GameMode.timed],
    'collection_2': [GameMode.free, GameMode.timed],
    'collection_3': [GameMode.free, GameMode.timed],
    'collection_4': [GameMode.free, GameMode.timed],
    'collection_5': [GameMode.free, GameMode.timed],
    'collection_6': [GameMode.free],
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

  // Tên không có số đứng trước các ảnh đánh số; tên là tiêu chí phụ khi trùng số.
  static int compareImagePaths(String a, String b) {
    final nameA = a.split('/').last.toLowerCase();
    final nameB = b.split('/').last.toLowerCase();
    final numberA = int.tryParse(RegExp(r'^\d+').stringMatch(nameA) ?? '');
    final numberB = int.tryParse(RegExp(r'^\d+').stringMatch(nameB) ?? '');
    if (numberA != numberB) {
      if (numberA == null) return -1;
      if (numberB == null) return 1;
      return numberA.compareTo(numberB);
    }
    return nameA.compareTo(nameB);
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

      images.sort(compareImagePaths);

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
        description: collectionDescriptions[collectionId] ?? '',
        maxLevel: images.length,
        availableLevels: levels,
        imagePaths: imagePaths,
        availableModes: availableModes(collectionId),
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

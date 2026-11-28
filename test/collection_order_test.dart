import 'dart:ui' as ui;

import 'package:bo_anh/services/collection_service.dart';
import 'package:bo_anh/utils/game_logic.dart';
import 'package:bo_anh/models/game_state.dart';
import 'package:bo_anh/models/game_mode.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'numeric prefix ordering supports gaps, suffixes and mixed extensions',
    () {
      final paths = ['10 - Threads.jpg', '2.png', '1.jpg', '5.JPG', '20.webp'];
      paths.sort(CollectionService.compareImagePaths);
      expect(paths, ['1.jpg', '2.png', '5.JPG', '10 - Threads.jpg', '20.webp']);
    },
  );

  test(
    'bundled collections use sequential levels with the highest number last',
    () async {
      final collections = await CollectionService.loadCollections();
      expect(collections.map((c) => c.id), [
        for (var n = 1; n <= 8; n++) 'collection_$n',
      ]);
      for (final collection in collections) {
        expect(collection.availableLevels, {
          for (var n = 1; n <= collection.maxLevel; n++) n,
        });
        final paths = collection.imagePaths.values.toList();
        final sorted = [...paths]..sort(CollectionService.compareImagePaths);
        expect(paths, sorted);
        expect(collection.imagePath(collection.maxLevel), sorted.last);
        final board = List<int?>.filled(9, 1);
        board[0] = board[1] = collection.maxLevel - 1;
        final state = GameLogic.merge(
          GameState(board: board),
          0,
          1,
          collection.maxLevel,
        );
        expect(state.maxLevelCelebrations, 1);
        expect(state.board[1], collection.maxLevel);
      }
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      for (var n = 1; n <= 8; n++) {
        expect(
          manifest.listAssets(),
          contains('assets/sounds/sound_secret/Sound $n.mp3'),
        );
      }
    },
  );

  test('new versions expose their modes and animated final image', () async {
    final collections = await CollectionService.loadCollections();
    final seven = collections.singleWhere((c) => c.id == 'collection_7');
    final eight = collections.singleWhere((c) => c.id == 'collection_8');
    expect(seven.name, 'BƠ XÉ');
    expect(eight.name, 'BƠ ÁO MAY Ô');
    expect(seven.maxLevel, 3);
    expect(eight.maxLevel, 4);
    for (final collection in [seven, eight]) {
      expect(collection.availableModes, [GameMode.free, GameMode.timed]);
      expect(CollectionService.isFree(collection.id), isFalse);
    }
    expect(CollectionService.unlockPrice(seven.id), 111);
    expect(CollectionService.unlockPrice(eight.id), 142);
    final path = seven.imagePath(seven.maxLevel);
    expect(path, endsWith('.gif'));
    final data = await rootBundle.load(path);
    final codec = await ui.instantiateImageCodec(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    );
    expect(codec.frameCount, greaterThan(1));
    codec.dispose();
  });
}

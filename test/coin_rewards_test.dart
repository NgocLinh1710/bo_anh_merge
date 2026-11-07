import 'package:bo_anh/services/game_storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'each collection awards its configured coins only at 14 pairs',
    () async {
      const rewards = [11, 14, 22, 24, 28, 30];
      for (var i = 0; i < rewards.length; i++) {
        SharedPreferences.setMockInitialValues({});
        final id = 'collection_${i + 1}';
        expect(GameStorageService.coinsPerReward(id), rewards[i]);
        expect(
          await GameStorageService.recordMergedPairs(13, collectionId: id),
          0,
        );
        expect(await GameStorageService.loadCoinProgress(), 13);
        expect(
          await GameStorageService.recordMergedPairs(1, collectionId: id),
          rewards[i],
        );
        expect(await GameStorageService.loadTotalCoins(), rewards[i]);
        expect(await GameStorageService.loadCoinProgress(), 0);
        expect(await GameStorageService.loadTotalPairs(), 14);
      }
    },
  );

  test(
    'multiple rewards retain remainder and add to existing wallet',
    () async {
      SharedPreferences.setMockInitialValues({'player_total_coins': 100});
      expect(
        await GameStorageService.recordMergedPairs(
          30,
          collectionId: 'collection_6',
        ),
        60,
      );
      expect(await GameStorageService.loadCoinProgress(), 2);
      expect(await GameStorageService.loadTotalCoins(), 160);
    },
  );

  test('existing shared progress is preserved across collections', () async {
    SharedPreferences.setMockInitialValues({'player_coin_progress': 13});
    expect(
      await GameStorageService.recordMergedPairs(
        1,
        collectionId: 'collection_2',
      ),
      14,
    );
    expect(await GameStorageService.loadCoinProgress(), 0);
  });

  test(
    'timed rewards remain 10 coins and do not affect free progress',
    () async {
      SharedPreferences.setMockInitialValues({'player_coin_progress': 7});
      expect(
        await GameStorageService.recordTimedMergedPair(pairs: 1, reward: false),
        0,
      );
      expect(
        await GameStorageService.recordTimedMergedPair(pairs: 1, reward: true),
        10,
      );
      expect(await GameStorageService.loadTotalCoins(), 10);
      expect(await GameStorageService.loadCoinProgress(), 7);
    },
  );
}

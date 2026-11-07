import 'dart:async';

import 'package:bo_anh/services/sound_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late List<String> played;
  late SoundPlaybackController audio;
  setUp(() {
    played = [];
    audio = SoundPlaybackController(
      loadNormalSounds: () async => [
        'sounds/sound_normal/a.mp3',
        'sounds/sound_normal/b.mp3',
      ],
      playAsset: (path) async {
        played.add(path);
      },
      stopPlayer: () async {},
    );
  });

  test(
    'reward selects one normal sound; each collection selects its exact secret',
    () async {
      await audio.playReward();
      expect(played, hasLength(1));
      expect(played.single, startsWith('sounds/sound_normal/'));
      for (var n = 1; n <= 6; n++) {
        await audio.playSecret('collection_$n');
        expect(played.last, 'sounds/sound_secret/Sound $n.mp3');
        audio.onComplete();
      }
      expect(played, hasLength(7));
    },
  );

  test(
    'secret suppresses simultaneous and subsequent rewards until completion',
    () async {
      final secret = audio.playSecret('collection_2');
      await audio.playReward();
      await secret;
      await audio.playReward();
      expect(played, ['sounds/sound_secret/Sound 2.mp3']);
      audio.onComplete();
      await audio.playReward();
      expect(played, hasLength(2));
    },
  );

  test('slow normal asset lookup cannot overwrite a later secret', () async {
    final lookup = Completer<List<String>>();
    audio = SoundPlaybackController(
      loadNormalSounds: () => lookup.future,
      playAsset: (path) async {
        played.add(path);
      },
      stopPlayer: () async {},
    );
    final reward = audio.playReward();
    await audio.playSecret('collection_6');
    audio.onComplete();
    lookup.complete(['sounds/sound_normal/a.mp3']);
    await reward;
    expect(played, ['sounds/sound_secret/Sound 6.mp3']);
  });

  test('leaving game cancels a secret not yet started', () async {
    final secret = audio.playSecret('collection_1');
    await audio.stop();
    await secret;
    expect(played, isEmpty);
  });

  test(
    'missing secret does not permanently block later reward sounds',
    () async {
      audio = SoundPlaybackController(
        loadNormalSounds: () async => ['sounds/sound_normal/a.mp3'],
        playAsset: (path) async {
          if (path.contains('sound_secret')) throw StateError('Unavailable');
          played.add(path);
        },
        stopPlayer: () async {},
      );
      await audio.playSecret('collection_1');
      await audio.playReward();
      expect(played, ['sounds/sound_normal/a.mp3']);
    },
  );
}

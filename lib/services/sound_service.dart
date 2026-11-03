import 'dart:math';

import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';

class SoundService {
  static final AudioPlayer _player = AudioPlayer();
  static final Random _random = Random();

  static Future<void> playRandomVictorySound() async {
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      final assets = manifest.listAssets();

      final soundFiles = assets
          .where(
            (path) =>
                path.startsWith('assets/sounds/') &&
                path.toLowerCase().endsWith('.mp3'),
          )
          .toList();

      if (soundFiles.isEmpty) return;

      final selectedSound = soundFiles[_random.nextInt(soundFiles.length)];

      await _player.stop();

      await _player.play(
        AssetSource(selectedSound.replaceFirst('assets/', '')),
      );
    } catch (e) {
      // Không để lỗi âm thanh làm gián đoạn trò chơi
    }
  }

  static Future<void> stop() async {
    await _player.stop();
  }

  static Future<void> dispose() async {
    await _player.dispose();
  }
}

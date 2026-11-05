import 'dart:math';

import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';

class SoundService {
  static final AudioPlayer _player = AudioPlayer();
  static final Random _random = Random();

  // Phát ngẫu nhiên một âm thanh trong nhóm được chỉ định
  static Future<void> playRandomVictorySound(
    String soundGroup, {
    bool loop = false,
  }) async {
    try {
      final normalizedGroup = soundGroup.trim();

      if (normalizedGroup.isEmpty ||
          normalizedGroup.contains('/') ||
          normalizedGroup.contains(r'\')) {
        return;
      }

      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      final assets = manifest.listAssets();

      final targetFolder = 'assets/sounds/$normalizedGroup/';

      final soundFiles = assets.where((path) {
        return path.startsWith(targetFolder) &&
            path.toLowerCase().endsWith('.mp3');
      }).toList();

      if (soundFiles.isEmpty) return;

      final selectedSound = soundFiles[_random.nextInt(soundFiles.length)];

      await _player.stop();

      // Cấu hình chế độ phát
      await _player.setReleaseMode(
        loop ? ReleaseMode.loop : ReleaseMode.release,
      );

      await _player.play(
        AssetSource(selectedSound.replaceFirst('assets/', '')),
      );
    } catch (e) {}
  }

  // Dừng âm thanh đang phát
  static Future<void> stop() async {
    await _player.stop();

    await _player.setReleaseMode(ReleaseMode.release);
  }

  static Future<void> dispose() async {
    await _player.dispose();
  }
}

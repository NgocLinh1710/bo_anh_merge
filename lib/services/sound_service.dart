import 'dart:async';
import 'dart:math';

import 'package:flutter/services.dart';
import 'sound_backend_native.dart'
    if (dart.library.js_interop) 'sound_backend_web.dart';

/// Serializes player commands and reserves priority when secret is requested.
class SoundPlaybackController {
  SoundPlaybackController({
    required this.loadNormalSounds,
    required this.playAsset,
    required this.stopPlayer,
  });

  final Future<List<String>> Function() loadNormalSounds;
  final Future<void> Function(String path) playAsset;
  final Future<void> Function() stopPlayer;
  final Random _random = Random();
  Future<void> _pending = Future<void>.value();
  int _generation = 0;
  bool _secretReserved = false;
  int? _activeSecret;

  Future<void> _enqueue(Future<void> Function() action) {
    _pending = _pending.then((_) => action()).catchError((Object error) {
      // Unavailable audio must not interrupt the game or later playback.
    });
    return _pending;
  }

  Future<void> playReward() async {
    if (_secretReserved) return;
    final generation = _generation;
    try {
      final sounds = await loadNormalSounds();
      if (sounds.isEmpty || generation != _generation || _secretReserved) {
        return;
      }
      final path = sounds[_random.nextInt(sounds.length)];
      await _enqueue(() async {
        if (generation != _generation || _secretReserved) return;
        await stopPlayer();
        if (generation != _generation || _secretReserved) return;
        await playAsset(path);
      });
    } catch (_) {
      /* Missing assets do not affect rewards. */
    }
  }

  Future<void> playSecret(String collectionId) {
    final match = RegExp(r'^collection_([1-6])$').firstMatch(collectionId);
    if (match == null) return Future<void>.value();
    final generation = ++_generation;
    _secretReserved = true;
    return _enqueue(() async {
      if (generation != _generation) return;
      try {
        await stopPlayer();
        if (generation != _generation) return;
        _activeSecret = generation;
        await playAsset('sounds/sound_secret/Sound ${match.group(1)}.mp3');
      } catch (_) {
        if (generation == _generation) {
          _secretReserved = false;
          _activeSecret = null;
        }
      }
    });
  }

  void onComplete() {
    if (_activeSecret == _generation) {
      _secretReserved = false;
      _activeSecret = null;
    }
  }

  Future<void> stop() {
    ++_generation;
    _secretReserved = false;
    _activeSecret = null;
    return _enqueue(stopPlayer);
  }
}

class SoundService {
  static final SoundBackend _backend = SoundBackend();
  static final SoundPlaybackController _playback = _createPlayback();

  static SoundPlaybackController _createPlayback() {
    final playback = SoundPlaybackController(
      loadNormalSounds: () async {
        final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
        return manifest
            .listAssets()
            .where(
              (path) =>
                  path.startsWith('assets/sounds/sound_normal/') &&
                  path.toLowerCase().endsWith('.mp3'),
            )
            .map((path) => path.replaceFirst('assets/', ''))
            .toList();
      },
      playAsset: _backend.play,
      stopPlayer: _backend.stop,
    );
    _backend.setOnComplete(playback.onComplete);
    return playback;
  }

  static Future<void> playReward() => _playback.playReward();
  static Future<void> playSecret(String collectionId) =>
      _playback.playSecret(collectionId);
  static Future<void> stop() => _playback.stop();

  static Future<void> dispose() async {
    await _playback.stop();
    await _backend.dispose();
  }
}

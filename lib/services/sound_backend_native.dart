import 'dart:async';
import 'package:audioplayers/audioplayers.dart';

class SoundBackend {
  final AudioPlayer _player = AudioPlayer();
  StreamSubscription<void>? _completion;

  void setOnComplete(void Function() callback) {
    _completion = _player.onPlayerComplete.listen((_) => callback());
  }

  Future<void> play(String path) async {
    await _player.setReleaseMode(ReleaseMode.release);
    await _player.play(AssetSource(path));
  }

  Future<void> stop() => _player.stop();

  Future<void> dispose() async {
    await _completion?.cancel();
    await _player.dispose();
  }
}

import 'dart:js_interop';

@JS('gameSoundEffects.play')
external JSPromise<JSAny?> _play(JSString path);
@JS('gameSoundEffects.stop')
external void _stop();
@JS('gameSoundEffects.setOnComplete')
external void _setOnComplete(JSFunction callback);

class SoundBackend {
  void setOnComplete(void Function() callback) => _setOnComplete(callback.toJS);
  Future<void> play(String path) async {
    await _play(path.toJS).toDart;
  }

  Future<void> stop() async => _stop();
  Future<void> dispose() async => _stop();
}

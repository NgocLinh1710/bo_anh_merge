import 'dart:async';
import 'dart:collection';

import 'package:flutter/services.dart';

/// Shared by visible images and prefetches, so duplicate tiles use one request.
class GameImageService {
  static final bundle = RetryingImageBundle(rootBundle);
}

class RetryingImageBundle extends CachingAssetBundle {
  final AssetBundle source;
  final int maxConcurrent;
  final List<Duration> retryDelays;
  final _queue = Queue<({String key, Completer<ByteData> result})>();
  final _pending = <String, Future<ByteData>>{};
  int _active = 0;

  RetryingImageBundle(
    this.source, {
    this.maxConcurrent = 3,
    this.retryDelays = const [
      Duration(milliseconds: 500),
      Duration(milliseconds: 1500),
    ],
  }) : assert(maxConcurrent > 0);

  @override
  Future<ByteData> load(String key) {
    // Manifest requests should not wait behind image downloads.
    if (!key.startsWith('assets/collections_webp/')) return source.load(key);
    final existing = _pending[key];
    if (existing != null) return existing;
    final result = Completer<ByteData>();
    _pending[key] = result.future;
    _queue.add((key: key, result: result));
    _drain();
    return result.future;
  }

  void _drain() {
    while (_active < maxConcurrent && _queue.isNotEmpty) {
      final request = _queue.removeFirst();
      _active++;
      unawaited(_run(request.key, request.result));
    }
  }

  Future<void> _run(String key, Completer<ByteData> result) async {
    try {
      for (var attempt = 0; ; attempt++) {
        try {
          result.complete(await source.load(key));
          break;
        } catch (_) {
          if (attempt >= retryDelays.length) rethrow;
          await Future<void>.delayed(retryDelays[attempt]);
        }
      }
    } catch (error, stack) {
      result.completeError(error, stack);
    } finally {
      _pending.remove(key);
      _active--;
      _drain();
    }
  }
}

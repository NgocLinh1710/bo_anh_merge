import 'dart:async';

import 'package:bo_anh/services/game_image_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _Bundle extends CachingAssetBundle {
  final Future<ByteData> Function(String) loader;
  _Bundle(this.loader);

  @override
  Future<ByteData> load(String key) => loader(key);
}

void main() {
  const prefix = 'assets/collections_webp/collection_1/';

  test('concurrent tiles share a request and downloads stay bounded', () async {
    final requests = <Completer<ByteData>>[];
    final bundle = RetryingImageBundle(
      _Bundle((key) {
        final request = Completer<ByteData>();
        requests.add(request);
        return request.future;
      }),
      maxConcurrent: 2,
    );
    final first = bundle.load('${prefix}1.hash.webp');
    final duplicate = bundle.load('${prefix}1.hash.webp');
    final second = bundle.load('${prefix}2.hash.webp');
    final third = bundle.load('${prefix}3.hash.webp');
    expect(identical(first, duplicate), isTrue);
    expect(requests, hasLength(2));
    requests[0].complete(ByteData(1));
    await first;
    expect(requests, hasLength(3));
    requests[1].complete(ByteData(1));
    requests[2].complete(ByteData(1));
    await Future.wait([second, third]);
  });

  test(
    'transient failures retry and succeed without failing the image',
    () async {
      var calls = 0;
      final bundle = RetryingImageBundle(
        _Bundle((key) async {
          if (++calls < 3) throw StateError('offline');
          return ByteData(7);
        }),
        retryDelays: [Duration.zero, Duration.zero],
      );
      expect((await bundle.load('${prefix}1.hash.webp')).lengthInBytes, 7);
      expect(calls, 3);
    },
  );

  test(
    'permanent failure is bounded, releases queue and can recover',
    () async {
      var calls = 0;
      var offline = true;
      final bundle = RetryingImageBundle(
        _Bundle((key) async {
          calls++;
          if (offline && key.endsWith('1.hash.webp')) {
            throw StateError('offline');
          }
          return ByteData(1);
        }),
        maxConcurrent: 1,
        retryDelays: [Duration.zero, Duration.zero],
      );
      final failed = bundle.load('${prefix}1.hash.webp');
      final queued = bundle.load('${prefix}2.hash.webp');
      await expectLater(failed, throwsStateError);
      await queued;
      expect(calls, 4);
      offline = false;
      await bundle.load('${prefix}1.hash.webp');
      expect(calls, 5);
    },
  );

  test('manifest requests bypass an occupied image queue', () async {
    final pending = Completer<ByteData>();
    final bundle = RetryingImageBundle(
      _Bundle((key) async {
        if (key.startsWith(prefix)) return pending.future;
        return ByteData(3);
      }),
      maxConcurrent: 1,
    );
    final image = bundle.load('${prefix}1.hash.webp');
    expect((await bundle.load('AssetManifest.bin')).lengthInBytes, 3);
    pending.complete(ByteData(1));
    await image;
  });
}

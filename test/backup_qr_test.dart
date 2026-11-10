import 'dart:typed_data';

import 'package:bo_anh/models/recovery_code.dart';
import 'package:bo_anh/services/backup_qr.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'exported PNG restores the exact recovery code, also after rotation',
    () async {
      final code = RecoveryCode.generate().value;
      final bytes = await BackupQr.encode(code);
      expect(BackupQr.decode(bytes), code);
      final rotated = img.copyRotate(img.decodePng(bytes)!, angle: 90);
      expect(BackupQr.decode(Uint8List.fromList(img.encodePng(rotated))), code);
    },
  );

  test('invalid images are rejected without producing a recovery code', () {
    expect(
      () => BackupQr.decode(Uint8List.fromList([1, 2, 3])),
      throwsFormatException,
    );
    final blank = img.Image(width: 200, height: 200);
    expect(
      () => BackupQr.decode(Uint8List.fromList(img.encodePng(blank))),
      throwsFormatException,
    );
  });
}

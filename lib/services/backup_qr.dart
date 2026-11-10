import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:image/image.dart' as img;
import 'package:qr_flutter/qr_flutter.dart';
import 'package:zxing2/qrcode.dart';

import '../models/recovery_code.dart';

class BackupQr {
  static Future<Uint8List> encode(String code) async {
    RecoveryCode.parse(code);
    final painter = QrPainter(
      data: code,
      version: QrVersions.auto,
      gapless: true,
      errorCorrectionLevel: QrErrorCorrectLevel.M,
    );
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawColor(const ui.Color(0xffffffff), ui.BlendMode.src);
    canvas.translate(48, 48);
    painter.paint(canvas, const ui.Size(672, 672));
    final picture = recorder.endRecording();
    final image = await picture.toImage(768, 768);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) throw StateError('Không tạo được ảnh QR.');
      return data.buffer.asUint8List();
    } finally {
      image.dispose();
      picture.dispose();
    }
  }

  static String decode(Uint8List bytes) {
    try {
      var image = img.decodeImage(bytes);
      if (image == null) throw const FormatException();
      image = img.bakeOrientation(image);
      if (image.width > 2048 || image.height > 2048) {
        image = img.copyResize(
          image,
          width: image.width >= image.height ? 2048 : null,
          height: image.height > image.width ? 2048 : null,
        );
      }
      final pixels = Int32List(image.width * image.height);
      for (final pixel in image) {
        pixels[pixel.y * image.width + pixel.x] =
            (pixel.r.toInt() << 16) | (pixel.g.toInt() << 8) | pixel.b.toInt();
      }
      final source = RGBLuminanceSource(image.width, image.height, pixels);
      final code = QRCodeReader()
          .decode(BinaryBitmap(HybridBinarizer(source)))
          .text;
      return RecoveryCode.parse(code).value;
    } catch (_) {
      throw const FormatException(
        'Ảnh không chứa QR khôi phục hợp lệ. Hãy chọn ảnh QR rõ nét của game.',
      );
    }
  }
}

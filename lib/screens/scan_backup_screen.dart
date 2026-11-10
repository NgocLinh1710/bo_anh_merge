import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../models/recovery_code.dart';

class ScanBackupScreen extends StatefulWidget {
  const ScanBackupScreen({super.key});

  @override
  State<ScanBackupScreen> createState() => _ScanBackupScreenState();
}

class _ScanBackupScreenState extends State<ScanBackupScreen> {
  final controller = MobileScannerController(formats: [BarcodeFormat.qrCode]);
  bool finished = false;
  String? message;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Quét QR khôi phục')),
    body: Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Đưa QR vào camera. Nếu không mở được camera, quay lại và chọn ảnh QR từ bộ sưu tập.',
          ),
        ),
        Expanded(
          child: MobileScanner(
            controller: controller,
            errorBuilder: (context, error) => const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Không mở được camera. Hãy cấp quyền camera và dùng HTTPS, hoặc quay lại chọn ảnh QR.',
                ),
              ),
            ),
            onDetect: (capture) {
              if (finished) return;
              for (final barcode in capture.barcodes) {
                try {
                  final code = RecoveryCode.parse(barcode.rawValue ?? '').value;
                  finished = true;
                  Navigator.pop(context, code);
                  return;
                } on FormatException {
                  if (message == null) {
                    setState(
                      () =>
                          message = 'QR này không phải mã khôi phục của game.',
                    );
                  }
                }
              }
            },
          ),
        ),
        if (message != null)
          Padding(padding: const EdgeInsets.all(16), child: Text(message!)),
      ],
    ),
  );
}

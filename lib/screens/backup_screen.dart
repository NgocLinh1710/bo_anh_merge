import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';

import '../services/backup_qr.dart';
import 'scan_backup_screen.dart';

import '../services/cloud_backup_service.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key, this.service});
  final CloudBackupService? service;
  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  late final CloudBackupService backup;
  String? message;
  bool qrBusy = false;

  @override
  void initState() {
    super.initState();
    backup = widget.service ?? CloudBackupService.instance;
    unawaited(_run(backup.loadLocal));
  }

  Future<bool> _run(Future<void> Function() action, {String? success}) async {
    try {
      await action();
      if (mounted && success != null) {
        setState(() {
          message = success;
        });
      }
      return true;
    } catch (error) {
      if (mounted) {
        setState(() {
          message = error is BackupException || error is FormatException
              ? error.toString()
              : 'Chưa xử lý được bản lưu. Tiến độ trên máy vẫn được giữ.';
        });
      }
      return false;
    }
  }

  Future<bool> _confirm(String title, String text) async =>
      await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(title),
          content: Text(text),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Đồng ý'),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _showCode() async {
    final code = backup.recoveryCode;
    if (code == null) return;
    final bytes = await BackupQr.encode(code);
    if (!mounted) return;
    final mobile =
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
    final filename = 'bo-anh-qr-${backup.playerId}.png';
    final file = XFile.fromData(bytes, mimeType: 'image/png', name: filename);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('QR khôi phục'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Ai có mã này có thể đọc, thay đổi hoặc xóa bản lưu. Hãy cất mã ở nơi riêng ngoài trình duyệt. Mất mã và dữ liệu máy sẽ không thể khôi phục.',
              ),
              const SizedBox(height: 16),
              if (kIsWeb && mobile)
                Image.network(
                  file.path,
                  width: 240,
                  height: 240,
                  webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
                )
              else
                Image.memory(bytes, width: 240, height: 240),
              const Text(
                'Lưu ảnh QR ở nơi riêng tư. QR khôi phục bản lưu server mới nhất; cần mạng khi khôi phục.',
              ),
              const SizedBox(height: 12),
              Text(
                mobile
                    ? 'Bấm Lưu ảnh QR rồi chọn Lưu hình ảnh nếu có. Bạn cũng có thể nhấn giữ ảnh QR để lưu vào Ảnh. Nếu trình duyệt tải ảnh về, mở ảnh trong Tệp/Downloads để lưu vào bộ sưu tập.'
                    : 'Bấm Lưu ảnh QR để tải PNG về thư mục tải xuống của trình duyệt (thường là Downloads).',
              ),
            ],
          ),
        ),
        actions: [
          Builder(
            builder: (buttonContext) => TextButton.icon(
              icon: const Icon(Icons.save_alt),
              label: const Text('Lưu ảnh QR'),
              onPressed: () async {
                await _run(() async {
                  if (kIsWeb && !mobile) {
                    await file.saveTo(filename);
                    return;
                  }
                  final box = buttonContext.findRenderObject() as RenderBox;
                  await SharePlus.instance.share(
                    ShareParams(
                      files: [file],
                      fileNameOverrides: [filename],
                      sharePositionOrigin:
                          box.localToGlobal(Offset.zero) & box.size,
                    ),
                  );
                });
              },
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (backup.recoveryCode == null &&
        !await _confirm(
          'Lưu tiến độ lên server?',
          'Game sẽ gửi xu, bộ đã mở và ván chơi lên Supabase. Không yêu cầu tên, email hay số điện thoại. Hạ tầng có thể ghi IP/nhật ký truy cập. Chỉ lần bấm Lưu mới cập nhật bản sao; hãy giữ mã khôi phục để dùng khi mất dữ liệu máy.',
        )) {
      return;
    }
    if (!mounted) return;
    final saved = await _run(
      backup.save,
      success: 'Đã lưu tiến độ lên server. Hãy cất mã khôi phục.',
    );
    if (saved && mounted && backup.savedAt != null) await _run(_showCode);
  }

  Future<void> _restore(String code) async {
    await _run(() async {
      final preview = await backup.preview(code);
      if (!mounted) return;
      final yes = await _confirm(
        'Thay tiến độ trên máy?',
        'Bản lưu có ${preview.data['coins']} xu. Khôi phục sẽ thay thế toàn bộ tiến độ đang có trên trình duyệt này, không cộng dồn hai số dư.',
      );
      if (!yes || !mounted) return;
      await backup.restore(preview);
      if (mounted) {
        setState(() {
          message = 'Đã khôi phục. Quay lại để tiếp tục chơi.';
        });
      }
    });
  }

  Future<void> _readQr({required bool camera}) async {
    if (qrBusy || backup.busy) return;
    setState(() => qrBusy = true);
    try {
      await _run(() async {
        String? code;
        if (camera) {
          code = await Navigator.of(context).push<String>(
            MaterialPageRoute(builder: (_) => const ScanBackupScreen()),
          );
        } else {
          final image = await ImagePicker().pickImage(
            source: ImageSource.gallery,
          );
          if (image == null) return;
          if (await image.length() > 20 * 1024 * 1024) {
            throw const FormatException(
              'Ảnh quá lớn. Hãy chọn ảnh QR dưới 20 MB.',
            );
          }
          code = await compute(BackupQr.decode, await image.readAsBytes());
        }
        if (code == null || !mounted) return;
        await _restore(code);
      });
    } finally {
      if (mounted) setState(() => qrBusy = false);
    }
  }

  Widget _section({
    required IconData icon,
    required String title,
    required String subtitle,
    required List<Widget> children,
  }) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: colors.outlineVariant.withValues(alpha: 0.65),
        ),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colors.primaryContainer.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: colors.primary, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            subtitle,
            style: TextStyle(color: colors.onSurfaceVariant, height: 1.5),
          ),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }

  ButtonStyle _buttonStyle({bool filled = false}) {
    final colors = Theme.of(context).colorScheme;
    return (filled ? FilledButton.styleFrom : OutlinedButton.styleFrom)(
      minimumSize: const Size.fromHeight(56),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      side: filled
          ? BorderSide.none
          : BorderSide(color: colors.primary.withValues(alpha: 0.3)),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Sao lưu tiến độ')),
    body: ListenableBuilder(
      listenable: backup,
      builder: (context, _) => SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _section(
                  icon: Icons.cloud_done_outlined,
                  title: 'Giữ an toàn tiến độ',
                  subtitle:
                      'Game vẫn tự lưu trên máy. Bấm “Lưu tiến độ” để cập nhật bản sao và giữ lại xu của bạn.',
                  children: [
                    if (backup.playerId != null)
                      SelectableText(
                        'Mã người chơi: ${backup.playerId}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    if (backup.savedAt != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          'Lần lưu server: ${DateTime.tryParse(backup.savedAt!)?.toLocal().toString() ?? backup.savedAt}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    if (backup.recoveryCode != null && backup.savedAt == null)
                      const Text(
                        'Chưa xác nhận bản lưu trên server. Hãy thử lưu lại khi có mạng.',
                      ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      style: _buttonStyle(filled: true),
                      onPressed: (backup.busy || qrBusy) ? null : _save,
                      icon: const Icon(Icons.cloud_upload_outlined),
                      label: const Text('Lưu tiến độ'),
                    ),
                    if (backup.recoveryCode != null) ...[
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        style: _buttonStyle(),
                        icon: const Icon(Icons.qr_code_rounded),
                        onPressed: (backup.busy || qrBusy)
                            ? null
                            : () => _run(_showCode),
                        label: const Text(
                          'Xem QR khôi phục',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 24),
                _section(
                  icon: Icons.restore_rounded,
                  title: 'Khôi phục bằng QR',
                  subtitle:
                      'Chọn ảnh QR đã lưu hoặc dùng camera để lấy lại tiến độ của bạn.',
                  children: [
                    OutlinedButton.icon(
                      style: _buttonStyle(),
                      onPressed: (backup.busy || qrBusy)
                          ? null
                          : () => _readQr(camera: false),
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text(
                        'Chọn ảnh QR từ bộ sưu tập',
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      style: _buttonStyle(),
                      onPressed: (backup.busy || qrBusy)
                          ? null
                          : () => _readQr(camera: true),
                      icon: const Icon(Icons.qr_code_scanner),
                      label: const Text(
                        'Quét QR bằng camera',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
                if (backup.busy)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                if (message != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(message!, textAlign: TextAlign.center),
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/cloud_backup_service.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key, this.service});
  final CloudBackupService? service;
  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  late final CloudBackupService backup;
  final codeInput = TextEditingController();
  String? message;

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
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Giữ kín mã khôi phục'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Ai có mã này có thể đọc, thay đổi hoặc xóa bản lưu. Hãy cất mã ở nơi riêng ngoài trình duyệt. Mất mã và dữ liệu máy sẽ không thể khôi phục.',
              ),
              const SizedBox(height: 16),
              SelectableText(code),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              try {
                await Clipboard.setData(ClipboardData(text: code));
                if (mounted && dialogContext.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Đã sao chép mã khôi phục.')),
                  );
                }
              } catch (_) {
                /* The selectable text remains available if clipboard is blocked. */
              }
            },
            child: const Text('Sao chép'),
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
    if (saved && mounted && backup.savedAt != null) await _showCode();
  }

  Future<void> _restore() async {
    await _run(() async {
      final preview = await backup.preview(codeInput.text);
      if (!mounted) return;
      final yes = await _confirm(
        'Thay tiến độ trên máy?',
        'Bản lưu có ${preview.data['coins']} xu. Khôi phục sẽ thay thế toàn bộ tiến độ đang có trên trình duyệt này, không cộng dồn hai số dư.',
      );
      if (!yes || !mounted) return;
      await backup.restore(preview);
      codeInput.clear();
      if (mounted) {
        setState(() {
          message = 'Đã khôi phục. Quay lại để tiếp tục chơi.';
        });
      }
    });
  }

  Future<void> _delete() async {
    if (!await _confirm(
      'Xóa dữ liệu trên server?',
      'Bản sao trên server sẽ bị xóa và mã cũ không còn khôi phục được. Xu và ván chơi trên thiết bị này vẫn được giữ.',
    )) {
      return;
    }
    if (!mounted) return;
    await _run(
      backup.deleteServer,
      success: 'Đã xóa bản sao trên server. Tiến độ trên máy vẫn còn.',
    );
  }

  @override
  void dispose() {
    codeInput.dispose();
    super.dispose();
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
                const Text(
                  'Game vẫn tự lưu trên máy. Bản sao server chỉ cập nhật khi bạn bấm “Lưu tiến độ”.',
                ),
                const SizedBox(height: 16),
                if (backup.playerId != null)
                  SelectableText('Mã người chơi: ${backup.playerId}'),
                if (backup.savedAt != null)
                  Text(
                    'Lần lưu server: ${DateTime.tryParse(backup.savedAt!)?.toLocal().toString() ?? backup.savedAt}',
                  ),
                if (backup.recoveryCode != null && backup.savedAt == null)
                  const Text(
                    'Chưa xác nhận bản lưu trên server. Hãy thử lưu lại khi có mạng.',
                  ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: backup.busy ? null : _save,
                  icon: const Icon(Icons.cloud_upload_outlined),
                  label: const Text('Lưu tiến độ'),
                ),
                if (backup.recoveryCode != null)
                  TextButton(
                    onPressed: backup.busy ? null : _showCode,
                    child: const Text('Xem mã khôi phục'),
                  ),
                const Divider(height: 36),
                TextField(
                  controller: codeInput,
                  enabled: !backup.busy,
                  minLines: 2,
                  maxLines: 4,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: const InputDecoration(
                    labelText: 'Mã khôi phục',
                    hintText: 'BO1.…',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: backup.busy ? null : _restore,
                  child: const Text('Khôi phục'),
                ),
                if (backup.recoveryCode != null)
                  TextButton(
                    onPressed: backup.busy ? null : _delete,
                    child: const Text(
                      'Xóa dữ liệu trên server',
                      style: TextStyle(color: Colors.red),
                    ),
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

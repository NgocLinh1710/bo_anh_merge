import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/recovery_code.dart';
import 'game_storage_service.dart';

class BackupException implements Exception {
  final String message;
  const BackupException(this.message);
  @override
  String toString() => message;
}

class BackupPreview {
  final RecoveryCode code;
  final Map<String, dynamic> data;
  final int revision;
  final String savedAt;
  const BackupPreview(this.code, this.data, this.revision, this.savedAt);
}

class CloudBackupService extends ChangeNotifier {
  CloudBackupService({http.Client? client}) : _client = client ?? http.Client();
  static final instance = CloudBackupService();
  static const _url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://foairqpmcniidluqxvsk.supabase.co',
  );
  static const _key = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'sb_publishable_Y06obTXw8myFsc7Yy6SbgQ_y9gNBEM0',
  );
  final http.Client _client;
  Map<String, dynamic>? _link;
  bool busy = false;
  bool loaded = false;
  String? get playerId => _link == null
      ? null
      : RecoveryCode.parse(_link!['code'] as String).playerId;
  String? get savedAt => _link?['savedAt'] as String?;
  String? get recoveryCode => _link?['code'] as String?;

  Future<Map<String, dynamic>?> _readLink() async {
    final link = await GameStorageService.loadBackupLink();
    if (link != null) {
      RecoveryCode.parse(link['code'] as String);
      if (link['revision'] is! int ||
          (link['revision'] as int) < 0 ||
          (link['savedAt'] != null && link['savedAt'] is! String)) {
        throw const FormatException(
          'Thông tin liên kết bản sao lưu không hợp lệ.',
        );
      }
    }
    return link;
  }

  Future<T> _exclusive<T>(Future<T> Function() action) async {
    if (busy) throw const BackupException('Đang xử lý bản sao lưu.');
    busy = true;
    notifyListeners();
    try {
      return await action();
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> loadLocal() => _exclusive(() async {
    _link = await _readLink();
    loaded = true;
  });

  Future<Map<String, dynamic>> _rpc(
    String name,
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await _client
          .post(
            Uri.parse('$_url/rest/v1/rpc/$name'),
            headers: {'apikey': _key, 'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        String code = '';
        try {
          code = (jsonDecode(response.body) as Map)['message'] as String? ?? '';
        } catch (_) {}
        if (code.contains('BACKUP_CONFLICT')) {
          throw const BackupException(
            'Có bản lưu mới hơn trên server. Hãy khôi phục trước khi lưu tiếp để tránh ghi đè.',
          );
        }
        if (code.contains('BACKUP_NOT_FOUND')) {
          throw const BackupException(
            'Không tìm thấy bản lưu hoặc mã khôi phục không đúng.',
          );
        }
        if (code.contains('BACKUP_LIMIT')) {
          throw const BackupException(
            'Server đang giới hạn lượt lưu. Vui lòng thử lại sau.',
          );
        }
        if (response.statusCode == 404) {
          throw const BackupException(
            'Chức năng lưu server chưa được thiết lập. Bạn vẫn chơi và lưu trên máy được.',
          );
        }
        throw const BackupException(
          'Chưa xử lý được bản sao lưu. Vui lòng thử lại.',
        );
      }
      return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
    } on BackupException {
      rethrow;
    } catch (_) {
      throw const BackupException(
        'Chưa kết nối được server. Tiến độ trên máy vẫn được giữ; hãy thử lại khi có mạng.',
      );
    }
  }

  Future<void> _persistLink(Map<String, dynamic>? next) async {
    await GameStorageService.saveBackupLink(next);
    _link = next;
  }

  Future<void> _sendPending() async {
    final link = Map<String, dynamic>.from(_link!);
    final pending = Map<String, dynamic>.from(link['pending'] as Map);
    final code = RecoveryCode.parse(link['code'] as String);
    final result = await _rpc('game_backup_save', {
      'p_id': code.playerId,
      'p_key': code.secret,
      'p_payload': pending['data'],
      'p_expected_revision': link['revision'],
      'p_operation': pending['operation'],
    });
    link.remove('pending');
    link['revision'] = result['revision'];
    link['savedAt'] = result['savedAt'];
    await _persistLink(link);
  }

  Future<void> save() => _exclusive(() async {
    if (!loaded) {
      _link = await _readLink();
      loaded = true;
    }
    if (_link == null) {
      await _persistLink({
        'code': RecoveryCode.generate().value,
        'revision': 0,
      });
    }
    // Retry the same operation after a lost response, rather than overwriting
    // a newer revision or counting the old operation twice.
    String? retriedData;
    if (_link!.containsKey('pending')) {
      retriedData = jsonEncode((_link!['pending'] as Map)['data']);
      await _sendPending();
    }
    final data = GameStorageService.validateBackup(
      await GameStorageService.exportBackup(),
    );
    if (retriedData == jsonEncode(data)) return;
    final next = Map<String, dynamic>.from(_link!);
    next['pending'] = {'operation': RecoveryCode.newId(), 'data': data};
    await _persistLink(next);
    await _sendPending();
  });

  Future<BackupPreview> preview(String input) => _exclusive(() async {
    final code = RecoveryCode.parse(input);
    final result = await _rpc('game_backup_read', {
      'p_id': code.playerId,
      'p_key': code.secret,
    });
    final data = GameStorageService.validateBackup(jsonEncode(result['data']));
    return BackupPreview(
      code,
      data,
      result['revision'] as int,
      result['savedAt'] as String,
    );
  });

  Future<void> restore(BackupPreview preview) => _exclusive(() async {
    final link = {
      'code': preview.code.value,
      'revision': preview.revision,
      'savedAt': preview.savedAt,
    };
    await GameStorageService.restoreBackup(jsonEncode(preview.data), link);
    _link = link;
    loaded = true;
  });

  Future<void> deleteServer() => _exclusive(() async {
    if (_link == null) return;
    final code = RecoveryCode.parse(_link!['code'] as String);
    await _rpc('game_backup_delete', {
      'p_id': code.playerId,
      'p_key': code.secret,
    });
    await _persistLink(null);
  });

  @override
  void dispose() {
    _client.close();
    super.dispose();
  }
}

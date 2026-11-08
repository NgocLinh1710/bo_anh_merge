import 'dart:convert';

import 'package:bo_anh/models/recovery_code.dart';
import 'package:bo_anh/screens/backup_screen.dart';
import 'package:flutter/material.dart';
import 'package:bo_anh/services/cloud_backup_service.dart';
import 'package:bo_anh/services/game_storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BackupServer {
  final rows = <String, Map<String, dynamic>>{};
  final requests = <Map<String, dynamic>>[];
  bool loseSaveResponse = false;
  bool loseDeleteResponse = false;

  http.Client client() => MockClient((request) async {
    final body = jsonDecode(request.body) as Map<String, dynamic>;
    requests.add(body);
    expect(request.url.query, isEmpty); // Recovery secrets never go in URLs.
    expect(request.headers['apikey'], startsWith('sb_publishable_'));
    final id = body['p_id'] as String;
    final row = rows[id];
    http.Response error(String message) =>
        http.Response(jsonEncode({'message': message}), 400);
    http.Response ok(Object value) => http.Response(jsonEncode(value), 200);
    if (row != null && row['key'] != body['p_key']) {
      return error('BACKUP_NOT_FOUND');
    }
    if (request.url.path.endsWith('game_backup_save')) {
      if (row != null && row['operation'] == body['p_operation']) {
        return ok({'revision': row['revision'], 'savedAt': row['savedAt']});
      }
      if ((row?['revision'] ?? 0) != body['p_expected_revision']) {
        return error('BACKUP_CONFLICT');
      }
      final next = {
        'key': body['p_key'],
        'operation': body['p_operation'],
        'data': body['p_payload'],
        'revision': (row?['revision'] as int? ?? 0) + 1,
        'savedAt': '2026-11-08T01:00:00Z',
      };
      rows[id] = next;
      if (loseSaveResponse) {
        loseSaveResponse = false;
        throw http.ClientException('connection lost');
      }
      return ok({'revision': next['revision'], 'savedAt': next['savedAt']});
    }
    if (request.url.path.endsWith('game_backup_read')) {
      if (row == null) return error('BACKUP_NOT_FOUND');
      return ok({
        'data': row['data'],
        'revision': row['revision'],
        'savedAt': row['savedAt'],
      });
    }
    rows.remove(id);
    if (loseDeleteResponse) {
      loseDeleteResponse = false;
      throw http.ClientException('connection lost');
    }
    return ok({'deleted': true});
  });
}

class PreviewService extends CloudBackupService {
  final code = RecoveryCode.generate();
  int balance = 150;
  bool restored = false;
  @override
  String? get recoveryCode => code.value;
  @override
  String? get playerId => code.playerId;
  @override
  String? get savedAt => '2026-11-08T01:00:00Z';
  @override
  Future<void> loadLocal() async {}
  @override
  Future<BackupPreview> preview(String input) async =>
      BackupPreview(code, {'coins': 200}, 1, savedAt!);
  @override
  Future<void> restore(BackupPreview preview) async {
    restored = true;
    balance = preview.data['coins'] as int;
    notifyListeners();
  }
}

class ConsentService extends CloudBackupService {
  bool saveCalled = false;
  @override
  Future<void> loadLocal() async {}
  @override
  Future<void> save() async {
    saveCalled = true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('opening backup screen and declining consent sends no data', (
    tester,
  ) async {
    final service = ConsentService();
    await tester.pumpWidget(MaterialApp(home: BackupScreen(service: service)));
    await tester.pumpAndSettle();
    expect(service.saveCalled, false);
    await tester.tap(find.text('Lưu tiến độ'));
    await tester.pumpAndSettle();
    expect(find.text('Lưu tiến độ lên server?'), findsOneWidget);
    await tester.tap(find.text('Hủy'));
    await tester.pumpAndSettle();
    expect(service.saveCalled, false);
    expect(service.recoveryCode, isNull);
    await tester.pumpWidget(const SizedBox());
    service.dispose();
  });

  testWidgets(
    'restore requires confirmation and replaces rather than adds coins',
    (tester) async {
      final service = PreviewService();
      await tester.pumpWidget(
        MaterialApp(home: BackupScreen(service: service)),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), service.recoveryCode!);
      await tester.ensureVisible(find.text('Khôi phục'));
      await tester.tap(find.text('Khôi phục'));
      await tester.pumpAndSettle();
      expect(find.text('Thay tiến độ trên máy?'), findsOneWidget);
      await tester.tap(find.text('Hủy'));
      await tester.pumpAndSettle();
      expect(service.balance, 150);
      expect(service.restored, false);
      await tester.tap(find.text('Khôi phục'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Đồng ý'));
      await tester.pumpAndSettle();
      expect(service.balance, 200);
      expect(service.restored, true);
      expect(
        find.text('Đã khôi phục. Quay lại để tiếp tục chơi.'),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
      service.dispose();
    },
  );

  test('recovery codes round-trip and reject malformed or truncated codes', () {
    final codes = List.generate(100, (_) => RecoveryCode.generate());
    expect(codes.map((c) => c.value).toSet(), hasLength(100));
    for (final code in codes) {
      expect(RecoveryCode.parse(' ${code.value} ').value, code.value);
      expect(code.secret.length, 43);
      expect(code.playerId, isNot(contains(code.secret)));
    }
    expect(() => RecoveryCode.parse('BO1.invalid'), throwsFormatException);
  });

  test(
    'explicit save and cross-device restore retain coins without merging balances or sending credentials',
    () async {
      SharedPreferences.setMockInitialValues({
        'player_total_coins': 200,
        'unlocked_collections': ['collection_2'],
      });
      final server = BackupServer();
      final first = CloudBackupService(client: server.client());
      await first.loadLocal();
      expect(server.requests, isEmpty);
      await first.save();
      final code = first.recoveryCode!;
      final payload = server.rows.values.single['data'] as Map;
      expect(payload.containsKey('backupLink'), false);
      expect(
        jsonEncode(payload),
        isNot(contains(RecoveryCode.parse(code).secret)),
      );
      // Simulate cleared storage or a completely different browser.
      SharedPreferences.setMockInitialValues({'player_total_coins': 5});
      final second = CloudBackupService(client: server.client());
      final preview = await second.preview(code);
      expect(
        await GameStorageService.loadTotalCoins(),
        5,
      ); // Preview cannot overwrite.
      await second.restore(preview);
      expect(await GameStorageService.loadTotalCoins(), 200);
      expect(await GameStorageService.loadUnlockedCollections(), {
        'collection_2',
      });
      expect(second.recoveryCode, code);
      first.dispose();
      second.dispose();
    },
  );

  test(
    'a lost save response retries the same persisted operation after app restart',
    () async {
      SharedPreferences.setMockInitialValues({'player_total_coins': 77});
      final server = BackupServer()..loseSaveResponse = true;
      final first = CloudBackupService(client: server.client());
      await expectLater(first.save(), throwsA(isA<BackupException>()));
      expect(server.rows.values.single['revision'], 1);
      final second = CloudBackupService(client: server.client());
      await second.save();
      expect(server.rows.values.single['revision'], 1);
      expect(
        server.requests[0]['p_operation'],
        server.requests[1]['p_operation'],
      );
      expect(
        (await GameStorageService.loadBackupLink())!.containsKey('pending'),
        false,
      );
      expect(await GameStorageService.loadTotalCoins(), 77);
      first.dispose();
      second.dispose();
    },
  );

  test('stale device cannot overwrite a newer backup', () async {
    final server = BackupServer();
    final first = CloudBackupService(client: server.client());
    await first.save();
    final second = CloudBackupService(client: server.client());
    await second.loadLocal();
    await GameStorageService.recordMergedPairs(
      14,
      collectionId: 'collection_6',
    );
    await second.save();
    expect(server.rows.values.single['revision'], 2);
    await expectLater(first.save(), throwsA(isA<BackupException>()));
    expect(server.rows.values.single['revision'], 2);
    expect((server.rows.values.single['data'] as Map)['coins'], 30);
    first.dispose();
    second.dispose();
  });

  test('wrong code cannot read or delete another player backup', () async {
    final server = BackupServer();
    final service = CloudBackupService(client: server.client());
    await service.save();
    final code = RecoveryCode.parse(service.recoveryCode!);
    final wrong = 'BO1.${code.playerId}.${RecoveryCode.generate().secret}';
    await expectLater(service.preview(wrong), throwsA(isA<BackupException>()));
    expect(server.rows, hasLength(1));
    service.dispose();
  });

  test(
    'delete is retryable after network loss and preserves local progress',
    () async {
      SharedPreferences.setMockInitialValues({'player_total_coins': 42});
      final server = BackupServer();
      final service = CloudBackupService(client: server.client());
      await service.save();
      server.loseDeleteResponse = true;
      await expectLater(
        service.deleteServer(),
        throwsA(isA<BackupException>()),
      );
      expect(service.recoveryCode, isNotNull);
      await service.deleteServer();
      expect(service.recoveryCode, isNull);
      expect(await GameStorageService.loadBackupLink(), isNull);
      expect(await GameStorageService.loadTotalCoins(), 42);
      service.dispose();
    },
  );

  test('invalid remote progress never overwrites the local wallet', () async {
    SharedPreferences.setMockInitialValues({'player_total_coins': 88});
    final server = BackupServer();
    final service = CloudBackupService(client: server.client());
    await service.save();
    (server.rows.values.single['data'] as Map)['coins'] = -999;
    await expectLater(
      service.preview(service.recoveryCode!),
      throwsFormatException,
    );
    expect(await GameStorageService.loadTotalCoins(), 88);
    service.dispose();
  });
}

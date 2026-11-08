import 'dart:convert';
import 'dart:math';

class RecoveryCode {
  final String playerId;
  final String secret;
  const RecoveryCode._(this.playerId, this.secret);

  static String newId() {
    final rng = Random.secure();
    final bytes = List.generate(16, (_) => rng.nextInt(256));
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  factory RecoveryCode.generate() {
    final rng = Random.secure();
    return RecoveryCode._(
      newId(),
      base64Url
          .encode(List.generate(32, (_) => rng.nextInt(256)))
          .replaceAll('=', ''),
    );
  }

  factory RecoveryCode.parse(String input) {
    final match = RegExp(
      r'^BO1\.([0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12})\.([A-Za-z0-9_-]{43})$',
    ).firstMatch(input.trim());
    if (match == null) {
      throw const FormatException('Mã khôi phục không đúng định dạng.');
    }
    return RecoveryCode._(match.group(1)!, match.group(2)!);
  }

  String get value => 'BO1.$playerId.$secret';
}

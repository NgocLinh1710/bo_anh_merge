enum GameMode { free, timed }

extension GameModeExtension on GameMode {
  String get storageKey {
    switch (this) {
      case GameMode.free:
        return 'free';
      case GameMode.timed:
        return 'timed';
    }
  }

  String get displayName {
    switch (this) {
      case GameMode.free:
        return 'Chơi tự do';
      case GameMode.timed:
        return 'Thử thách thời gian';
    }
  }

  String get description {
    switch (this) {
      case GameMode.free:
        return 'Ghép ảnh thoải mái, tích lũy xu và chinh phục cấp độ cao nhất.';
      case GameMode.timed:
        return 'Bắt đầu với 14 giây. Ghép sai sẽ bị trừ 1 giây.';
    }
  }

  static GameMode fromStorageKey(String? value) {
    switch (value) {
      case 'timed':
        return GameMode.timed;
      case 'free':
      default:
        return GameMode.free;
    }
  }
}

import 'game_mode.dart';

class GameCollection {
  final String id;
  final String name;
  final int maxLevel;

  final Set<int> availableLevels;

  final Map<int, String> imagePaths;

  // Các chế độ được phép chơi trong ver
  final List<GameMode> availableModes;

  // Nhóm âm thanh chiến thắng của ver
  final String victorySoundGroup;

  GameCollection({
    required this.id,
    required this.name,
    required this.maxLevel,
    required this.availableLevels,
    this.imagePaths = const {},
    this.availableModes = const [GameMode.free],
    this.victorySoundGroup = 'sound_1',
  });

  List<int> get sortedLevels {
    final levels = availableLevels.toList()..sort();
    return levels;
  }

  String imagePath(int level) {
    if (level < 1 || level > maxLevel) {
      return '';
    }

    // Ưu tiên đường dẫn ảnh thực tế được lưu
    final actualPath = imagePaths[level];

    if (actualPath != null) {
      return actualPath;
    }

    final levels = sortedLevels;
    final actualFileNumber = levels[level - 1];

    return 'assets/collections/$id/$actualFileNumber.jpg';
  }

  bool hasLevel(int level) {
    return availableLevels.contains(level);
  }

  bool supportsMode(GameMode mode) {
    return availableModes.contains(mode);
  }
}

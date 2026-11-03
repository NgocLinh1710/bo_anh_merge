class GameCollection {
  final String id;
  final String name;
  final int maxLevel;
  final Set<int> availableLevels;

  GameCollection({
    required this.id,
    required this.name,
    required this.maxLevel,
    required this.availableLevels,
  });

  List<int> get sortedLevels {
    final levels = availableLevels.toList()..sort();
    return levels;
  }

  String imagePath(int level) {
    final levels = sortedLevels;

    if (level < 1 || level > levels.length) {
      return '';
    }

    final actualFileNumber = levels[level - 1];

    return 'assets/collections/$id/$actualFileNumber.jpg';
  }

  bool hasLevel(int level) {
    return level >= 1 && level <= maxLevel;
  }
}

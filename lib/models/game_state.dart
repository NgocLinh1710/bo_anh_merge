class GameState {
  final List<int?> board;
  final int score;
  final int moves;
  final int highestDiscoveredLevel;

  final int pairsMerged;

  final int maxLevelCelebrations;

  final int maxLevelNoticeShownFor;

  final bool isGameOver;

  // Số giây còn lại trong chế độ Thử thách thời gian
  final int remainingSeconds;

  // Tiến độ nhận thưởng riêng của chế độ Thử thách thời gian
  final int timedRewardProgress;

  const GameState({
    required this.board,
    this.score = 0,
    this.moves = 0,
    this.highestDiscoveredLevel = 1,
    this.pairsMerged = 0,
    this.maxLevelCelebrations = 0,
    this.maxLevelNoticeShownFor = 0,
    this.isGameOver = false,
    this.remainingSeconds = 14,
    this.timedRewardProgress = 0,
  });

  GameState copyWith({
    List<int?>? board,
    int? score,
    int? moves,
    int? highestDiscoveredLevel,
    int? pairsMerged,
    int? maxLevelCelebrations,
    int? maxLevelNoticeShownFor,
    bool? isGameOver,
    int? remainingSeconds,
    int? timedRewardProgress,
  }) {
    return GameState(
      board: board ?? this.board,
      score: score ?? this.score,
      moves: moves ?? this.moves,
      highestDiscoveredLevel:
          highestDiscoveredLevel ?? this.highestDiscoveredLevel,
      pairsMerged: pairsMerged ?? this.pairsMerged,
      maxLevelCelebrations: maxLevelCelebrations ?? this.maxLevelCelebrations,
      maxLevelNoticeShownFor:
          maxLevelNoticeShownFor ?? this.maxLevelNoticeShownFor,
      isGameOver: isGameOver ?? this.isGameOver,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      timedRewardProgress: timedRewardProgress ?? this.timedRewardProgress,
    );
  }
}

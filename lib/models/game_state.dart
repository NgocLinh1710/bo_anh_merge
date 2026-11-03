class GameState {
  final List<int?> board;
  final int score;
  final int moves;

  // Tổng số cặp đã ghép trong ván hiện tại
  final int pairsMerged;

  final int maxLevelCelebrations;

  final int maxLevelNoticeShownFor;

  final bool isGameOver;

  const GameState({
    required this.board,
    this.score = 0,
    this.moves = 0,
    this.pairsMerged = 0,
    this.maxLevelCelebrations = 0,
    this.maxLevelNoticeShownFor = 0,
    this.isGameOver = false,
  });

  GameState copyWith({
    List<int?>? board,
    int? score,
    int? moves,
    int? pairsMerged,
    int? maxLevelCelebrations,
    int? maxLevelNoticeShownFor,
    bool? isGameOver,
  }) {
    return GameState(
      board: board ?? this.board,
      score: score ?? this.score,
      moves: moves ?? this.moves,
      pairsMerged: pairsMerged ?? this.pairsMerged,
      maxLevelCelebrations: maxLevelCelebrations ?? this.maxLevelCelebrations,
      maxLevelNoticeShownFor:
          maxLevelNoticeShownFor ?? this.maxLevelNoticeShownFor,
      isGameOver: isGameOver ?? this.isGameOver,
    );
  }
}

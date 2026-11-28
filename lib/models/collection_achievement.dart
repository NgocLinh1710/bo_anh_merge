/// Permanent goals for free play. Records stop at the first final-image merge.
class CollectionAchievement {
  final int? bestMoves;
  final bool speedWinner;
  final bool cleanWinner;
  final bool recordBreaker;

  const CollectionAchievement({
    this.bestMoves,
    this.speedWinner = false,
    this.cleanWinner = false,
    this.recordBreaker = false,
  });

  CollectionAchievement recordWin(int moves, bool clean, int target) =>
      CollectionAchievement(
        bestMoves: bestMoves == null || moves < bestMoves! ? moves : bestMoves,
        speedWinner: speedWinner || moves <= target,
        cleanWinner: cleanWinner || clean,
        recordBreaker:
            recordBreaker || (bestMoves != null && moves < bestMoves!),
      );

  factory CollectionAchievement.fromJson(Map<String, dynamic> json) {
    final best = json['bestMoves'] as int?;
    if (best != null && (best < 1 || best > 999999999999999)) {
      throw const FormatException('Kỷ lục số lượt không hợp lệ.');
    }
    return CollectionAchievement(
      bestMoves: best,
      speedWinner: json['speedWinner'] as bool? ?? false,
      cleanWinner: json['cleanWinner'] as bool? ?? false,
      recordBreaker: json['recordBreaker'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    if (bestMoves != null) 'bestMoves': bestMoves,
    'speedWinner': speedWinner,
    'cleanWinner': cleanWinner,
    'recordBreaker': recordBreaker,
  };
}

class ChallengeGoals {
  // Near the median of 500 seeded random-strategy runs without rescue.
  static const targetMoves = <String, int>{
    'collection_1': 90,
    'collection_2': 95,
    'collection_3': 115,
    'collection_4': 135,
    'collection_5': 165,
    'collection_6': 240,
    'collection_7': 3,
    'collection_8': 7,
  };
}

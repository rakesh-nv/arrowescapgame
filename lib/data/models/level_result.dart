/// Result of completing a level
class LevelResult {
  final int levelNumber;
  final int stars; // 1–3
  final int moves;
  final int mistakes;
  final int elapsedSeconds;
  final int coinsEarned;

  const LevelResult({
    required this.levelNumber,
    required this.stars,
    required this.moves,
    required this.mistakes,
    required this.elapsedSeconds,
    required this.coinsEarned,
  });

  /// Calculate star rating:
  /// 3 stars: 0 mistakes and within moveTarget (or moveTarget == null)
  /// 2 stars: up to 2 mistakes
  /// 1 star: completed but more mistakes
  static int calculateStars({
    required int mistakes,
    required int moves,
    int? moveTarget,
  }) {
    if (mistakes == 0 && (moveTarget == null || moves <= moveTarget)) {
      return 3;
    } else if (mistakes <= 2) {
      return 2;
    } else {
      return 1;
    }
  }
}

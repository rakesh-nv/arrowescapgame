/// Difficulty levels for puzzle generation
enum Difficulty {
  easy,
  normal,
  hard,
  expert,
  extreme;

  String get displayName {
    switch (this) {
      case Difficulty.easy:
        return 'EASY';
      case Difficulty.normal:
        return 'NORMAL';
      case Difficulty.hard:
        return 'HARD';
      case Difficulty.expert:
        return 'EXPERT';
      case Difficulty.extreme:
        return 'EXTREME';
    }
  }
}

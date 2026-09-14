/// App-wide constants for Arrow Escape
class AppConstants {
  AppConstants._();

  // Game
  static const int fixedGridSize = 16;
  static const int startingCoins = 100;
  static const int startingHints = 3;
  static const int startingLives = 3;
  static const int maxLives = 3;

  static const int coinsPerLevelComplete = 25;
  static const int coinsFor3Stars = 10;
  static const int coinsDailyChallenge = 50;
  static const int coinsHintCost = 10;
  static const int coinsUndoCost = 5;

  static const int totalLevels = 100;
  static const int levelsPerWorld = 25;

  // Level difficulty ranges
  static const int easyLevelsStart = 1;
  static const int easyLevelsEnd = 20;
  static const int normalLevelsStart = 21;
  static const int normalLevelsEnd = 50;
  static const int hardLevelsStart = 51;
  static const int hardLevelsEnd = 80;
  static const int expertLevelsStart = 81;
  static const int expertLevelsEnd = 100;

  // Level seed formula: seed = levelNumber * 31337 + 42
  static int levelSeed(int levelNumber) => levelNumber * 31337 + 42;

  // Solver
  static const int solverMaxIterations = 100000;

  // Animations
  /// Touch response begins immediately for smooth, responsive movement.
  static const int arrowPressDelayMs = 0;
  static const int arrowFlightDurationMs = 400;

  /// Longer paths get a little more time to remain readable, without making
  /// short and medium arrows feel sluggish.
  static int arrowFlightDurationForLength(int length) =>
      (arrowFlightDurationMs + ((length - 5).clamp(0, 5) * 15))
          .clamp(arrowFlightDurationMs, 500)
          .toInt();
  static int arrowEscapeDurationForLength(int length) =>
      arrowFlightDurationForLength(length);
  static const int arrowEscapeDurationMs = arrowFlightDurationMs;
  static const int blockedAnimDurationMs = 250;
  static const int levelCompleteDurationMs = 800;

  // Board
  static const double boardPadding = 12.0;
  static const double arrowStrokeWidth = 3.0;
  static const double arrowHeadSize = 6.0;
  static const double arrowCornerRadius = 2.0;
  static const double cellPadding = 4.0;

  // Themes
  static const int forestThemeCost = 100;
  static const int sunsetThemeCost = 150;
  static const int nightThemeCost = 200;

  // Daily challenge
  static const String dailyChallengeBoxKey = 'daily_challenge';

  // Hive box names
  static const String progressBox = 'progress_box';
  static const String settingsBox = 'settings_box';

  // Hive type IDs
  static const int playerProgressTypeId = 0;
  static const int gameSettingsTypeId = 1;
}

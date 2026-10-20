/// App-wide constants for Arrow Escape
class AppConstants {
  AppConstants._();

  // Game
  /// Largest board of the first [classicLevels] levels. Those levels keep this
  /// cap forever so their boards (and saved games on them) never change.
  /// Board size per level comes from DifficultyCurve.
  static const int maxGridSize = 60;

  /// Largest board in the campaign, reached at the final level.
  static const int finalMaxGridSize = 96;

  /// Levels that shipped before the campaign was extended. Their generation
  /// inputs are frozen: new keyframes, shapes and board caps only apply
  /// beyond this level.
  static const int classicLevels = 200;
  static const int startingCoins = 100;
  static const int startingHints = 3;
  static const int startingLives = 4;
  static const int maxLives = 4;

  static const int coinsPerLevelComplete = 25;
  static const int coinsFor3Stars = 10;
  static const int coinsDailyChallenge = 50;
  static const int coinsHintCost = 10;
  static const int coinsUndoCost = 5;

  static const int totalLevels = 1000;
  static const int levelsPerWorld = 25;

  // Level seed formula: seed = levelNumber * 31337 + 42
  static int levelSeed(int levelNumber) => levelNumber * 31337 + 42;

  /// Bumped whenever generation changes the board a level produces. Saved
  /// in-progress games from another version are discarded, because their
  /// removed-arrow ids refer to a different board.
  static const int levelGeneratorVersion = 7;

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
  static const double arrowStrokeWidth = 6.0;
  static const double arrowHeadSize = 12.0;
  static const double arrowCornerRadius = 4.0;
  static const double cellPadding = 8.0;

  // Theme prices by tier (coins). No paid theme costs less than the entry tier.
  static const int themePriceEntry = 2000;
  static const int themePriceStandard = 3000;
  static const int themePriceAdvanced = 5000;
  static const int themePricePremium = 8000;
  static const int themePriceRare = 10000;

  // Must match `applicationId` in android/app/build.gradle.kts. Only used as a
  // fallback when the platform cannot report its own package name.
  static const String androidApplicationId = 'com.arrowescape.arrowescapegame';

  // Daily challenge
  static const String dailyChallengeBoxKey = 'daily_challenge';

  // Hive box names
  static const String progressBox = 'progress_box';
  static const String settingsBox = 'settings_box';

  // Hive type IDs
  static const int playerProgressTypeId = 0;
  static const int gameSettingsTypeId = 1;
}

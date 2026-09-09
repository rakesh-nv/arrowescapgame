import '../../core/constants/app_constants.dart';
import '../../data/models/difficulty.dart';
import '../../data/models/level_model.dart';
import '../../game/generator/level_generator.dart';

/// Provides access to all 100 game levels via deterministic generation.
///
/// Each level is generated from a unique seed:
///   seed = levelNumber * 31337 + 42
///
/// This guarantees:
/// - Same level always produces the same board
/// - No two levels share a seed
/// - Levels can be added beyond 100 without any code changes
class LevelRepository {
  LevelRepository._();

  // Cache to avoid re-generating on every access
  static final Map<int, LevelModel> _cache = {};

  /// Get or generate level [n] (1-indexed).
  static LevelModel getLevel(int n) {
    assert(n >= 1, 'Level number must be >= 1');

    if (_cache.containsKey(n)) return _cache[n]!;

    final difficulty = _difficultyForLevel(n);
    final seed = AppConstants.levelSeed(n);

    final level = LevelGenerator.generate(
          levelNumber: n,
          seed: seed,
          difficulty: difficulty,
        ) ??
        _fallbackLevel(n, difficulty);

    _cache[n] = level;
    return level;
  }

  /// Pre-generate all 100 levels (useful for validation/testing)
  static List<LevelModel> generateAll() {
    return List.generate(
      AppConstants.totalLevels,
      (i) => getLevel(i + 1),
    );
  }

  /// Clear cache (useful for testing)
  static void clearCache() => _cache.clear();

  static Difficulty _difficultyForLevel(int n) {
    if (n <= AppConstants.easyLevelsEnd) return Difficulty.easy;
    if (n <= AppConstants.normalLevelsEnd) return Difficulty.normal;
    if (n <= AppConstants.hardLevelsEnd) return Difficulty.hard;
    return Difficulty.expert;
  }

  static LevelModel _fallbackLevel(int n, Difficulty difficulty) {
    // Ultra-simple 3-arrow level as last-resort fallback
    return LevelGenerator.generate(
          levelNumber: n,
          seed: n * 13,
          difficulty: Difficulty.easy,
        ) ??
        LevelGenerator.generate(
          levelNumber: n,
          seed: 999,
          difficulty: Difficulty.easy,
        )!;
  }

  /// Generate a daily challenge level from a date seed
  static LevelModel getDailyChallenge(int dateSeed) {
    if (_cache.containsKey(-dateSeed)) return _cache[-dateSeed]!;

    final level = LevelGenerator.generate(
          levelNumber: 0,
          seed: dateSeed,
          difficulty: Difficulty.normal,
        ) ??
        LevelGenerator.generate(
          levelNumber: 0,
          seed: dateSeed + 1,
          difficulty: Difficulty.easy,
        )!;

    _cache[-dateSeed] = level;
    return level;
  }
}

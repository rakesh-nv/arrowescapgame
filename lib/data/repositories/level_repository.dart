import 'dart:async';
import 'dart:isolate';

import '../../core/constants/app_constants.dart';
import '../../data/models/difficulty.dart';
import '../../data/models/level_model.dart';
import '../../game/generator/level_generator.dart';

/// Provides access to every campaign level via deterministic generation.
///
/// Each level is generated from a unique seed:
///   seed = levelNumber * 31337 + 42
/// and its board size and difficulty come from DifficultyCurve.
///
/// This guarantees:
/// - Same level always produces the same board
/// - No two levels share a seed
/// - Levels can be added beyond the campaign without any code changes
class LevelRepository {
  LevelRepository._();

  // Cache to avoid re-generating on every access
  static final Map<int, LevelModel> _cache = {};

  /// Get or generate level [n] (1-indexed).
  static LevelModel getLevel(int n) {
    assert(n >= 1, 'Level number must be >= 1');

    final level = _cache.putIfAbsent(n, () => _generate(n));

    _preloadNextLevels(n);
    return level;
  }

  static void _preloadNextLevels(int currentLevel) {
    // If background preparation fails, getLevel() still generates on demand.
    unawaited(
      prepareLevels(currentLevel + 1, count: 3).catchError((Object _) {}),
    );
  }

  static final Set<int> _preparing = {};

  /// Generates levels [first]..[first]+[count]-1 on a background isolate and
  /// adds them to the cache, so the UI isolate never blocks long enough to
  /// trigger an Android ANR.
  ///
  /// Generation is a pure function of the level number, so boards made here
  /// are identical to ones made by [getLevel]. Preloading stops at the end of
  /// the campaign; with [requireFirst], [first] is prepared even beyond it.
  static Future<void> prepareLevels(
    int first, {
    int count = 1,
    bool requireFirst = false,
  }) async {
    final numbers = [
      for (var n = first; n < first + count; n++)
        if (n >= 1 &&
            (n <= AppConstants.totalLevels || (requireFirst && n == first)) &&
            !_cache.containsKey(n) &&
            !_preparing.contains(n))
          n,
    ];
    if (numbers.isEmpty) {
      // Another call may already be preparing it; wait for that to land.
      if (requireFirst) {
        while (_preparing.contains(first)) {
          await Future<void>.delayed(const Duration(milliseconds: 16));
        }
      }
      return;
    }

    _preparing.addAll(numbers);
    try {
      final levels = await Isolate.run(() => _generateBatch(numbers));
      levels.forEach((n, level) => _cache.putIfAbsent(n, () => level));
    } finally {
      _preparing.removeAll(numbers);
    }
  }

  /// Runs on a background isolate.
  static Map<int, LevelModel> _generateBatch(List<int> numbers) => {
        for (final n in numbers) n: _generate(n),
      };

  static LevelModel _generate(int n) {
    final seed = AppConstants.levelSeed(n);
    return LevelGenerator.generate(levelNumber: n, seed: seed) ??
        LevelGenerator.guaranteedLevel(levelNumber: n, seed: seed);
  }

  /// Pre-generate every campaign level (useful for validation/testing)
  static List<LevelModel> generateAll() {
    return List.generate(AppConstants.totalLevels, (i) => getLevel(i + 1));
  }

  /// Clear cache (useful for testing)
  static void clearCache() => _cache.clear();

  /// Reads the cache without generating or preloading (useful for testing).
  static LevelModel? cachedLevel(int n) => _cache[n];

  /// Daily challenges use a mid-campaign board size and difficulty.
  static const Difficulty dailyDifficulty = Difficulty.normal;

  /// Generate a daily challenge level from a date seed
  static LevelModel getDailyChallenge(int dateSeed) {
    return _cache.putIfAbsent(
      -dateSeed,
      () =>
          LevelGenerator.generate(
            levelNumber: 0,
            seed: dateSeed,
            difficulty: dailyDifficulty,
          ) ??
          LevelGenerator.guaranteedLevel(
            levelNumber: 0,
            seed: dateSeed,
            spec: LevelGenerator.specFor(0, dailyDifficulty),
          ),
    );
  }
}

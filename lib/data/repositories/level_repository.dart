import 'dart:async';
import 'dart:isolate';

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

    LevelModel level;
    if (_cache.containsKey(n)) {
      level = _cache[n]!;
    } else {
      final seed = AppConstants.levelSeed(n);
      level =
          LevelGenerator.generate(levelNumber: n, seed: seed) ??
          _fallbackLevel(n, Difficulty.easy);
      _cache[n] = level;
    }

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
  /// Levels are generated in the same order, with the same seeds and the same
  /// anti-duplicate history as the synchronous path, so the boards are
  /// identical. With [requireFirst], [first] gets the same fallback as
  /// [getLevel]; the others are cached only if generation succeeds, matching
  /// the old preload.
  static Future<void> prepareLevels(
    int first, {
    int count = 1,
    bool requireFirst = false,
  }) async {
    final numbers = [
      for (var n = first; n < first + count; n++)
        if (n >= 1 &&
            n <= AppConstants.totalLevels &&
            !_cache.containsKey(n) &&
            !_preparing.contains(n))
          n,
    ];
    if (numbers.isEmpty) return;

    final fallbackLevel = requireFirst && numbers.first == first ? first : null;
    final signatures = LevelGenerator.recentSignatures;
    _preparing.addAll(numbers);
    try {
      final (levels, newSignatures) = await Isolate.run(
        () => _generateBatch(numbers, signatures, fallbackLevel),
      );
      LevelGenerator.restoreSignatures(newSignatures);
      levels.forEach((n, level) => _cache.putIfAbsent(n, () => level));
    } finally {
      _preparing.removeAll(numbers);
    }
  }

  /// Runs on a background isolate, whose static generator state starts empty.
  static (Map<int, LevelModel>, Map<int, LevelPatternSignature>)
      _generateBatch(
    List<int> numbers,
    Map<int, LevelPatternSignature> signatures,
    int? fallbackLevel,
  ) {
    LevelGenerator.restoreSignatures(signatures);
    final levels = <int, LevelModel>{};
    for (final n in numbers) {
      final level =
          LevelGenerator.generate(levelNumber: n, seed: AppConstants.levelSeed(n)) ??
          (n == fallbackLevel ? _fallbackLevel(n, Difficulty.easy) : null);
      if (level != null) levels[n] = level;
    }
    return (levels, LevelGenerator.recentSignatures);
  }

  /// Pre-generate all 100 levels (useful for validation/testing)
  static List<LevelModel> generateAll() {
    return List.generate(AppConstants.totalLevels, (i) => getLevel(i + 1));
  }

  /// Clear cache (useful for testing)
  static void clearCache() => _cache.clear();

  /// Reads the cache without generating or preloading (useful for testing).
  static LevelModel? cachedLevel(int n) => _cache[n];

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

    final level =
        LevelGenerator.generate(
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

import 'dart:math';

import '../../data/models/arrow_model.dart';
import '../../data/models/level_model.dart';
import '../config/difficulty_curve.dart';
import 'level_generator.dart';
import 'level_validator.dart';

/// Measured difficulty of a board, taken from its arrows rather than from its
/// labels. Every number follows the game's escape rule: an arrow can leave
/// when no other arrow sits in the straight lane ahead of its head.
class PuzzleDifficulty {
  /// Board side in cells.
  final int gridSize;

  /// Arrows on the board. Every tap removes exactly one arrow, so this is
  /// also the length of the escape sequence and the minimum number of moves.
  final int arrows;

  /// Average and longest arrow length (cells).
  final double averageLength;
  final int longestArrow;

  /// Average 90° turns per arrow.
  final double averageBends;

  /// Blocking relationships at the start: pairs (A, B) where B sits in A's
  /// exit lane, so B must leave before A can.
  final int blockingRelations;

  /// Waves of "remove everything that is free right now" needed to clear the
  /// board. This is the longest chain of dependencies: an arrow freed in wave
  /// k was waiting on an arrow freed in wave k − 1.
  final int dependencyDepth;

  /// Arrows that can leave on the very first tap.
  final int initiallyFree;

  /// Average share of the remaining arrows that are free at each wave. Low
  /// means the player must find a few safe arrows among many traps.
  final double averageFreeShare;

  const PuzzleDifficulty({
    required this.gridSize,
    required this.arrows,
    required this.averageLength,
    required this.longestArrow,
    required this.averageBends,
    required this.blockingRelations,
    required this.dependencyDepth,
    required this.initiallyFree,
    required this.averageFreeShare,
  });

  /// Minimum number of moves to solve the board (one per arrow).
  int get minimumMoves => arrows;

  /// Share of arrows that are blocked on the first tap.
  double get blockedShare => arrows == 0 ? 0 : 1 - initiallyFree / arrows;

  /// Blocking relationships per arrow.
  double get blockingPerArrow => arrows == 0 ? 0 : blockingRelations / arrows;

  /// One number for comparing boards: the campaign's complexity score plus
  /// the dependency structure, so size alone cannot make a board "hard".
  double get score =>
      PuzzleSpec.complexityScore(
        arrows: arrows,
        avgLength: averageLength,
        avgBends: averageBends,
        rounds: dependencyDepth,
        blockedShare: blockedShare,
      ) +
      blockingPerArrow * 10 +
      (1 - averageFreeShare) * 20;

  /// Measures [level], or returns null if it cannot be cleared.
  static PuzzleDifficulty? measure(LevelModel level) {
    final n = level.gridSize;
    final arrows = level.arrows;
    if (arrows.isEmpty) return null;

    final owner = <(int, int), String>{
      for (final a in arrows)
        for (final cell in a.occupiedCells) cell: a.id,
    };

    // Distinct foreign arrows in [a]'s lane under the current [owner] map.
    Set<String> blockers(ArrowModel a) {
      final out = <String>{};
      final dir = a.exitDirection;
      var r = a.headRow + dir.dRow;
      var c = a.headCol + dir.dCol;
      while (r >= 0 && r < n && c >= 0 && c < n) {
        final o = owner[(r, c)];
        if (o != null && o != a.id) out.add(o);
        r += dir.dRow;
        c += dir.dCol;
      }
      return out;
    }

    var relations = 0;
    for (final a in arrows) {
      relations += blockers(a).length;
    }

    final remaining = {for (final a in arrows) a.id: a};
    var depth = 0;
    var initiallyFree = 0;
    var freeShareSum = 0.0;
    while (remaining.isNotEmpty) {
      final free = [
        for (final a in remaining.values)
          if (blockers(a).isEmpty) a,
      ];
      if (free.isEmpty) return null;
      if (depth == 0) initiallyFree = free.length;
      freeShareSum += free.length / remaining.length;
      depth++;
      for (final a in free) {
        remaining.remove(a.id);
        for (final cell in a.occupiedCells) {
          owner.remove(cell);
        }
      }
    }

    final lengths = arrows.map((a) => a.length);
    return PuzzleDifficulty(
      gridSize: n,
      arrows: arrows.length,
      averageLength: lengths.reduce((x, y) => x + y) / arrows.length,
      longestArrow: lengths.reduce(max),
      averageBends: arrows.fold<int>(0, (s, a) => s + a.turns) / arrows.length,
      blockingRelations: relations,
      dependencyDepth: depth,
      initiallyFree: initiallyFree,
      averageFreeShare: freeShareSum / depth,
    );
  }

  @override
  String toString() =>
      '${gridSize}x$gridSize, $arrows arrows, avg len '
      '${averageLength.toStringAsFixed(1)}, longest $longestArrow, bends '
      '${averageBends.toStringAsFixed(1)}, blocking $blockingRelations '
      '(${blockingPerArrow.toStringAsFixed(2)}/arrow), depth $dependencyDepth, '
      'free at start $initiallyFree (${(blockedShare * 100).round()}% blocked), '
      'avg free share ${(averageFreeShare * 100).toStringAsFixed(0)}%, '
      'score ${score.toStringAsFixed(0)}';
}

/// Builds the daily challenge: one huge, expert-level board per date.
///
/// The board for a date is a pure function of the date's seed, so every
/// player gets the same puzzle and changing the device clock only ever shows
/// the puzzle of the date it is set to. Every candidate passes
/// [LevelValidator] (valid paths, no overlaps, no self-collision, solvable by
/// replaying the game's own escape rule) and then [DailyChallengeGenerator.minimum]
/// difficulty; easy candidates are discarded and the next seeded attempt is
/// tried.
class DailyChallengeGenerator {
  DailyChallengeGenerator._();

  /// Seeded attempts per date before the hardest valid one is used.
  static const int maxAttempts = 4;

  /// The difficulty floor every daily board must reach. Set just below what
  /// boards of [DifficultyCurve.forDaily] measure (about 250–310 arrows on
  /// 99–128 cell boards, 23–36 waves deep, 81–88% blocked at the start), and
  /// far above the old mid-campaign daily (85–97 arrows, 10–11 waves).
  static const DailyThreshold minimum = DailyThreshold(
    gridSize: 90,
    arrows: 220,
    averageLength: 16,
    longestArrow: 50,
    dependencyDepth: 20,
    blockedShare: 0.78,
    blockingPerArrow: 3.5,
    maxAverageFreeShare: 0.22,
  );

  /// Generates the daily board for [dateSeed] (see DailyChallenge.seedFromDate).
  static LevelModel generate(int dateSeed) =>
      generateWithReport(dateSeed).level;

  /// [generate], plus the measured difficulty and how many attempts it took.
  static DailyResult generateWithReport(int dateSeed) {
    final spec = DifficultyCurve.forDaily();
    DailyResult? hardest;
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      final seed = attempt == 0 ? dateSeed : _attemptSeed(dateSeed, attempt);
      final level = LevelGenerator.generate(
        levelNumber: 0,
        seed: seed,
        baseSpec: spec,
        silhouette: DifficultyCurve.dailySilhouette(seed),
      );
      if (level == null || LevelValidator.problems(level).isNotEmpty) continue;
      final measured = PuzzleDifficulty.measure(level);
      if (measured == null) continue;
      final result = DailyResult(level, measured, attempt + 1);
      if (minimum.failures(measured).isEmpty) return result;
      if (hardest == null || measured.score > hardest.difficulty.score) {
        hardest = result;
      }
    }
    // Every attempt fell short of the floor: the hardest validated board.
    return hardest!.asFallback();
  }

  static int _attemptSeed(int seed, int attempt) =>
      (seed ^ (attempt * 0x2545F491) ^ 0xDA1) & 0x7FFFFFFF;
}

/// One generated daily board and its measured difficulty.
class DailyResult {
  final LevelModel level;
  final PuzzleDifficulty difficulty;
  final int attempts;

  /// True when no attempt reached [DailyChallengeGenerator.minimum] and the
  /// hardest valid board was used instead.
  final bool fallback;

  const DailyResult(
    this.level,
    this.difficulty,
    this.attempts, {
    this.fallback = false,
  });

  DailyResult asFallback() => DailyResult(
    level,
    difficulty,
    DailyChallengeGenerator.maxAttempts,
    fallback: true,
  );
}

/// Minimum difficulty a board must measure to count as a daily challenge.
class DailyThreshold {
  final int gridSize;
  final int arrows;
  final double averageLength;
  final int longestArrow;
  final int dependencyDepth;
  final double blockedShare;
  final double blockingPerArrow;
  final double maxAverageFreeShare;

  const DailyThreshold({
    required this.gridSize,
    required this.arrows,
    required this.averageLength,
    required this.longestArrow,
    required this.dependencyDepth,
    required this.blockedShare,
    required this.blockingPerArrow,
    required this.maxAverageFreeShare,
  });

  /// Every way [d] falls short; empty when it is hard enough.
  List<String> failures(PuzzleDifficulty d) => [
    if (d.gridSize < gridSize) 'board ${d.gridSize} < $gridSize',
    if (d.arrows < arrows) 'arrows ${d.arrows} < $arrows',
    if (d.averageLength < averageLength)
      'average length ${d.averageLength.toStringAsFixed(1)} < $averageLength',
    if (d.longestArrow < longestArrow)
      'longest arrow ${d.longestArrow} < $longestArrow',
    if (d.dependencyDepth < dependencyDepth)
      'dependency depth ${d.dependencyDepth} < $dependencyDepth',
    if (d.blockedShare < blockedShare)
      'blocked at start ${d.blockedShare.toStringAsFixed(2)} < $blockedShare',
    if (d.blockingPerArrow < blockingPerArrow)
      'blocking per arrow ${d.blockingPerArrow.toStringAsFixed(2)} '
          '< $blockingPerArrow',
    if (d.averageFreeShare > maxAverageFreeShare)
      'average free share ${d.averageFreeShare.toStringAsFixed(2)} '
          '> $maxAverageFreeShare',
  ];
}

import 'dart:math';

import '../../core/constants/app_constants.dart';
import '../../core/constants/app_strings.dart';
import '../../data/models/difficulty.dart';
import '../generator/silhouette.dart';
import '../generator/silhouette_library.dart';

/// Everything the generator needs to build one board.
class PuzzleSpec {
  /// Square board size (cells per side).
  final int gridSize;

  /// Share of the shape mask the generator tries to fill with arrows.
  final double fill;

  /// Average arrow length (cells) the generator aims for.
  final double avgArrowLen;

  /// Upper bound of the longest length tier (cells).
  final int maxTierLen;

  /// Longest an arrow may grow while absorbing leftover cells.
  final int maxAbsorbLen;

  /// Minimum average number of 90° turns per arrow.
  final double minAvgBends;

  /// Minimum dependency depth (longest chain of "must clear first").
  final int minDepth;

  /// Minimum share of the mask that must end up covered.
  final double minOccupancy;

  /// Label shown in the HUD and used for the level's world.
  final Difficulty difficulty;

  /// Planning steps the board should need: waves of "clear everything that
  /// is free right now" (see [LevelSolver.planningStats]).
  final double targetRounds;

  /// Share of arrows that are blocked on the first tap, i.e. traps the player
  /// must reason past rather than tap blindly.
  final double targetBlockedShare;

  /// Arrow count the board should reach regardless of the shape's size.
  final int arrowFloor;

  /// Playable silhouette cells the board should offer. The board size for a
  /// given silhouette is chosen so its picture covers about this many cells
  /// (see [DifficultyCurve.gridFor]); 0 means "use [gridSize] as is".
  final int targetCells;

  const PuzzleSpec({
    required this.gridSize,
    required this.fill,
    required this.avgArrowLen,
    required this.maxTierLen,
    required this.maxAbsorbLen,
    required this.minAvgBends,
    required this.minDepth,
    required this.minOccupancy,
    required this.difficulty,
    this.targetRounds = 4,
    this.targetBlockedShare = 0.55,
    this.arrowFloor = 4,
    this.targetCells = 0,
  });

  /// Same parameters on a different board size (tests and tools).
  PuzzleSpec withGridSize(int size) => PuzzleSpec(
    gridSize: size,
    fill: fill,
    avgArrowLen: avgArrowLen,
    maxTierLen: maxTierLen,
    maxAbsorbLen: maxAbsorbLen,
    minAvgBends: minAvgBends,
    minDepth: minDepth,
    minOccupancy: minOccupancy,
    difficulty: difficulty,
    targetRounds: targetRounds,
    targetBlockedShare: targetBlockedShare,
    arrowFloor: arrowFloor,
  );

  /// Fewest arrows a board built on [maskCells] usable cells may have.
  int minArrowsFor(int maskCells) =>
      max(4, (maskCells * fill / avgArrowLen * 0.7).floor());

  /// Single number summarising how demanding a board with these measured
  /// properties is. Used by tests and diagnostics to check that difficulty is
  /// not just "more arrows": planning rounds and traps weigh as much as size.
  static double complexityScore({
    required int arrows,
    required double avgLength,
    required double avgBends,
    required int rounds,
    required double blockedShare,
  }) =>
      arrows * 0.5 +
      avgLength * 1.0 +
      avgBends * 1.5 +
      rounds * 2.0 +
      blockedShare * 10.0;

  @override
  String toString() =>
      'PuzzleSpec(${gridSize}x$gridSize, fill $fill, avgLen $avgArrowLen, '
      'tier $maxTierLen, absorb $maxAbsorbLen, bends $minAvgBends, '
      'depth $minDepth, ${difficulty.name})';
}

/// A group of [AppConstants.levelsPerWorld] campaign levels.
class CampaignWorld {
  final int number;
  final String name;
  final Difficulty difficulty;
  final int firstLevel;
  final int lastLevel;

  const CampaignWorld({
    required this.number,
    required this.name,
    required this.difficulty,
    required this.firstLevel,
    required this.lastLevel,
  });

  bool contains(int level) => level >= firstLevel && level <= lastLevel;
  int get levelCount => lastLevel - firstLevel + 1;
}

class _Key {
  final int level;
  final double grid;
  final double fill;
  final double avgLen;
  final double maxTierLen;
  final double absorb;
  final double bends;
  final double depth;
  final double minOcc;
  final double rounds;
  final double blocked;
  final double arrows;
  final double cells;

  const _Key(
    this.level,
    this.grid,
    this.fill,
    this.avgLen,
    this.maxTierLen,
    this.absorb,
    this.bends,
    this.depth,
    this.minOcc,
    this.rounds,
    this.blocked,
    this.arrows,
    this.cells,
  );
}

/// The single source of truth for how the campaign gets harder.
///
/// Every level is a large, recognizable silhouette (animal, vehicle,
/// object…) filled with long, winding arrows. Every parameter rises with the
/// level: playable picture area, arrow count, path length, turns, dependency
/// depth, planning rounds and the share of arrows that are traps at the
/// start. The generator picks, among valid candidates, the board closest to
/// these targets, so neighbouring levels do not swing wildly. The board size
/// for a level follows its picture (see [gridFor]) and caps at
/// [AppConstants.maxGridSize]; the view frames the picture and taps that land
/// between thin arrows magnify the board instead of guessing.
class DifficultyCurve {
  DifficultyCurve._();

  // Columns: level, nominal grid, fill, avgLen, maxTierLen, absorbCap, bends,
  // depth, minOcc, planning rounds, blocked-at-start share, arrow floor,
  // playable silhouette cells.
  //
  // Level 1 already offers ~380 playable cells (a 31×31 board for a cat):
  // ~43 arrows averaging ~9 cells, the longest ~18, in 6–7 waves of
  // dependencies. By level 200 a picture offers ~1,000–1,240 cells on boards
  // up to 60×60, holding ~70–90 arrows averaging ~13 cells (the longest
  // ~30–40) in ~12 waves. Short
  // stubs are merged into their neighbours, so arrow count grows with the
  // picture, not with fragments. Bends are floors that rise every keyframe
  // (real boards wind more). Thin strokes (about a fifth of a cell) keep
  // these dense boards readable. The nominal grid gates detailed
  // silhouettes (bicycle, castle…) so new pictures keep joining.
  static const List<_Key> _keys = [
    _Key(1, 26, 0.94, 8.0, 14, 24, 3.4, 4, 0.88, 5.5, 0.56, 38, 380),
    _Key(15, 28, 0.94, 8.6, 16, 28, 3.6, 5, 0.88, 6.0, 0.58, 42, 440),
    _Key(35, 30, 0.95, 9.4, 18, 32, 3.9, 5, 0.89, 6.8, 0.60, 46, 520),
    _Key(60, 33, 0.95, 10.2, 20, 38, 4.2, 6, 0.89, 7.6, 0.62, 52, 620),
    _Key(85, 36, 0.96, 11.0, 22, 44, 4.5, 6, 0.90, 8.4, 0.64, 58, 720),
    _Key(110, 40, 0.96, 11.8, 25, 50, 4.8, 7, 0.90, 9.2, 0.66, 64, 830),
    _Key(140, 44, 0.96, 12.8, 28, 58, 5.1, 7, 0.90, 10.2, 0.68, 70, 960),
    _Key(170, 48, 0.97, 13.8, 31, 64, 5.4, 8, 0.90, 11.2, 0.70, 76, 1100),
    _Key(200, 52, 0.97, 14.6, 34, 70, 5.7, 8, 0.90, 12.0, 0.72, 82, 1240),
  ];

  static const List<(String, Difficulty)> _worldDefs = [
    (AppStrings.world1, Difficulty.easy),
    (AppStrings.world2, Difficulty.normal),
    (AppStrings.world3, Difficulty.normal),
    (AppStrings.world4, Difficulty.hard),
    (AppStrings.world5, Difficulty.hard),
    (AppStrings.world6, Difficulty.expert),
    (AppStrings.world7, Difficulty.expert),
    (AppStrings.world8, Difficulty.extreme),
  ];

  /// Campaign worlds, [AppConstants.levelsPerWorld] levels each.
  static final List<CampaignWorld> worlds = [
    for (var i = 0; i < _worldDefs.length; i++)
      CampaignWorld(
        number: i + 1,
        name: _worldDefs[i].$1,
        difficulty: _worldDefs[i].$2,
        firstLevel: i * AppConstants.levelsPerWorld + 1,
        lastLevel: (i + 1) * AppConstants.levelsPerWorld,
      ),
  ];

  /// World containing [level]; levels past the campaign belong to the last.
  static CampaignWorld worldFor(int level) => worlds.firstWhere(
    (w) => w.contains(level),
    orElse: () => level < 1 ? worlds.first : worlds.last,
  );

  /// Board parameters for campaign [level]. Levels beyond the last keyframe
  /// use the final (mastery) parameters.
  static PuzzleSpec forLevel(int level) {
    final n = level.clamp(_keys.first.level, _keys.last.level);
    var i = 0;
    while (i < _keys.length - 2 && n > _keys[i + 1].level) {
      i++;
    }
    final a = _keys[i];
    final b = _keys[i + 1];
    final t = (n - a.level) / (b.level - a.level);
    double lerp(double x, double y) => x + (y - x) * t;

    return PuzzleSpec(
      gridSize: lerp(a.grid, b.grid).round(),
      fill: lerp(a.fill, b.fill),
      avgArrowLen: lerp(a.avgLen, b.avgLen),
      maxTierLen: lerp(a.maxTierLen, b.maxTierLen).round(),
      maxAbsorbLen: lerp(a.absorb, b.absorb).round(),
      minAvgBends: lerp(a.bends, b.bends),
      minDepth: lerp(a.depth, b.depth).floor(),
      minOccupancy: lerp(a.minOcc, b.minOcc),
      difficulty: worldFor(level).difficulty,
      targetRounds: lerp(a.rounds, b.rounds),
      targetBlockedShare: lerp(a.blocked, b.blocked),
      arrowFloor: lerp(a.arrows, b.arrows).round(),
      targetCells: lerp(a.cells, b.cells).round(),
    );
  }

  /// A representative campaign level for an explicitly requested difficulty
  /// (daily challenge, tests).
  static int representativeLevel(Difficulty difficulty) => switch (difficulty) {
    Difficulty.easy => 15,
    Difficulty.normal => 50,
    Difficulty.hard => 100,
    Difficulty.expert => 150,
    Difficulty.extreme => 200,
  };

  static PuzzleSpec forDifficulty(Difficulty difficulty) {
    final spec = forLevel(representativeLevel(difficulty));
    return PuzzleSpec(
      gridSize: spec.gridSize,
      fill: spec.fill,
      avgArrowLen: spec.avgArrowLen,
      maxTierLen: spec.maxTierLen,
      maxAbsorbLen: spec.maxAbsorbLen,
      minAvgBends: spec.minAvgBends,
      minDepth: spec.minDepth,
      minOccupancy: spec.minOccupancy,
      difficulty: difficulty,
      targetRounds: spec.targetRounds,
      targetBlockedShare: spec.targetBlockedShare,
      arrowFloor: spec.arrowFloor,
      targetCells: spec.targetCells,
    );
  }

  // ── Silhouettes ─────────────────────────────────────────────────────────

  /// Silhouettes that suit a level with nominal board [gridSize] and, when
  /// given, [targetCells] of playable picture. Detailed pictures (bicycle,
  /// motorcycle, castle…) join as boards grow, and slim pictures that could
  /// not offer enough playable cells even on the largest board retire from
  /// the dense late levels, so the cast keeps changing through the campaign.
  static List<Silhouette> silhouettePoolFor(
    int gridSize, {
    int targetCells = 0,
  }) => [
    for (final s in SilhouetteLibrary.all)
      if (s.minGrid <= gridSize &&
          areaAt(s, AppConstants.maxGridSize) >= targetCells * 0.75)
        s,
  ];

  static final Map<String, double> _shareMemo = {};
  static final Map<(String, int), int> _areaMemo = {};

  /// Share of a board the silhouette covers (measured on a 20×20 raster).
  static double areaShare(Silhouette s) =>
      _shareMemo.putIfAbsent(s.id, () => s.rasterize(20).cells.length / 400);

  /// Playable cells [s] actually offers on a [gridSize] board. Measured, not
  /// estimated: thin pictures (spiral, bicycle) rasterize fatter on small
  /// boards, so a share taken at one size misjudges another.
  static int areaAt(Silhouette s, int gridSize) => _areaMemo.putIfAbsent(
    (s.id, gridSize),
    () => s.rasterize(gridSize).cells.length,
  );

  /// Board size for [s] at [spec]: the smallest board on which the picture
  /// offers `spec.targetCells` playable cells, so every level gives a similar
  /// amount of puzzle whatever its shape. A compact picture (castle) therefore
  /// gets a smaller board with bigger cells, a slim one (airplane) a larger
  /// board. Never below 18×18, the shape's own minimum, or above the cap.
  static int gridFor(PuzzleSpec spec, Silhouette s) {
    if (spec.targetCells <= 0) return spec.gridSize;
    final lo = max(18, s.minGrid);
    const hi = AppConstants.maxGridSize;
    // Start from the area-share estimate, then step to the exact size.
    var g = sqrt(spec.targetCells / areaShare(s)).round().clamp(lo, hi);
    while (g < hi && areaAt(s, g) < spec.targetCells) {
      g++;
    }
    while (g > lo && areaAt(s, g - 1) >= spec.targetCells) {
      g--;
    }
    return g;
  }

  /// How many recent levels a silhouette must sit out before it returns.
  static const int repeatGap = 8;

  /// Iconic animals and vehicles shown first, one per opening level.
  static const List<String> openingSilhouettes = [
    'cat',
    'car',
    'fish',
    'butterfly',
    'rocket',
    'house',
    'owl',
    'truck',
  ];

  static final List<Silhouette> _sequence = [];
  static final Map<String, int> _uses = {};

  /// Deterministic silhouette for campaign [level]. Shapes rotate evenly
  /// (least-used first), never repeat within [repeatGap] levels, and a shape
  /// unlocked by a bigger board joins the rotation at the current usage level
  /// instead of monopolising the next few levels.
  static Silhouette silhouetteForLevel(int level) {
    if (level < 1) return silhouetteForSeed(level, forLevel(1).gridSize);
    while (_sequence.length < level) {
      final n = _sequence.length + 1;
      final spec = forLevel(n);
      final pool = silhouettePoolFor(
        spec.gridSize,
        targetCells: spec.targetCells,
      );
      final known = [
        for (final s in pool)
          if (_uses.containsKey(s.id)) s,
      ];
      final floor = known.isEmpty
          ? 0
          : known.map((s) => _uses[s.id]!).reduce(min);
      for (final s in pool) {
        _uses.putIfAbsent(s.id, () => floor);
      }
      final gap = min(repeatGap, pool.length - 1);
      final recent = {for (final s in _sequence.reversed.take(gap)) s.id};
      Silhouette? pick;
      var pickKey = 0;
      for (var i = 0; i < pool.length; i++) {
        final s = pool[i];
        if (recent.contains(s.id)) continue;
        // Fewest uses first; ties broken by a per-level hash, so the order
        // is varied but fixed.
        final key = _uses[s.id]! * 0x10000000 + (_mix(n * 131 + i) & 0xFFFFFFF);
        if (pick == null || key < pickKey) {
          pick = s;
          pickKey = key;
        }
      }
      // The campaign opens with instantly recognizable pictures.
      if (n <= openingSilhouettes.length) {
        final id = openingSilhouettes[n - 1];
        final opener = pool.where((s) => s.id == id);
        if (opener.isNotEmpty && !recent.contains(id)) pick = opener.first;
      }
      _uses[pick!.id] = _uses[pick.id]! + 1;
      _sequence.add(pick);
    }
    return _sequence[level - 1];
  }

  /// Deterministic silhouette for a seeded, non-campaign board (daily).
  static Silhouette silhouetteForSeed(
    int seed,
    int gridSize, {
    int targetCells = 0,
  }) {
    final pool = silhouettePoolFor(gridSize, targetCells: targetCells);
    return pool[_mix(seed) % pool.length];
  }

  static int _mix(int x) {
    var h = (x * 0x9E3779B1) & 0xFFFFFFFF;
    h ^= h >> 15;
    h = (h * 0x85EBCA77) & 0xFFFFFFFF;
    h ^= h >> 13;
    return h & 0x7FFFFFFF;
  }
}

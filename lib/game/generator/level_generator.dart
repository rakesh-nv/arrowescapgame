import 'dart:math';

import '../../data/models/arrow_direction.dart';
import '../../data/models/arrow_model.dart';
import '../../data/models/difficulty.dart';
import '../../data/models/level_model.dart';
import '../solver/level_solver.dart';
import 'dependency_analyzer.dart';
import 'dot_grid_generator.dart';
import 'shape_template.dart';

typedef Cell = (int, int);

/// Public diagnostic description used by generator tests and debug tools.
class LevelLayoutInfo {
  final String shape;
  final String family;

  const LevelLayoutInfo({required this.shape, required this.family});

  @override
  String toString() => '$shape / $family';
}

enum _RouteField {
  horizontal,
  vertical,
  mixed,
  zigzag,
  spiral,
  radial,
  border,
  diagonal,
  organic,
  maze,
}

class _Template {
  final String shapeName;
  final ShapeTemplate shapeTemplate;
  final String family;
  final _RouteField field;

  const _Template(this.shapeName, this.shapeTemplate, this.family, this.field);
}

class _DifficultyParams {
  final int gridSize;
  final double targetDensity;
  final int maxMistakes;
  final double minBends;
  final int minDepth;
  final int minArrows;
  final int maxArrowLen;
  final double avgTargetLen; // target average path length in cells

  const _DifficultyParams({
    required this.gridSize,
    required this.targetDensity,
    required this.maxMistakes,
    required this.minBends,
    required this.minDepth,
    required this.minArrows,
    required this.maxArrowLen,
    required this.avgTargetLen,
  });
}

/// Advanced generator producing dense, puzzle-like Arrow Escape boards.
/// Targets 20-100+ arrows per level filling recognizable shape silhouettes.
class LevelGenerator {
  LevelGenerator._();

  // 40 templates covering all required shape families
  static final List<_Template> _templates = [
    // ── Geometric ──────────────────────────────────────────────────────────
    _Template('heart',      ShapeTemplate.fromName('heart'),      'interlocking heart',     _RouteField.radial),
    _Template('circle',     ShapeTemplate.fromName('circle'),     'spiral rings',           _RouteField.spiral),
    _Template('square',     ShapeTemplate.fromName('square'),     'woven maze',             _RouteField.maze),
    _Template('rectangle',  ShapeTemplate.fromName('rectangle'),  'dense grid lattice',     _RouteField.mixed),
    _Template('diamond',    ShapeTemplate.fromName('diamond'),    'diagonal stepped',       _RouteField.diagonal),
    _Template('triangle',   ShapeTemplate.fromName('triangle'),   'stepped pyramid',        _RouteField.diagonal),
    _Template('star',       ShapeTemplate.fromName('star'),       'radial burst',           _RouteField.radial),
    _Template('ring',       ShapeTemplate.fromName('ring'),       'concentric loops',       _RouteField.spiral),
    _Template('moon',       ShapeTemplate.fromName('moon'),       'crescent serpentine',    _RouteField.spiral),
    _Template('lightning',  ShapeTemplate.fromName('lightning'),  'jagged switchback',      _RouteField.zigzag),
    _Template('gem',        ShapeTemplate.fromName('gem'),        'faceted interlocking',   _RouteField.diagonal),
    _Template('irregular',  ShapeTemplate.fromName('irregular'),  'organic labyrinth',      _RouteField.organic),
    // ── Nature / Animals ───────────────────────────────────────────────────
    _Template('butterfly',  ShapeTemplate.fromName('butterfly'),  'symmetric wings',        _RouteField.mixed),
    _Template('cat',        ShapeTemplate.fromName('cat'),        'whiskered winding',      _RouteField.zigzag),
    _Template('dog',        ShapeTemplate.fromName('dog'),        'floppy ears cluster',    _RouteField.mixed),
    _Template('fish',       ShapeTemplate.fromName('fish'),       'streamlined switchback', _RouteField.zigzag),
    _Template('tree',       ShapeTemplate.fromName('tree'),       'branching canopy',       _RouteField.organic),
    _Template('cloud',      ShapeTemplate.fromName('cloud'),      'puffy switchback',       _RouteField.zigzag),
    // ── Objects ────────────────────────────────────────────────────────────
    _Template('house',      ShapeTemplate.fromName('house'),      'structural maze',        _RouteField.maze),
    _Template('crown',      ShapeTemplate.fromName('crown'),      'triple peak cluster',    _RouteField.mixed),
    _Template('trophy',     ShapeTemplate.fromName('trophy'),     'handled cup core',       _RouteField.radial),
    _Template('rocket',     ShapeTemplate.fromName('rocket'),     'vertical thrust core',   _RouteField.vertical),
    // ── Second rotation of key shapes with different field to vary internals ──
    _Template('heart',      ShapeTemplate.fromName('heart'),      'heart zigzag',           _RouteField.zigzag),
    _Template('circle',     ShapeTemplate.fromName('circle'),     'circle maze',            _RouteField.maze),
    _Template('star',       ShapeTemplate.fromName('star'),       'star winding',           _RouteField.organic),
    _Template('diamond',    ShapeTemplate.fromName('diamond'),    'diamond radial',         _RouteField.radial),
    _Template('butterfly',  ShapeTemplate.fromName('butterfly'),  'butterfly maze',         _RouteField.maze),
    _Template('cat',        ShapeTemplate.fromName('cat'),        'cat spiral',             _RouteField.spiral),
    _Template('fish',       ShapeTemplate.fromName('fish'),       'fish horizontal',        _RouteField.horizontal),
    _Template('cloud',      ShapeTemplate.fromName('cloud'),      'cloud mixed',            _RouteField.mixed),
    _Template('tree',       ShapeTemplate.fromName('tree'),       'tree zigzag',            _RouteField.zigzag),
    _Template('moon',       ShapeTemplate.fromName('moon'),       'moon radial',            _RouteField.radial),
    _Template('gem',        ShapeTemplate.fromName('gem'),        'gem spiral',             _RouteField.spiral),
    _Template('triangle',   ShapeTemplate.fromName('triangle'),   'triangle maze',          _RouteField.maze),
    _Template('rectangle',  ShapeTemplate.fromName('rectangle'),  'rectangle zigzag',       _RouteField.zigzag),
    _Template('square',     ShapeTemplate.fromName('square'),     'square radial',          _RouteField.radial),
    _Template('crown',      ShapeTemplate.fromName('crown'),      'crown spiral',           _RouteField.spiral),
    _Template('trophy',     ShapeTemplate.fromName('trophy'),     'trophy zigzag',          _RouteField.zigzag),
    _Template('ring',       ShapeTemplate.fromName('ring'),       'ring maze',              _RouteField.maze),
    _Template('irregular',  ShapeTemplate.fromName('irregular'),  'irregular horizontal',   _RouteField.horizontal),
  ];

  // Grid sizes match the original game rendering (small cells = fast solver).
  // More arrows come from SHORTER paths, not bigger grids.
  static const Map<Difficulty, _DifficultyParams> _params = {
    Difficulty.easy: _DifficultyParams(
      gridSize: 10,          // 10×10; ~80% → ~80 usable → ~20-25 arrows at avgLen 4
      targetDensity: 0.85,
      maxMistakes: 5,
      minBends: 0.8,
      minDepth: 2,
      minArrows: 15,
      maxArrowLen: 8,
      avgTargetLen: 4.0,
    ),
    Difficulty.normal: _DifficultyParams(
      gridSize: 12,          // 12×12; ~85% → ~122 usable → ~30-35 arrows at avgLen 4
      targetDensity: 0.86,
      maxMistakes: 4,
      minBends: 1.0,
      minDepth: 2,
      minArrows: 22,
      maxArrowLen: 10,
      avgTargetLen: 4.0,
    ),
    Difficulty.hard: _DifficultyParams(
      gridSize: 14,          // 14×14; ~87% → ~170 usable → ~40-45 arrows at avgLen 4
      targetDensity: 0.87,
      maxMistakes: 3,
      minBends: 1.2,
      minDepth: 3,
      minArrows: 30,
      maxArrowLen: 12,
      avgTargetLen: 4.0,
    ),
    Difficulty.expert: _DifficultyParams(
      gridSize: 16,          // 16×16; ~88% → ~225 usable → ~55-60 arrows at avgLen 4
      targetDensity: 0.88,
      maxMistakes: 2,
      minBends: 1.4,
      minDepth: 3,
      minArrows: 45,
      maxArrowLen: 14,
      avgTargetLen: 4.0,
    ),
    Difficulty.extreme: _DifficultyParams(
      gridSize: 18,          // 18×18; ~90% → ~292 usable → ~70-75 arrows at avgLen 4
      targetDensity: 0.90,
      maxMistakes: 1,
      minBends: 1.6,
      minDepth: 4,
      minArrows: 60,
      maxArrowLen: 14,
      avgTargetLen: 4.0,
    ),
  };

  /// Returns layout information for a given level and seed.
  static LevelLayoutInfo layoutInfo({required int levelNumber, required int seed}) {
    final template = _templateFor(levelNumber, seed);
    return LevelLayoutInfo(shape: template.shapeName, family: template.family);
  }

  // Number of distinct base shapes (first 22 entries in _templates are all unique shapes)
  static const _distinctShapes = 22;

  static _Template _templateFor(int levelNumber, int seed) {
    // Shape selection is level-number-only (no seed) so anti-repetition is deterministic
    // regardless of what seed the caller uses. The seed still drives arrow placement.
    //
    // Strategy: rotate through the 22 distinct base shapes (indices 0-21).
    // Every second full cycle (levels 23-44 etc.) use the alternate-family variant
    // (indices 22-39) where one exists.
    final cycle = (levelNumber - 1) ~/ _distinctShapes; // 0, 1, 2, ...
    final slot  = (levelNumber - 1) % _distinctShapes;  // 0..21

    // Odd cycles → prefer variant (index 22+slot) if it exists
    if (cycle % 2 == 1) {
      final variantIndex = _distinctShapes + slot;
      if (variantIndex < _templates.length) return _templates[variantIndex];
    }
    return _templates[slot];
  }

  /// Generates a complete, solver-verified puzzle level.
  static LevelModel? generate({
    required int levelNumber,
    required int seed,
    required Difficulty difficulty,
  }) {
    final dotGridLevel = DotGridGenerator.generate(
      levelNumber: levelNumber,
      seed: seed,
      difficulty: difficulty,
    );
    if (dotGridLevel != null) return dotGridLevel;

    final params = _params[difficulty] ?? _params[Difficulty.normal]!;
    final template = _templateFor(levelNumber, seed);
    final shapeMask = template.shapeTemplate.generateMask(params.gridSize);

    // Primary generation attempts — capped at 20 for fast generation
    for (var attempt = 0; attempt < 20; attempt++) {
      final rng = Random(seed ^ (attempt * 0x9E3779B9) ^ (levelNumber * 7919));
      final candidate = _synthesizeLevel(rng: rng, params: params, template: template, shapeMask: shapeMask);
      if (candidate == null || candidate.isEmpty) continue;
      if (!_passesQuality(candidate, params, shapeMask)) continue;
      if (!LevelSolver.solve(candidate, params.gridSize).solvable) continue;
      return LevelModel(
        levelNumber: levelNumber, seed: seed, gridSize: params.gridSize,
        difficulty: difficulty, arrowCount: candidate.length,
        maxMistakes: params.maxMistakes, arrows: candidate,
      );
    }

    // Relaxed fallback — relaxes bend/depth thresholds ONLY; minArrows is preserved
    final relaxed = _DifficultyParams(
      gridSize: params.gridSize, targetDensity: max(0.78, params.targetDensity - 0.08),
      maxMistakes: params.maxMistakes,
      minBends: max(0.4, params.minBends - 0.5),
      minDepth: max(1, params.minDepth - 1),
      minArrows: max(4, params.minArrows - 5),
      maxArrowLen: params.maxArrowLen,
      avgTargetLen: params.avgTargetLen,
    );
    for (var attempt = 0; attempt < 12; attempt++) {
      final rng = Random(seed ^ (attempt * 0x7FFFFFED) ^ 0xBEEF);
      final candidate = _synthesizeLevel(rng: rng, params: relaxed, template: template, shapeMask: shapeMask);
      if (candidate != null && candidate.isNotEmpty &&
          LevelSolver.solve(candidate, params.gridSize).solvable) {
        return LevelModel(
          levelNumber: levelNumber, seed: seed, gridSize: params.gridSize,
          difficulty: difficulty, arrowCount: candidate.length,
          maxMistakes: params.maxMistakes, arrows: candidate,
        );
      }
    }

    return null;
  }

  /// Calculates usable board occupancy (occupied cells / shape's usable cells).
  static double density(List<ArrowModel> arrows, int gridSize, {Set<Cell>? usableMask}) {
    final cells = <Cell>{for (final a in arrows) ...a.occupiedCells};
    final denominator = (usableMask != null && usableMask.isNotEmpty)
        ? usableMask.length : (gridSize * gridSize);
    return denominator == 0 ? 0.0 : cells.length / denominator;
  }

  // ── Core synthesis ──────────────────────────────────────────────────────

  static List<ArrowModel>? _synthesizeLevel({
    required Random rng,
    required _DifficultyParams params,
    required _Template template,
    required Set<Cell> shapeMask,
  }) {
    final gridSize = params.gridSize;
    final totalUsable = shapeMask.length;
    final targetOccupied = (totalUsable * params.targetDensity).round();

    final occupied = <Cell>{};
    final placedArrows = <ArrowModel>[]; // reverse escape order (K … 1)
    final blockedExitRays = <Cell, Set<int>>{};

    // Build shuffled target-length sequence biased toward shorter arrows
    // to achieve MORE arrows in the same space.
    final targetLengths = _buildTargetLengths(
      targetOccupied: targetOccupied,
      params: params,
      rng: rng,
    );

    for (final targetLen in targetLengths) {
      if (occupied.length >= targetOccupied) break;

      final arrow = _growReverseArrow(
        rng: rng, gridSize: gridSize, shapeMask: shapeMask,
        occupied: occupied, blockedExitRays: blockedExitRays,
        placedArrows: placedArrows, template: template,
        targetLength: targetLen, arrowIndex: placedArrows.length,
      );

      if (arrow != null && arrow.length >= 2) {
        placedArrows.add(arrow);
        occupied.addAll(arrow.occupiedCells);
        _recordExitRay(arrow, gridSize, placedArrows.length - 1, blockedExitRays);
      }
    }

    // Absorption pass: squeeze remaining cells into arrow tails
    _absorbRemainingCells(
      placedArrows: placedArrows, shapeMask: shapeMask,
      occupied: occupied, targetOccupied: targetOccupied,
      gridSize: gridSize, rng: rng,
    );

    // Compute a realistic floor based on how many arrows actually fit:
    // (targetOccupied / avgTargetLen) is the theoretical max; we require 70% of that.
    // Then take the min with params.minArrows so narrow shapes are not impossible.
    final theoreticalMax = (targetOccupied / params.avgTargetLen).floor();
    final adaptiveFloor = max(4, (theoreticalMax * 0.70).floor());
    final minArrows = min(params.minArrows, adaptiveFloor);
    if (placedArrows.length < minArrows) return null;

    // Flip to forward play order and assign clean IDs
    final forwardArrows = <ArrowModel>[];
    for (var i = 0; i < placedArrows.length; i++) {
      final a = placedArrows[placedArrows.length - 1 - i];
      forwardArrows.add(ArrowModel(
        id: 'a${(i + 1).toString().padLeft(3, '0')}',
        points: a.points,
      ));
    }
    return forwardArrows;
  }

  /// Builds a shuffled target-length list biased toward SHORT paths
  /// so many arrows pack into the same grid space (avg ≈ 4 cells/arrow).
  /// Distribution: 35% tiny(2-3), 40% short(3-5), 20% medium(5-8), 5% long(8-max).
  static List<int> _buildTargetLengths({
    required int targetOccupied,
    required _DifficultyParams params,
    required Random rng,
  }) {
    final lengths = <int>[];
    var sum = 0;
    final maxLen = params.maxArrowLen;

    while (sum < targetOccupied) {
      final roll = rng.nextDouble();
      int len;
      if (roll < 0.35) {
        // Tiny: 2–3 cells
        len = 2 + rng.nextInt(2);
      } else if (roll < 0.75) {
        // Short: 3–5 cells
        len = 3 + rng.nextInt(3);
      } else if (roll < 0.95) {
        // Medium: 5–8 cells
        len = 5 + rng.nextInt(4);
      } else {
        // Long: 8–maxLen
        len = 8 + rng.nextInt(max(1, maxLen - 7));
      }
      len = min(len, maxLen);
      lengths.add(len);
      sum += len;
    }

    lengths.shuffle(rng);
    return lengths;
  }

  // ── Reverse arrow growth (RDA) ──────────────────────────────────────────

  static ArrowModel? _growReverseArrow({
    required Random rng,
    required int gridSize,
    required Set<Cell> shapeMask,
    required Set<Cell> occupied,
    required Map<Cell, Set<int>> blockedExitRays,
    required List<ArrowModel> placedArrows,
    required _Template template,
    required int targetLength,
    required int arrowIndex,
  }) {
    // Build direction balance counts from already-placed arrows
    final dirCounts = <ArrowDirection, int>{for (final d in ArrowDirection.values) d: 0};
    for (final a in placedArrows) {
      dirCounts[a.exitDirection] = (dirCounts[a.exitDirection] ?? 0) + 1;
    }

    final candidateHeads = <(Cell, ArrowDirection, double)>[];
    for (final cell in shapeMask) {
      if (occupied.contains(cell)) continue;
      for (final dir in ArrowDirection.values) {
        if (!_isExitRayFree(cell, dir, gridSize, occupied)) continue;
        final backCell = (cell.$1 - dir.dRow, cell.$2 - dir.dCol);
        if (!shapeMask.contains(backCell) || occupied.contains(backCell)) continue;

        candidateHeads.add((cell, dir, _scoreCandidateHead(
          head: cell, dir: dir, gridSize: gridSize, shapeMask: shapeMask,
          occupied: occupied, blockedExitRays: blockedExitRays,
          template: template, arrowIndex: arrowIndex,
          dirCounts: dirCounts, rng: rng,
        )));
      }
    }

    if (candidateHeads.isEmpty) return null;
    candidateHeads.sort((a, b) => b.$3.compareTo(a.$3));

    final topCount = min(6, candidateHeads.length);
    final chosen = candidateHeads[rng.nextInt(topCount)];
    final head = chosen.$1;
    final dir = chosen.$2;

    // Grow path backwards from head
    final path = <Cell>[head, (head.$1 - dir.dRow, head.$2 - dir.dCol)];
    final pathSet = path.toSet();

    // Track consecutive straight steps to enforce bending
    var straightRun = 1;
    const maxStraightRun = 4; // force a turn after this many straight steps

    while (path.length < targetLength) {
      final tail = path.last;
      final prev = path[path.length - 2];
      final prevDelta = (tail.$1 - prev.$1, tail.$2 - prev.$2);

      final neighbors = <(Cell, double)>[];
      for (final delta in const <Cell>[(-1, 0), (1, 0), (0, -1), (0, 1)]) {
        final next = (tail.$1 + delta.$1, tail.$2 + delta.$2);
        if (!shapeMask.contains(next) || occupied.contains(next) || pathSet.contains(next)) continue;

        var score = 1.0;
        final isTurn = delta.$1 != prevDelta.$1 || delta.$2 != prevDelta.$2;

        // Enforce bends: if we've been straight too long, penalize straight
        if (straightRun >= maxStraightRun && !isTurn) {
          score -= 5.0;
        } else if (isTurn) {
          score += 3.5; // reward bends
        } else {
          score += 0.5;
        }

        // DEPENDENCY: huge bonus for crossing an existing arrow's exit ray
        if (blockedExitRays.containsKey(next)) {
          final count = blockedExitRays[next]!.length;
          score += 9.0 + count * 3.0;
        } else {
          // lookahead: steer towards exit rays
          for (final d in const <Cell>[(-1, 0), (1, 0), (0, -1), (0, 1)]) {
            final ahead = (next.$1 + d.$1, next.$2 + d.$2);
            if (blockedExitRays.containsKey(ahead) && !occupied.contains(ahead)) {
              score += 3.0;
              break;
            }
          }
        }

        score += _fieldStepScore(template.field, tail, next, gridSize);

        // Anti-trap: prefer cells with at least one free neighbor after stepping
        final freeN = _countFreeNeighbors(next, shapeMask, occupied, pathSet);
        if (freeN == 0 && path.length < targetLength - 1) score -= 2.0;
        else score += freeN * 0.4;

        neighbors.add((next, score + rng.nextDouble() * 1.2));
      }

      if (neighbors.isEmpty) break;
      neighbors.sort((a, b) => b.$2.compareTo(a.$2));
      final nextCell = neighbors.first.$1;
      final isTurn = (nextCell.$1 - tail.$1) != prevDelta.$1 ||
                     (nextCell.$2 - tail.$2) != prevDelta.$2;
      straightRun = isTurn ? 0 : straightRun + 1;

      path.add(nextCell);
      pathSet.add(nextCell);
    }

    if (path.length < 2) return null;
    // path[0] = head, path.last = tail → reverse to get tail-first for ArrowModel
    return ArrowModel(id: 'tmp_$arrowIndex', points: path.reversed.toList());
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  static bool _isExitRayFree(Cell head, ArrowDirection dir, int gridSize, Set<Cell> occupied) {
    var r = head.$1 + dir.dRow;
    var c = head.$2 + dir.dCol;
    while (r >= 0 && r < gridSize && c >= 0 && c < gridSize) {
      if (occupied.contains((r, c))) return false;
      r += dir.dRow;
      c += dir.dCol;
    }
    return true;
  }

  static double _scoreCandidateHead({
    required Cell head,
    required ArrowDirection dir,
    required int gridSize,
    required Set<Cell> shapeMask,
    required Set<Cell> occupied,
    required Map<Cell, Set<int>> blockedExitRays,
    required _Template template,
    required int arrowIndex,
    required Map<ArrowDirection, int> dirCounts,
    required Random rng,
  }) {
    var score = 2.0;
    final center = (gridSize - 1) / 2.0;
    final distToCenter = sqrt(pow(head.$1 - center, 2) + pow(head.$2 - center, 2));

    // Strong direction balancing
    final maxUsed = dirCounts.values.fold<int>(0, max);
    final thisCount = dirCounts[dir] ?? 0;
    score += (maxUsed - thisCount) * 7.0;

    // Central cluster preference for early arrows; outer for later
    if (arrowIndex < 6) {
      score += max(0.0, 4.0 - distToCenter * 0.5);
    } else {
      score += distToCenter * 0.2;
    }

    // Dependency creation: bonus if head covers an existing exit ray
    if (blockedExitRays.containsKey(head)) {
      score += 6.0;
    }

    return score + rng.nextDouble() * 2.0;
  }

  static double _fieldStepScore(_RouteField field, Cell from, Cell to, int size) {
    final horizontal = from.$1 == to.$1;
    final center = (size - 1) / 2.0;
    final dx = to.$2 - center;
    final dy = to.$1 - center;

    switch (field) {
      case _RouteField.horizontal: return horizontal ? 2.5 : 0.2;
      case _RouteField.vertical:   return horizontal ? 0.2 : 2.5;
      case _RouteField.mixed:
        return ((to.$1 + to.$2) & 1) == 0
            ? (horizontal ? 2.0 : 0.5)
            : (horizontal ? 0.5 : 2.0);
      case _RouteField.zigzag || _RouteField.maze: return 2.0;
      case _RouteField.spiral:
        return horizontal ? dy.abs() * 0.35 : dx.abs() * 0.35;
      case _RouteField.radial:
        final fromD = pow(from.$1 - center, 2) + pow(from.$2 - center, 2);
        final toD   = pow(to.$1   - center, 2) + pow(to.$2   - center, 2);
        return toD > fromD ? 2.0 : 1.0;
      case _RouteField.diagonal:
        return ((dx.abs() - dy.abs()).abs() < 1.5) ? 2.2 : 0.8;
      case _RouteField.border:
        final bd = min(min(to.$1, to.$2), min(size - 1 - to.$1, size - 1 - to.$2));
        return max(0.0, 3.0 - bd * 0.5);
      case _RouteField.organic:
        return 1.0 + sin((to.$1 + to.$2) * 1.4);
    }
  }

  static int _countFreeNeighbors(Cell cell, Set<Cell> shapeMask, Set<Cell> occupied, Set<Cell> pathSet) {
    var count = 0;
    for (final d in const <Cell>[(-1, 0), (1, 0), (0, -1), (0, 1)]) {
      final n = (cell.$1 + d.$1, cell.$2 + d.$2);
      if (shapeMask.contains(n) && !occupied.contains(n) && !pathSet.contains(n)) count++;
    }
    return count;
  }

  static void _recordExitRay(ArrowModel arrow, int gridSize, int idx, Map<Cell, Set<int>> rays) {
    final dir = arrow.exitDirection;
    var r = arrow.headRow + dir.dRow;
    var c = arrow.headCol + dir.dCol;
    while (r >= 0 && r < gridSize && c >= 0 && c < gridSize) {
      rays.putIfAbsent((r, c), () => <int>{}).add(idx);
      r += dir.dRow;
      c += dir.dCol;
    }
  }

  static void _absorbRemainingCells({
    required List<ArrowModel> placedArrows,
    required Set<Cell> shapeMask,
    required Set<Cell> occupied,
    required int targetOccupied,
    required int gridSize,
    required Random rng,
  }) {
    if (placedArrows.isEmpty) return;

    // Pass 1: extend existing arrow tails into adjacent free cells
    var modified = true;
    while (occupied.length < targetOccupied && modified) {
      modified = false;
      final indices = List<int>.generate(placedArrows.length, (i) => i)..shuffle(rng);
      for (final i in indices) {
        if (occupied.length >= targetOccupied) break;
        final arrow = placedArrows[i];
        if (arrow.length >= 16) continue; // prevent excessive length
        final tail = arrow.points.first;

        final deltas = [(-1, 0), (1, 0), (0, -1), (0, 1)]..shuffle(rng);
        for (final delta in deltas) {
          final next = (tail.$1 + delta.$1, tail.$2 + delta.$2);
          if (shapeMask.contains(next) && !occupied.contains(next)) {
            placedArrows[i] = ArrowModel(id: arrow.id, points: [next, ...arrow.points]);
            occupied.add(next);
            modified = true;
            break;
          }
        }
      }
    }

    // Pass 2: place minimal 2-cell arrows in remaining isolated gaps
    if (occupied.length < targetOccupied) {
      // Build per-direction count to balance gap-fill arrows
      final dirCounts = <ArrowDirection, int>{for (final d in ArrowDirection.values) d: 0};
      for (final a in placedArrows) dirCounts[a.exitDirection] = (dirCounts[a.exitDirection] ?? 0) + 1;

      for (final cell in shapeMask) {
        if (occupied.contains(cell)) continue;
        // Sort directions by least used first
        final dirs = ArrowDirection.values.toList()
          ..sort((a, b) => (dirCounts[a] ?? 0).compareTo(dirCounts[b] ?? 0));

        for (final dir in dirs) {
          final tail = (cell.$1 - dir.dRow, cell.$2 - dir.dCol);
          if (!shapeMask.contains(tail) || occupied.contains(tail)) continue;
          if (!_isExitRayFree(cell, dir, gridSize, occupied)) continue;

          occupied.addAll([tail, cell]);
          placedArrows.add(ArrowModel(id: 'gap_${placedArrows.length}', points: [tail, cell]));
          dirCounts[dir] = (dirCounts[dir] ?? 0) + 1;
          break;
        }
        if (occupied.length >= targetOccupied) break;
      }
    }
  }

  // ── Quality gate ─────────────────────────────────────────────────────────

  static bool _passesQuality(List<ArrowModel> arrows, _DifficultyParams params, Set<Cell> shapeMask) {
    // Arrow count floor
    if (arrows.length < params.minArrows) return false;

    // Density against usable mask
    final occ = density(arrows, params.gridSize, usableMask: shapeMask);
    if (occ < params.targetDensity) return false;

    // Valid paths
    if (arrows.any((a) => !a.hasValidPath || a.length < 2)) return false;

    // Direction balance: no single direction > 45% (generous for small counts)
    final dirCounts = <ArrowDirection, int>{};
    for (final a in arrows) dirCounts[a.exitDirection] = (dirCounts[a.exitDirection] ?? 0) + 1;
    final dominant = dirCounts.values.fold<int>(0, max);
    if (dominant / arrows.length > 0.46) return false;

    // Average bends
    final totalTurns = arrows.fold<int>(0, (s, a) => s + a.turns);
    if (totalTurns / arrows.length < params.minBends) return false;

    // Dependency depth
    final metrics = DependencyAnalyzer.analyze(arrows, params.gridSize, usableMask: shapeMask);
    if (metrics.dependencyDepth < params.minDepth) return false;

    // No large empty region
    if (_hasLargeEmptyRegion(arrows, shapeMask, params.gridSize)) return false;

    return true;
  }

  static bool _hasLargeEmptyRegion(List<ArrowModel> arrows, Set<Cell> shapeMask, int size) {
    final used = <Cell>{for (final a in arrows) ...a.occupiedCells};
    final seen = <Cell>{};
    final maxCluster = max(6, (shapeMask.length * 0.08).ceil());

    for (final cell in shapeMask) {
      if (used.contains(cell) || !seen.add(cell)) continue;
      final queue = [cell];
      var count = 0;
      while (queue.isNotEmpty) {
        final cur = queue.removeLast();
        count++;
        if (count > maxCluster) return true;
        for (final d in const <Cell>[(-1, 0), (1, 0), (0, -1), (0, 1)]) {
          final n = (cur.$1 + d.$1, cur.$2 + d.$2);
          if (shapeMask.contains(n) && !used.contains(n) && seen.add(n)) queue.add(n);
        }
      }
    }
    return false;
  }
}

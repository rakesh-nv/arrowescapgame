import 'dart:math';

import '../../data/models/arrow_direction.dart';
import '../../data/models/arrow_model.dart';
import 'shape_template.dart';

class LevelMetrics {
  final int arrowCount;
  final double occupancy;
  final double averagePathLength;
  final double averageBends;
  final int dependencyDepth;
  final double branchingFactor;
  final Map<ArrowDirection, double> directionDistribution;
  final Map<String, double> lengthDistribution;

  const LevelMetrics({
    required this.arrowCount,
    required this.occupancy,
    required this.averagePathLength,
    required this.averageBends,
    required this.dependencyDepth,
    required this.branchingFactor,
    required this.directionDistribution,
    required this.lengthDistribution,
  });

  @override
  String toString() {
    final dirs = directionDistribution.entries
        .map((e) => '${_dirSymbol(e.key)}:${(e.value * 100).toStringAsFixed(0)}%')
        .join(' ');
    return '$arrowCount arrows | ${(occupancy * 100).toStringAsFixed(1)}% occ | '
        'avgLen:${averagePathLength.toStringAsFixed(1)} | '
        'avgBends:${averageBends.toStringAsFixed(1)} | '
        'depth:$dependencyDepth | dirs:[$dirs]';
  }

  static String _dirSymbol(ArrowDirection dir) {
    switch (dir) {
      case ArrowDirection.up:
        return '↑';
      case ArrowDirection.down:
        return '↓';
      case ArrowDirection.left:
        return '←';
      case ArrowDirection.right:
        return '→';
    }
  }
}

/// Computes puzzle complexity metrics and dependency structure.
class DependencyAnalyzer {
  DependencyAnalyzer._();

  static LevelMetrics analyze(
    List<ArrowModel> arrows,
    int gridSize, {
    Set<Cell>? usableMask,
  }) {
    if (arrows.isEmpty) {
      return const LevelMetrics(
        arrowCount: 0,
        occupancy: 0,
        averagePathLength: 0,
        averageBends: 0,
        dependencyDepth: 0,
        branchingFactor: 0,
        directionDistribution: {},
        lengthDistribution: {},
      );
    }

    final totalOccupied = <Cell>{for (final a in arrows) ...a.occupiedCells};
    final denominator = (usableMask != null && usableMask.isNotEmpty)
        ? usableMask.length
        : (gridSize * gridSize);
    final occupancy = totalOccupied.length / denominator;

    final totalLength = arrows.fold<int>(0, (sum, a) => sum + a.length);
    final avgLen = totalLength / arrows.length;

    final totalTurns = arrows.fold<int>(0, (sum, a) => sum + a.turns);
    final avgBends = totalTurns / arrows.length;

    // Direction distribution
    final dirCounts = <ArrowDirection, int>{};
    for (final a in arrows) {
      dirCounts[a.exitDirection] = (dirCounts[a.exitDirection] ?? 0) + 1;
    }
    final dirDist = <ArrowDirection, double>{
      for (final dir in ArrowDirection.values)
        dir: (dirCounts[dir] ?? 0) / arrows.length,
    };

    // Length distribution: short (2-3), medium (4-6), long (7-10), veryLong (11+)
    var shortCount = 0;
    var mediumCount = 0;
    var longCount = 0;
    var veryLongCount = 0;
    for (final a in arrows) {
      if (a.length <= 3) {
        shortCount++;
      } else if (a.length <= 6) {
        mediumCount++;
      } else if (a.length <= 10) {
        longCount++;
      } else {
        veryLongCount++;
      }
    }
    final lenDist = {
      'short': shortCount / arrows.length,
      'medium': mediumCount / arrows.length,
      'long': longCount / arrows.length,
      'veryLong': veryLongCount / arrows.length,
    };

    // Dependency graph: which arrows block which
    // arrow B blocks arrow A if B occupies a cell on A's exit ray
    final cellToArrow = <Cell, String>{};
    for (final a in arrows) {
      for (final c in a.occupiedCells) {
        cellToArrow[c] = a.id;
      }
    }

    // blockers[A] = set of arrows that block A (must leave before A can leave)
    final blockers = <String, Set<String>>{for (final a in arrows) a.id: {}};
    // blockedBy[B] = set of arrows blocked by B (freed when B leaves)
    final blockedBy = <String, Set<String>>{for (final a in arrows) a.id: {}};

    for (final a in arrows) {
      final dir = a.exitDirection;
      var r = a.headRow + dir.dRow;
      var c = a.headCol + dir.dCol;
      while (r >= 0 && r < gridSize && c >= 0 && c < gridSize) {
        final blockerId = cellToArrow[(r, c)];
        if (blockerId != null && blockerId != a.id) {
          blockers[a.id]!.add(blockerId);
          blockedBy[blockerId]!.add(a.id);
        }
        r += dir.dRow;
        c += dir.dCol;
      }
    }

    // Branching factor: average number of arrows unblocked when an arrow escapes
    final branching = blockedBy.values.isEmpty
        ? 0.0
        : blockedBy.values.fold<int>(0, (s, b) => s + b.length) / arrows.length;

    // Dependency depth: compute longest chain using memoized DFS
    final depthMemo = <String, int>{};
    int getDepth(String arrowId, Set<String> visiting) {
      if (visiting.contains(arrowId)) return 1; // cycle guard
      if (depthMemo.containsKey(arrowId)) return depthMemo[arrowId]!;

      visiting.add(arrowId);
      var maxParentDepth = 0;
      for (final parent in blockers[arrowId]!) {
        maxParentDepth = max(maxParentDepth, getDepth(parent, visiting));
      }
      visiting.remove(arrowId);

      final d = 1 + maxParentDepth;
      depthMemo[arrowId] = d;
      return d;
    }

    var maxDepth = 0;
    for (final a in arrows) {
      maxDepth = max(maxDepth, getDepth(a.id, {}));
    }

    return LevelMetrics(
      arrowCount: arrows.length,
      occupancy: occupancy,
      averagePathLength: avgLen,
      averageBends: avgBends,
      dependencyDepth: maxDepth,
      branchingFactor: branching,
      directionDistribution: dirDist,
      lengthDistribution: lenDist,
    );
  }
}

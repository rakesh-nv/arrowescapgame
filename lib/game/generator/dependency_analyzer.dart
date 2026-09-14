import 'dart:math';

import '../../data/models/arrow_direction.dart';
import '../../data/models/arrow_model.dart';
import 'shape_template.dart';

class LevelMetrics {
  final int arrowCount;
  final int occupiedCells;
  final double occupancy;
  final double averagePathLength;
  final double averageBends;
  final int dependencyDepth;
  final double branchingFactor;
  final int connectedComponents;
  final Map<ArrowDirection, double> directionDistribution;
  final Map<String, double> lengthDistribution;
  final int shortCount;
  final int mediumCount;
  final int longCount;
  final int veryLongCount;
  final int extraLongCount;
  final int minimumPathLength;
  final int longestPathLength;

  const LevelMetrics({
    required this.arrowCount,
    required this.occupiedCells,
    required this.occupancy,
    required this.averagePathLength,
    required this.averageBends,
    required this.dependencyDepth,
    required this.branchingFactor,
    required this.connectedComponents,
    required this.directionDistribution,
    required this.lengthDistribution,
    required this.shortCount,
    required this.mediumCount,
    required this.longCount,
    required this.veryLongCount,
    required this.extraLongCount,
    required this.minimumPathLength,
    required this.longestPathLength,
  });

  @override
  String toString() {
    final dirs = directionDistribution.entries
        .map((e) => '${_dirSymbol(e.key)}:${(e.value * 100).toStringAsFixed(0)}%')
        .join(' ');
    return '$arrowCount arrows | $occupiedCells cells (${(occupancy * 100).toStringAsFixed(1)}%) | '
        'avgLen:${averagePathLength.toStringAsFixed(1)} | maxLen:$longestPathLength | '
        'short:$shortCount med:$mediumCount long:$longCount '
        'vLong:$veryLongCount xLong:$extraLongCount | '
        'depth:$dependencyDepth | comps:$connectedComponents | dirs:[$dirs]';
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
        occupiedCells: 0,
        occupancy: 0,
        averagePathLength: 0,
        averageBends: 0,
        dependencyDepth: 0,
        branchingFactor: 0,
        connectedComponents: 0,
        directionDistribution: {},
        lengthDistribution: {},
        shortCount: 0,
        mediumCount: 0,
        longCount: 0,
        veryLongCount: 0,
        extraLongCount: 0,
        minimumPathLength: 0,
        longestPathLength: 0,
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

    // Length distribution in actual grid cells.
    var shortCount = 0;
    var mediumCount = 0;
    var longCount = 0;
    var veryLongCount = 0;
    var extraLongCount = 0;
    var minimumPathLen = arrows.first.length;
    var longestPathLen = 0;

    for (final a in arrows) {
      if (a.length > longestPathLen) {
        longestPathLen = a.length;
      }
      if (a.length < minimumPathLen) {
        minimumPathLen = a.length;
      }
      if (a.length <= 4) {
        shortCount++;
      } else if (a.length <= 14) {
        mediumCount++;
      } else if (a.length <= 22) {
        longCount++;
      } else if (a.length <= 32) {
        veryLongCount++;
      } else {
        extraLongCount++;
      }
    }
    final lenDist = {
      'short': shortCount / arrows.length,
      'medium': mediumCount / arrows.length,
      'long': longCount / arrows.length,
      'veryLong': veryLongCount / arrows.length,
      'extraLong': extraLongCount / arrows.length,
    };

    // Dependency graph: which arrows block which
    final cellToArrow = <Cell, String>{};
    for (final a in arrows) {
      for (final c in a.occupiedCells) {
        cellToArrow[c] = a.id;
      }
    }

    final blockers = <String, Set<String>>{for (final a in arrows) a.id: {}};
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

    // Branching factor
    final branching = blockedBy.values.isEmpty
        ? 0.0
        : blockedBy.values.fold<int>(0, (s, b) => s + b.length) / arrows.length;

    // Dependency depth
    final depthMemo = <String, int>{};
    int getDepth(String arrowId, Set<String> visiting) {
      if (visiting.contains(arrowId)) return 1;
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

    // Connected components of the puzzle layout graph
    final adj = <String, Set<String>>{for (final a in arrows) a.id: {}};
    for (final a in arrows) {
      adj[a.id]!.addAll(blockers[a.id]!);
      adj[a.id]!.addAll(blockedBy[a.id]!);
      for (final cell in a.occupiedCells) {
        for (final d in const <Cell>[(-1, 0), (1, 0), (0, -1), (0, 1)]) {
          final n = (cell.$1 + d.$1, cell.$2 + d.$2);
          final neighborArrow = cellToArrow[n];
          if (neighborArrow != null && neighborArrow != a.id) {
            adj[a.id]!.add(neighborArrow);
            adj[neighborArrow]!.add(a.id);
          }
        }
      }
    }

    final visitedComp = <String>{};
    var compCount = 0;
    for (final a in arrows) {
      if (visitedComp.add(a.id)) {
        compCount++;
        final q = [a.id];
        while (q.isNotEmpty) {
          final curr = q.removeLast();
          for (final neighbor in adj[curr]!) {
            if (visitedComp.add(neighbor)) {
              q.add(neighbor);
            }
          }
        }
      }
    }

    return LevelMetrics(
      arrowCount: arrows.length,
      occupiedCells: totalOccupied.length,
      occupancy: occupancy,
      averagePathLength: avgLen,
      averageBends: avgBends,
      dependencyDepth: maxDepth,
      branchingFactor: branching,
      connectedComponents: compCount,
      directionDistribution: dirDist,
      lengthDistribution: lenDist,
      shortCount: shortCount,
      mediumCount: mediumCount,
      longCount: longCount,
      veryLongCount: veryLongCount,
      extraLongCount: extraLongCount,
      minimumPathLength: minimumPathLen,
      longestPathLength: longestPathLen,
    );
  }
}

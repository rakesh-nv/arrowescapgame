import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:arrowescapegame/data/models/arrow_model.dart';
import 'package:arrowescapegame/data/repositories/level_repository.dart';
import 'package:arrowescapegame/game/renderer/arrow_collision.dart';
import 'package:arrowescapegame/game/renderer/arrow_painter.dart';
import 'package:arrowescapegame/game/solver/level_solver.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _cell = 40.0;
const _grid = 12;

ArrowModel _a(List<(int, int)> pts, [String id = 'a']) =>
    ArrowModel(id: id, points: pts);

/// The four orientations of a board: identity, then rotated 90°, 180°, 270°.
List<(int, int)> _rot((int, int) Function((int, int)) f, List<(int, int)> p) =>
    [for (final q in p) f(q)];
final _rotations = <String, (int, int) Function((int, int))>{
  'right': (p) => p,
  'down': (p) => (p.$2, _grid - 1 - p.$1),
  'left': (p) => (_grid - 1 - p.$1, _grid - 1 - p.$2),
  'up': (p) => (_grid - 1 - p.$2, p.$1),
};

double? _travel(ArrowModel mover, List<ArrowModel> others) =>
    ArrowCollision.crashTravel(
      arrow: mover,
      remaining: [mover, ...others],
      gridSize: _grid,
      cellSize: _cell,
    );

/// Alpha channel of [arrow] painted alone (as the game draws it) at [shift].
Future<Uint8List> _alpha(ArrowModel arrow, double shift) async {
  const size = _cell * _grid;
  final recorder = ui.PictureRecorder();
  ArrowPainter(
    arrow: arrow,
    cellSize: _cell,
    bodyColor: Colors.black,
    glowColor: Colors.teal,
    snakeShift: shift,
    motionPath: ArrowMotionPath.build(arrow: arrow, cellSize: _cell),
  ).paint(Canvas(recorder), const Size(size, size));
  final img = await recorder.endRecording().toImage(
    size.toInt(),
    size.toInt(),
  );
  final bytes = (await img.toByteData())!.buffer.asUint8List();
  return Uint8List.fromList([
    for (var i = 3; i < bytes.length; i += 4) bytes[i],
  ]);
}

/// True when the two drawn arrows share any solidly painted pixel.
bool _overlap(Uint8List a, Uint8List b) {
  for (var i = 0; i < a.length; i++) {
    if (a[i] > 100 && b[i] > 100) return true;
  }
  return false;
}

/// Checks on the actual pixels: just before the stop the drawings are apart,
/// a little further they overlap.
Future<void> _expectStopsOnContact(
  ArrowModel mover,
  ArrowModel obstacle,
  double stop,
) async {
  final still = await _alpha(obstacle, 0);
  expect(_overlap(await _alpha(mover, stop - 1), still), isFalse,
      reason: 'already overlapping before the stop');
  expect(_overlap(await _alpha(mover, stop + 3), still), isTrue,
      reason: 'would not touch even past the stop');
}

void main() {
  group('stops on contact with the rendered shape', () {
    for (final r in _rotations.entries) {
      final f = r.value;

      test('${r.key}: straight arrow meets another arrow\'s shaft', () async {
        final mover = _a(_rot(f, [(2, 0), (2, 1), (2, 2)]));
        final wall = _a(_rot(f, [(0, 6), (1, 6), (2, 6), (3, 6), (4, 6)]), 'b');
        final d = _travel(mover, [wall])!;
        // Tip starts 0.25 cell past the head centre; the shaft's near edge
        // is half a stroke (0.1 cell) before its centre line, 4 cells away.
        expect(d, closeTo((4 - 0.25 - 0.1) * _cell, 0.6));
        await _expectStopsOnContact(mover, wall, d);
      });

      test('${r.key}: meets an arrowhead pointing back at it', () async {
        final mover = _a(_rot(f, [(2, 0), (2, 1), (2, 2)]));
        final facing = _a(_rot(f, [(2, 9), (2, 8), (2, 7)]), 'b');
        final d = _travel(mover, [facing])!;
        // Tip to tip: both tips sit 0.25 cell outside their head cells.
        expect(d, closeTo((5 - 0.5) * _cell, 0.6));
        await _expectStopsOnContact(mover, facing, d);
      });

      test('${r.key}: meets the side of a crossing arrowhead', () async {
        final mover = _a(_rot(f, [(2, 0), (2, 1), (2, 2)]));
        final head = _a(_rot(f, [(0, 6), (1, 6), (2, 6)]), 'b');
        final d = _travel(mover, [head])!;
        await _expectStopsOnContact(mover, head, d);
      });

      test('${r.key}: turning arrow meets a turning segment', () async {
        // The mover bends before its head; the obstacle's corner sits in
        // the lane.
        final mover = _a(_rot(f, [(5, 0), (4, 0), (3, 0), (2, 0), (2, 1)]));
        final corner =
            _a(_rot(f, [(0, 5), (1, 5), (2, 5), (2, 6), (2, 7)]), 'b');
        final d = _travel(mover, [corner])!;
        expect(d, lessThan((4 - 0.25) * _cell));
        await _expectStopsOnContact(mover, corner, d);
      });
    }
  });

  test('self-collision: the head stops on its own body', () {
    // Head at (2,1) pointing up; its lane meets its own body at (1,1).
    final a = _a([(1, 0), (1, 1), (1, 2), (2, 2), (3, 2), (3, 1), (2, 1)]);
    final d = ArrowCollision.crashTravel(
      arrow: a,
      remaining: [a],
      gridSize: 6,
      cellSize: _cell,
    )!;
    // Tip 0.25 cell out, body edge 0.1 cell below the row-1 centre line.
    expect(d, closeTo((1 - 0.25 - 0.1) * _cell, 0.6));
  });

  test('a clear lane never crashes', () {
    final a = _a([(2, 0), (2, 1), (2, 2)]);
    final b = _a([(4, 0), (4, 1), (4, 2)], 'b');
    expect(_travel(a, [b]), isNull);
    expect(ArrowCollision.laneCellsToCollision(a, [a, b], _grid), isNull);
  });

  group('real levels: the drawn shapes agree with the rule', () {
    for (final n in [1, 30, 120]) {
      test('level $n', () {
        final level = LevelRepository.getLevel(n);
        final arrows = level.arrows;
        final free = {
          for (final a in LevelSolver.getAvailableArrows(arrows, level.gridSize))
            a.id,
        };
        var blockedChecked = 0;
        for (final a in arrows) {
          final cells = ArrowCollision.laneCellsToCollision(
            a,
            arrows,
            level.gridSize,
          );
          if (free.contains(a.id)) {
            // An escaping arrow touches nothing all the way off the board.
            final toEdge = switch (a.exitDirection.name) {
              'up' => a.headRow,
              'down' => level.gridSize - 1 - a.headRow,
              'left' => a.headCol,
              _ => level.gridSize - 1 - a.headCol,
            };
            expect(
              ArrowCollision.contactDistance(
                arrow: a,
                remaining: arrows,
                cellSize: _cell,
                limit: (toEdge + 1) * _cell,
              ),
              isNull,
              reason: '${a.id} touches something while escaping',
            );
          } else if (blockedChecked < 25) {
            blockedChecked++;
            // A blocked arrow stops before the centre of the first occupied
            // lane cell, and no earlier than one cell short of it.
            final d = ArrowCollision.crashTravel(
              arrow: a,
              remaining: arrows,
              gridSize: level.gridSize,
              cellSize: _cell,
            )!;
            expect(d, lessThanOrEqualTo((cells! - 0.3) * _cell),
                reason: '${a.id} passes into the obstacle');
            expect(d, greaterThanOrEqualTo((cells - 1.05) * _cell),
                reason: '${a.id} stops before reaching the obstacle');
          }
        }
        expect(blockedChecked, greaterThan(0));
      });
    }
  });

  test('crash timing grows with distance and stays short', () {
    expect(CrashTiming.travelMs(1), 110);
    expect(CrashTiming.travelMs(4), greaterThan(CrashTiming.travelMs(2)));
    expect(CrashTiming.travelMs(60), 400);
    expect(CrashTiming.totalMs(60), CrashTiming.maxTotalMs);
  });
}

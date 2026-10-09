import 'dart:ui' as ui;

import 'package:arrowescapegame/data/models/arrow_model.dart';
import 'package:arrowescapegame/data/models/arrow_state.dart';
import 'package:arrowescapegame/game/config/puzzle_config.dart';
import 'package:arrowescapegame/game/renderer/arrow_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records every path draw with the paint used, ignoring other calls.
class _RecordingCanvas implements Canvas {
  final List<Paint> paints = [];

  @override
  void drawPath(ui.Path path, Paint paint) => paints.add(paint);

  @override
  void save() {}

  @override
  void restore() {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

const _cell = 40.0;
const _bodyColor = Color(0xFF1A2340);

final _arrow = ArrowModel(
  id: 'a001',
  points: const [(5, 1), (5, 2), (5, 3), (4, 3), (3, 3), (3, 4), (3, 5)],
);

List<Paint> _paint({
  double? progress,
  bool glow = false,
  ArrowState state = ArrowState.normal,
}) {
  final canvas = _RecordingCanvas();
  final arrow = _arrow.copyWith(state: state);
  ArrowPainter(
    arrow: arrow,
    cellSize: _cell,
    bodyColor: _bodyColor,
    glowColor: Colors.teal,
    showGlow: glow,
    snakeProgress: progress,
    motionPath: ArrowMotionPath.build(arrow: arrow, cellSize: _cell),
  ).paint(canvas, const Size(400, 400));
  return canvas.paints;
}

void main() {
  test('idle, escaping and blocked arrows draw only the body and its head',
      () {
    for (final (label, paints) in [
      ('idle', _paint()),
      ('escaping', _paint(progress: 0.5)),
      ('blocked', _paint(state: ArrowState.blocked)),
    ]) {
      // Exactly two shapes: the stroked body and the filled arrowhead.
      expect(paints.length, 2, reason: label);
      expect(paints[0].style, PaintingStyle.stroke, reason: label);
      expect(paints[1].style, PaintingStyle.fill, reason: label);
      for (final p in paints) {
        // No blur, i.e. no drop shadow, trail or blurred copy behind it.
        expect(p.maskFilter, isNull, reason: label);
        // Fully opaque body colour, never a translucent grey copy.
        expect(p.color.toARGB32(), _bodyColor.toARGB32(), reason: label);
      }
    }
  });

  test('the glow appears only while the hint / blocker cue is active', () {
    final paints = _paint(glow: true);
    expect(paints.length, 3);
    expect(paints.first.maskFilter, isNotNull);
    expect(paints.first.color.toARGB32() & 0x00FFFFFF,
        Colors.teal.toARGB32() & 0x00FFFFFF);
  });

  test('strokes are thin and the head stays proportionate', () {
    final body = _paint().first;
    expect(body.strokeWidth, closeTo(PuzzleConfig.strokeWidthFor(_cell), 1e-4));
    // Under a quarter of a cell: neighbouring paths keep a wide clear gap.
    expect(body.strokeWidth, lessThanOrEqualTo(_cell * 0.25));
    final head = PuzzleConfig.headSizeFor(_cell);
    // Head: ~0.6 cell long, about 1.04× as wide, so it is clearly visible
    // (2.5× the stroke or more) yet narrower than one cell.
    expect(head, greaterThanOrEqualTo(body.strokeWidth * 2.5));
    expect(head * 1.04, lessThan(_cell));
    // Layout and painter use the same formulas.
    final config = PuzzleConfig.adaptive(screenWidth: 360, overrideGridSize: 24);
    expect(config.pathThickness, PuzzleConfig.strokeWidthFor(config.cellSpacing));
    expect(config.arrowHeadSize, PuzzleConfig.headSizeFor(config.cellSpacing));
  });
}

// Renders real campaign boards with the game's own ArrowBoardWidget for the
// Play Store screenshots. Not part of the app or its test suite; run with
//
//   flutter test store_assets/arrow_escape/tools/render_boards_test.dart
//
// Output: store_assets/arrow_escape/raw_captures/v12/rendered/*.png
import 'dart:io';
import 'dart:ui' as ui;

import 'package:arrowescapegame/data/repositories/level_repository.dart';
import 'package:arrowescapegame/data/repositories/theme_repository.dart';
import 'package:arrowescapegame/game/renderer/arrow_board_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

const _out = 'store_assets/arrow_escape/raw_captures/v12/rendered';
const double _side = 1000;

/// (level, theme id) pairs to render.
const _boards = [
  (1, 'classic'),
  (60, 'classic'),
  (250, 'classic'),
  (500, 'classic'),
  (1000, 'classic'),
  (120, 'neon_glow'),
  (180, 'galaxy'),
  (90, 'sakura_garden'),
  (140, 'golden_luxury'),
];

void main() {
  testWidgets('render store boards', (tester) async {
    Directory(_out).createSync(recursive: true);
    tester.view.physicalSize = const Size(_side, _side);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    for (final (n, themeId) in _boards) {
      final level = LevelRepository.getLevel(n);
      final theme = ThemeRepository.getById(themeId);
      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          home: RepaintBoundary(
            key: key,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: theme.backgroundGradient,
                ),
              ),
              child: ArrowBoardWidget(
                key: ValueKey('$n-$themeId'),
                arrows: level.arrows,
                gridSize: level.gridSize,
                theme: theme,
                shapeCells: level.shapeCells,
                onArrowTap: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 600));

      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final name =
          'level${n.toString().padLeft(4, '0')}_${themeId}_'
          '${level.shapeName ?? 'shape'}_${level.gridSize}x${level.gridSize}_'
          '${level.arrows.length}arrows.png'
              .replaceAll(' ', '-');
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 1);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        File('$_out/$name').writeAsBytesSync(bytes!.buffer.asUint8List());
      });
      // ignore: avoid_print
      print('$name  ${level.difficulty.name}');
    }
  }, timeout: const Timeout(Duration(minutes: 10)));
}

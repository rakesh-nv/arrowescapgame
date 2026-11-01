import 'dart:io';

import 'package:arrowescapegame/core/constants/app_constants.dart';
import 'package:arrowescapegame/game/generator/level_generator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('dump', () {
    final out = File(Platform.environment['DUMP_FILE']!).openWrite();
    final sw = Stopwatch()..start();
    for (var n = 1; n <= AppConstants.totalLevels; n++) {
      final l = LevelGenerator.generate(
        levelNumber: n,
        seed: AppConstants.levelSeed(n),
      )!;
      out.writeln('L $n ${l.gridSize} ${l.shapeName} ${l.arrowCount}');
      for (final a in l.arrows) {
        out.writeln(
          'A ${a.id} ${a.points.map((p) => '${p.$1},${p.$2}').join(';')}',
        );
      }
    }
    out.close();
    // ignore: avoid_print
    print('DUMPED ${sw.elapsed}');
  }, timeout: const Timeout(Duration(hours: 2)));
}

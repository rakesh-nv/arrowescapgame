import 'package:arrowescapegame/core/constants/app_constants.dart';
import 'package:arrowescapegame/data/repositories/level_repository.dart';
import 'package:arrowescapegame/game/generator/level_generator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('prepareLevels on a background isolate yields the same boards as '
      'synchronous generation', () async {
    LevelRepository.clearCache();

    // Same sequence as startup for a player on level 2: the current level,
    // then the background preload of the next 3.
    await LevelRepository.prepareLevels(2, requireFirst: true);
    await LevelRepository.prepareLevels(3, count: 3);

    for (var n = 2; n <= 5; n++) {
      final prepared = LevelRepository.cachedLevel(n);
      expect(prepared, isNotNull, reason: 'level $n should be cached');

      // The old path: sequential generation on this isolate.
      final expected = LevelGenerator.generate(
        levelNumber: n,
        seed: AppConstants.levelSeed(n),
      );
      expect(expected, isNotNull);

      expect(
        prepared!.arrows.map((a) => [a.id, a.points]).toList(),
        equals(expected!.arrows.map((a) => [a.id, a.points]).toList()),
        reason: 'level $n board changed',
      );
    }
  });
}

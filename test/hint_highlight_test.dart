import 'package:arrowescapegame/core/constants/app_colors.dart';
import 'package:arrowescapegame/core/constants/app_constants.dart';
import 'package:arrowescapegame/data/models/player_progress.dart';
import 'package:arrowescapegame/data/repositories/level_repository.dart';
import 'package:arrowescapegame/data/repositories/progress_repository.dart';
import 'package:arrowescapegame/data/repositories/theme_repository.dart';
import 'package:arrowescapegame/game/config/puzzle_config.dart';
import 'package:arrowescapegame/game/renderer/arrow_board_widget.dart';
import 'package:arrowescapegame/game/renderer/arrow_painter.dart';
import 'package:arrowescapegame/game/solver/level_solver.dart';
import 'package:arrowescapegame/modules/ads/services/ad_service.dart';
import 'package:arrowescapegame/modules/gameplay/gameplay_controller.dart';
import 'package:arrowescapegame/services/analytics_service.dart';
import 'package:arrowescapegame/services/audio_service.dart';
import 'package:arrowescapegame/services/economy_service.dart';
import 'package:arrowescapegame/services/haptic_service.dart';
import 'package:arrowescapegame/services/storage_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

class _FakeStorage extends StorageService {
  PlayerProgress _progress = PlayerProgress(coins: 100, hints: 3);

  @override
  PlayerProgress get progress => _progress;

  @override
  Future<void> saveProgress(PlayerProgress p) async => _progress = p;
}

Future<void> _escapeWait() => Future.delayed(
  Duration(milliseconds: AppConstants.arrowFlightDurationForLength(45) + 60),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late EconomyService economy;

  setUp(() {
    Get.reset();
    final storage = _FakeStorage();
    Get.put<StorageService>(storage);
    Get.put(ProgressRepository(storage));
    economy = Get.put(EconomyService(storage));
    Get.put(HapticService());
    Get.put<IAudioService>(NoOpAudioService());
    Get.put<IAnalyticsService>(DebugAnalyticsService());
    Get.put<IAdService>(NoOpAdService());
  });

  tearDown(Get.reset);

  test('the hint stays until the hinted arrow itself is moved', () async {
    final gc = Get.put(GameplayController());
    await gc.loadLevel(30);
    final level = LevelRepository.getLevel(30);

    expect(gc.onHint(), isTrue);
    final hinted = gc.hintedArrowId.value;
    expect(hinted, isNotEmpty);

    // No timeout.
    await Future.delayed(const Duration(seconds: 3));
    expect(gc.hintedArrowId.value, hinted);

    // Moving a different free arrow leaves the hint in place.
    final other = LevelSolver.getAvailableArrows(
      level.arrows,
      level.gridSize,
    ).firstWhere((a) => a.id != hinted);
    gc.onArrowTap(other.id);
    await _escapeWait();
    expect(gc.hintedArrowId.value, hinted);

    // A blocked tap elsewhere leaves it too.
    final free = {
      for (final a in LevelSolver.getAvailableArrows(
        gc.arrows.where((a) => a.id != other.id).toList(),
        level.gridSize,
      ))
        a.id,
    };
    final blocked = gc.arrows.firstWhere(
      (a) => a.id != other.id && !free.contains(a.id),
    );
    gc.onArrowTap(blocked.id);
    expect(gc.hintedArrowId.value, hinted);
    await Future.delayed(const Duration(milliseconds: 600));

    // Moving the hinted arrow clears it.
    gc.onArrowTap(hinted);
    expect(gc.hintedArrowId.value, isEmpty);
  });

  test('pressing Hint while one is showing does not spend another', () async {
    final gc = Get.put(GameplayController());
    await gc.loadLevel(30);
    final before = economy.hints.value;

    expect(gc.onHint(), isTrue);
    final hinted = gc.hintedArrowId.value;
    expect(economy.hints.value, before - 1);

    expect(gc.onHint(), isTrue);
    expect(gc.hintedArrowId.value, hinted);
    expect(economy.hints.value, before - 1);

    // Once it has been moved, the next hint costs one again.
    gc.onArrowTap(hinted);
    await _escapeWait();
    expect(gc.onHint(), isTrue);
    expect(economy.hints.value, before - 2);
  });

  testWidgets('the hinted arrow is drawn solid blue, head included', (
    tester,
  ) async {
    final level = LevelRepository.getLevel(3);
    final hinted = level.arrows.first.id;
    for (final theme in ThemeRepository.allThemes) {
      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 400,
            height: 600,
            child: ArrowBoardWidget(
              arrows: level.arrows,
              gridSize: level.gridSize,
              shapeCells: level.shapeCells,
              theme: theme,
              hintedArrowId: hinted,
              onArrowTap: (_) {},
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
      final painter = tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((c) => c.painter)
          .whereType<ArrowPainter>()
          .single;
      final blue = theme.isDark
          ? AppColors.accentBlueLight
          : AppColors.accentBlue;
      expect(painter.arrow.id, hinted);
      expect(painter.bodyColor, blue, reason: theme.id);
      expect(painter.headColor, blue, reason: theme.id);
      expect(painter.opacity, 1.0, reason: 'steady, not pulsing');
      // Nothing keeps animating while it waits to be moved.
      expect(tester.hasRunningAnimations, isFalse, reason: theme.id);
    }
  });

  testWidgets('a hint glides the view to the whole arrow, readable', (
    tester,
  ) async {
    // A big late board on a small phone: cells are tiny at the fitted view.
    final level = LevelRepository.getLevel(200);
    const box = Size(360, 480);
    // A long arrow and a short one, both must end up fully on screen.
    final sorted = [...level.arrows]
      ..sort((a, b) => a.length.compareTo(b.length));
    Widget board(String? hint, int request) => MaterialApp(
      home: Align(
        alignment: Alignment.topLeft,
        child: SizedBox.fromSize(
          size: box,
          child: ArrowBoardWidget(
            arrows: level.arrows,
            gridSize: level.gridSize,
            shapeCells: level.shapeCells,
            theme: ThemeRepository.allThemes.first,
            hintedArrowId: hint,
            hintRequest: request,
            onArrowTap: (_) {},
          ),
        ),
      ),
    );
    TransformationController tc() => tester
        .widget<InteractiveViewer>(find.byType(InteractiveViewer))
        .transformationController!;

    await tester.pumpWidget(board(null, 0));
    await tester.pump(const Duration(milliseconds: 400));
    final fitted = tc().value.getMaxScaleOnAxis();
    final cell = PuzzleConfig.adaptive(
      screenWidth: box.width,
      screenHeight: box.height,
      overrideGridSize: level.gridSize,
    ).cellSpacing;
    expect(cell * fitted, lessThan(22), reason: 'tiny cells before the hint');

    var request = 0;
    for (final arrow in [sorted.first, sorted.last]) {
      await tester.pumpWidget(board(arrow.id, ++request));
      await tester.pumpAndSettle();
      final m = tc().value;
      final scale = m.getMaxScaleOnAxis();
      // Every cell of the arrow is on screen.
      for (final (r, c) in arrow.points) {
        final p = MatrixUtils.transformPoint(
          m,
          Offset((c + 0.5) * cell, (r + 0.5) * cell),
        );
        expect(box.contains(p), isTrue, reason: '${arrow.id} cell ($r,$c)');
      }
      // Zoomed in from the fitted view, never out past it.
      expect(scale, greaterThan(fitted));
      if (arrow == sorted.first) {
        // A short arrow gets comfortable, tappable cells.
        expect(cell * scale, greaterThanOrEqualTo(33.9));
      }
    }

    // The player pans away; pressing Hint again for the same arrow returns.
    final arrow = sorted.first;
    tc().value = Matrix4.identity()..scaleByDouble(fitted, fitted, fitted, 1);
    await tester.pump();
    await tester.pumpWidget(board(arrow.id, ++request));
    await tester.pumpAndSettle();
    final (r, c) = arrow.points[arrow.points.length ~/ 2];
    final p = MatrixUtils.transformPoint(
      tc().value,
      Offset((c + 0.5) * cell, (r + 0.5) * cell),
    );
    expect(box.contains(p), isTrue);
  });
}

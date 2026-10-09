import 'package:arrowescapegame/data/models/game_settings.dart';
import 'package:arrowescapegame/data/models/player_progress.dart';
import 'package:arrowescapegame/data/repositories/level_repository.dart';
import 'package:arrowescapegame/data/repositories/progress_repository.dart';
import 'package:arrowescapegame/data/repositories/theme_repository.dart';
import 'package:arrowescapegame/game/generator/level_generator.dart';
import 'package:arrowescapegame/game/renderer/arrow_board_widget.dart';
import 'package:arrowescapegame/modules/ads/services/ad_service.dart';
import 'package:arrowescapegame/modules/gameplay/gameplay_screen.dart';
import 'package:arrowescapegame/modules/gameplay/widgets/game_over_dialog.dart';
import 'package:arrowescapegame/modules/gameplay/widgets/level_complete_dialog.dart';
import 'package:arrowescapegame/modules/gameplay/widgets/tutorial_overlay.dart';
import 'package:arrowescapegame/modules/home/home_screen.dart';
import 'package:arrowescapegame/modules/level_select/level_select_screen.dart';
import 'package:arrowescapegame/modules/settings/settings_screen.dart';
import 'package:arrowescapegame/services/analytics_service.dart';
import 'package:arrowescapegame/services/audio_service.dart';
import 'package:arrowescapegame/services/economy_service.dart';
import 'package:arrowescapegame/services/haptic_service.dart';
import 'package:arrowescapegame/services/storage_service.dart';
import 'dart:math';

import 'package:arrowescapegame/data/models/level_model.dart';
import 'package:arrowescapegame/game/config/puzzle_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

class FakeStorageService extends StorageService {
  PlayerProgress _progress = PlayerProgress(
    coins: 120,
    hints: 3,
    hasSeenTutorial: true,
  );

  @override
  PlayerProgress get progress => _progress;

  @override
  Future<void> saveProgress(PlayerProgress p) async => _progress = p;

  GameSettings _settings = GameSettings();

  @override
  GameSettings get settings => _settings;

  @override
  Future<void> saveSettings(GameSettings s) async => _settings = s;
}

const _phones = <String, Size>{
  'small 320x568': Size(320, 568),
  'common 360x640': Size(360, 640),
  'tall 412x915': Size(412, 915),
};

void _registerServices() {
  Get.reset();
  final storage = FakeStorageService();
  Get.put<StorageService>(storage);
  Get.put(ProgressRepository(storage));
  Get.put(EconomyService(storage));
  Get.put(HapticService());
  Get.put<IAudioService>(NoOpAudioService());
  Get.put<IAnalyticsService>(DebugAnalyticsService());
  Get.put<IAdService>(NoOpAdService());
}

Future<void> _setScreen(WidgetTester tester, Size size, double textScale) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(() {
    tester.view.reset();
    tester.platformDispatcher.clearTextScaleFactorTestValue();
  });
}

Widget _board(LevelModel level, Size size, void Function(String) onTap) =>
    MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox.fromSize(
            size: size,
            child: ArrowBoardWidget(
              arrows: level.arrows,
              gridSize: level.gridSize,
              shapeCells: level.shapeCells,
              theme: ThemeRepository.allThemes.first,
              onArrowTap: onTap,
            ),
          ),
        ),
      ),
    );

TransformationController _controller(WidgetTester tester) => tester
    .widget<InteractiveViewer>(find.byType(InteractiveViewer))
    .transformationController!;

/// Scene size of one cell, as the board lays itself out.
double _sceneCell(Size box, int grid) => PuzzleConfig.adaptive(
      screenWidth: box.width,
      screenHeight: box.height,
      overrideGridSize: grid,
    ).cellSpacing;

/// Scene rectangle of the picture (silhouette cells plus half a cell).
Rect _pictureRect(LevelModel level, double cell) {
  final cells = level.shapeCells;
  final rows = cells.map((c) => c.$1);
  final cols = cells.map((c) => c.$2);
  return Rect.fromLTRB(
    (cols.reduce(min) - 0.5) * cell,
    (rows.reduce(min) - 0.5) * cell,
    (cols.reduce(max) + 1.5) * cell,
    (rows.reduce(max) + 1.5) * cell,
  );
}

Rect _screenRect(Matrix4 m, Rect scene) => Rect.fromPoints(
      MatrixUtils.transformPoint(m, scene.topLeft),
      MatrixUtils.transformPoint(m, scene.bottomRight),
    );

Offset _cellCentre(Matrix4 m, double cell, (int, int) rc) =>
    MatrixUtils.transformPoint(
      m,
      Offset((rc.$2 + 0.5) * cell, (rc.$1 + 0.5) * cell),
    );

void main() {
  setUpAll(() {
    // Generate boards up front so widget tests never wait on an isolate.
    for (final n in [1, 2, 3, 4, 120, 200]) {
      LevelRepository.getLevel(n);
    }
  });

  group('Board fit and tap accuracy', () {
    for (final n in [1, 120, 200]) {
      for (final entry in _phones.entries) {
        testWidgets('level $n on ${entry.key}', (tester) async {
          final level = LevelRepository.getLevel(n);
          final boardSize = Size(entry.value.width, entry.value.height * 0.6);
          String? tapped;
          await tester.pumpWidget(_board(level, boardSize, (id) => tapped = id));
          await tester.pump(const Duration(milliseconds: 400));

          final tc = _controller(tester);
          final cell = _sceneCell(boardSize, level.gridSize);

          // The picture fills the play area: it fits inside the box and spans
          // most of its width or height (it is not a small shape adrift in
          // empty board).
          final pic = _screenRect(tc.value, _pictureRect(level, cell));
          expect(pic.left, greaterThanOrEqualTo(-0.5));
          expect(pic.top, greaterThanOrEqualTo(-0.5));
          expect(pic.right, lessThanOrEqualTo(boardSize.width + 0.5));
          expect(pic.bottom, lessThanOrEqualTo(boardSize.height + 0.5));
          expect(
            max(pic.width / boardSize.width, pic.height / boardSize.height),
            greaterThanOrEqualTo(ArrowBoardWidget.fitFraction - 0.01),
          );
          final onScreenCell = cell * tc.value.getMaxScaleOnAxis();
          if (n == 1 && entry.value.width >= 360) {
            expect(onScreenCell, greaterThanOrEqualTo(14));
          }

          // Tapping the centre of an arrow's cell either hits that arrow or,
          // when the fingertip straddles thin neighbouring arrows on tiny
          // cells, magnifies the board; the next tap then hits it.
          final target = level.arrows[level.arrows.length ~/ 2];
          final rc = target.points[target.points.length ~/ 2];
          for (var attempt = 0; attempt < 4 && tapped == null; attempt++) {
            final before = tc.value.getMaxScaleOnAxis();
            await tester.tapAt(_cellCentre(tc.value, cell, rc));
            await tester.pumpAndSettle();
            if (tapped == null) {
              expect(tc.value.getMaxScaleOnAxis(), greaterThan(before));
            }
          }
          expect(tapped, target.id);
          if (onScreenCell >= 22) {
            // Comfortable cells never need the magnify step.
            expect(tc.value.getMaxScaleOnAxis(), closeTo(onScreenCell / cell, 1e-6));
          }
        });
      }
    }
  });

  testWidgets('pinch zoom keeps the picture on screen and taps accurate',
      (tester) async {
    final level = LevelRepository.getLevel(120);
    const boardSize = Size(412, 600);
    String? tapped;
    await tester.pumpWidget(_board(level, boardSize, (id) => tapped = id));
    await tester.pump(const Duration(milliseconds: 400));

    final tc = _controller(tester);
    final cell = _sceneCell(boardSize, level.gridSize);
    final picture = _pictureRect(level, cell);
    final fitScale = tc.value.getMaxScaleOnAxis();
    // Regression: the fitted transform must report its real (shrunk) scale;
    // a z-scale of 1 used to make InteractiveViewer read it as 1×.
    expect(fitScale, lessThan(1));

    // Two-finger pinch outwards around the centre.
    final centre = boardSize.center(Offset.zero);
    final f1 = await tester.startGesture(centre - const Offset(20, 0));
    final f2 = await tester.startGesture(centre + const Offset(20, 0));
    for (var i = 1; i <= 10; i++) {
      await f1.moveTo(centre - Offset(20.0 + i * 12, 0));
      await f2.moveTo(centre + Offset(20.0 + i * 12, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await f1.up();
    await f2.up();
    await tester.pumpAndSettle();
    final zoomed = tc.value.getMaxScaleOnAxis();
    expect(zoomed, greaterThan(fitScale * 1.5));

    // Drag far towards the bottom-right: the picture stays on screen, with at
    // most a small margin past its top-left corner.
    await tester.dragFrom(centre, const Offset(2000, 2000));
    await tester.pumpAndSettle();
    final shown = _screenRect(tc.value, picture);
    expect(shown.left, lessThanOrEqualTo(24.01));
    expect(shown.top, lessThanOrEqualTo(24.01));

    // Tapping a visible cell while zoomed hits that cell's arrow.
    final visible = Rect.fromLTWH(0, 0, boardSize.width, boardSize.height)
        .deflate(30);
    final target = level.arrows.firstWhere(
      (a) => visible.contains(_cellCentre(tc.value, cell, a.points.last)),
    );
    for (var attempt = 0; attempt < 4 && tapped == null; attempt++) {
      await tester.tapAt(_cellCentre(tc.value, cell, target.points.last));
      await tester.pumpAndSettle();
    }
    expect(tapped, target.id);

    // A strong pinch-in shrinks the picture below the fitted size, down to
    // the zoom-out limit, and the smaller picture stays centred.
    final g1 = await tester.startGesture(centre - const Offset(180, 0));
    final g2 = await tester.startGesture(centre + const Offset(180, 0));
    for (var i = 1; i <= 17; i++) {
      await g1.moveTo(centre - Offset(180.0 - i * 10, 0));
      await g2.moveTo(centre + Offset(180.0 - i * 10, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await g1.up();
    await g2.up();
    await tester.pumpAndSettle();
    final out = tc.value.getMaxScaleOnAxis();
    expect(out, lessThan(fitScale * 0.9));
    expect(out,
        greaterThanOrEqualTo(fitScale * ArrowBoardWidget.minZoomFraction - 1e-6));
    final small = _screenRect(tc.value, picture);
    expect(small.center.dx, closeTo(boardSize.width / 2, 0.5));
    expect(small.center.dy, closeTo(boardSize.height / 2, 0.5));
  });

  group('Screens render without overflow', () {
    for (final entry in _phones.entries) {
      for (final scale in [1.0, 1.3]) {
        final label = '${entry.key} @${scale}x text';

        testWidgets('Home – $label', (tester) async {
          _registerServices();
          await _setScreen(tester, entry.value, scale);
          await tester.pumpWidget(const GetMaterialApp(home: HomeScreen()));
          await tester.pump(const Duration(milliseconds: 300));
          expect(find.text('Level Map'), findsOneWidget);
          expect(find.textContaining('Play'), findsWidgets);
          Get.reset();
        });

        testWidgets('Gameplay + pause menu – $label', (tester) async {
          _registerServices();
          await _setScreen(tester, entry.value, scale);
          await tester.pumpWidget(GetMaterialApp(
            initialRoute: '/',
            getPages: [
              GetPage(name: '/', page: () => const SizedBox()),
              GetPage(name: '/g', page: () => const GameplayScreen()),
            ],
          ));
          Get.toNamed('/g', arguments: 2);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 500));
          expect(find.text('Level 2'), findsOneWidget);
          // The header names the picture the arrows form.
          expect(
            find.textContaining(LevelGenerator.silhouetteForLevel(2).name),
            findsOneWidget,
          );
          expect(find.text('Restart'), findsOneWidget);

          await tester.tap(find.byTooltip('Pause'));
          await tester.pump(const Duration(milliseconds: 500));
          expect(find.text('Resume'), findsOneWidget);
          Get.reset();
        });

        testWidgets('Level map – $label', (tester) async {
          _registerServices();
          await _setScreen(tester, entry.value, scale);
          await tester.pumpWidget(
            const GetMaterialApp(home: LevelSelectScreen()),
          );
          await tester.pump(const Duration(milliseconds: 800));
          expect(find.text('Level Map'), findsOneWidget);
          Get.reset();
        });

        testWidgets('Settings – $label', (tester) async {
          _registerServices();
          await _setScreen(tester, entry.value, scale);
          await tester.pumpWidget(const GetMaterialApp(home: SettingsScreen()));
          await tester.pump(const Duration(milliseconds: 300));
          expect(find.text('How to Play'), findsOneWidget);
          Get.reset();
        });

        final dialogs = <String, Widget Function()>{
          'Level complete': () => LevelCompleteDialog(
                stars: 2,
                levelNumber: 57,
                moves: 31,
                onNextLevel: () {},
                onReplay: () {},
                onHome: () {},
              ),
          'Daily complete': () => LevelCompleteDialog(
                stars: 3,
                levelNumber: 0,
                moves: 12,
                coinsEarned: 0,
                isDailyChallenge: true,
                onNextLevel: () {},
                onReplay: () {},
                onHome: () {},
              ),
          'Game over': () => GameOverDialog(
                levelNumber: 57,
                onRetry: () {},
                onHome: () {},
                onWatchAd: () async => false,
              ),
          'Tutorial': () => TutorialOverlay(onDismiss: () {}),
        };
        for (final d in dialogs.entries) {
          testWidgets('${d.key} dialog – $label', (tester) async {
            _registerServices();
            await _setScreen(tester, entry.value, scale);
            await tester.pumpWidget(
              GetMaterialApp(home: Scaffold(body: d.value())),
            );
            await tester.pump(const Duration(milliseconds: 600));
            await tester.pump(const Duration(milliseconds: 600));
            Get.reset();
          });
        }
      }
    }
  });
}

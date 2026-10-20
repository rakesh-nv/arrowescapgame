import 'package:arrowescapegame/core/constants/app_constants.dart';
import 'package:arrowescapegame/data/models/game_settings.dart';
import 'package:arrowescapegame/data/models/player_progress.dart';
import 'package:arrowescapegame/data/repositories/progress_repository.dart';
import 'package:arrowescapegame/game/config/difficulty_curve.dart';
import 'package:arrowescapegame/modules/ads/services/ad_service.dart';
import 'package:arrowescapegame/modules/level_select/level_select_controller.dart';
import 'package:arrowescapegame/modules/level_select/level_select_screen.dart';
import 'package:arrowescapegame/modules/level_select/map/level_map_layout.dart';
import 'package:arrowescapegame/modules/level_select/map/map_biome.dart';
import 'package:arrowescapegame/services/analytics_service.dart';
import 'package:arrowescapegame/services/audio_service.dart';
import 'package:arrowescapegame/services/economy_service.dart';
import 'package:arrowescapegame/services/haptic_service.dart';
import 'package:arrowescapegame/services/storage_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

class _FakeStorage extends StorageService {
  PlayerProgress _progress;
  GameSettings _settings = GameSettings();

  _FakeStorage(this._progress);

  @override
  PlayerProgress get progress => _progress;

  @override
  Future<void> saveProgress(PlayerProgress p) async => _progress = p;

  @override
  GameSettings get settings => _settings;

  @override
  Future<void> saveSettings(GameSettings s) async => _settings = s;
}

/// Progress with levels 1..[cleared] completed (3 stars) and the next one
/// unlocked.
PlayerProgress _progressThrough(int cleared, {Map<int, int>? stars}) =>
    PlayerProgress(
      highestUnlockedLevel:
          (cleared + 1).clamp(1, AppConstants.totalLevels),
      levelStars: stars ?? {for (var l = 1; l <= cleared; l++) l: 3},
      coins: 345,
      hints: 3,
      hasSeenTutorial: true,
    );

_FakeStorage _register(PlayerProgress progress) {
  Get.reset();
  final storage = _FakeStorage(progress);
  Get.put<StorageService>(storage);
  Get.put(ProgressRepository(storage));
  Get.put(EconomyService(storage));
  Get.put(HapticService());
  Get.put<IAudioService>(NoOpAudioService());
  Get.put<IAnalyticsService>(DebugAnalyticsService());
  Get.put<IAdService>(NoOpAdService());
  return storage;
}

Future<void> _setScreen(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

class _GameplayProbe extends StatelessWidget {
  static Object? lastArguments;

  const _GameplayProbe();

  @override
  Widget build(BuildContext context) {
    lastArguments = Get.arguments;
    return const Scaffold(body: Text('gameplay-probe'));
  }
}

Widget _app() => GetMaterialApp(
      initialRoute: '/',
      getPages: [
        GetPage(name: '/', page: () => const LevelSelectScreen()),
        GetPage(name: '/gameplay', page: () => const _GameplayProbe()),
      ],
    );

void main() {
  setUp(() {
    LevelSelectController.justCompletedLevel.value = 0;
    LevelSelectController.lastAnimatedLevel = 0;
    _GameplayProbe.lastArguments = null;
  });
  tearDown(Get.reset);

  group('LevelMapLayout', () {
    for (final width in [320.0, 360.0, 412.0, 800.0]) {
      test('covers every level once, bottom to top (width $width)', () {
        final layout = LevelMapLayout(
          width: width,
          totalLevels: AppConstants.totalLevels,
        );
        expect(layout.sections.first.firstLevel, 1);
        expect(layout.sections.last.lastLevel, AppConstants.totalLevels);
        for (var i = 1; i < layout.sections.length; i++) {
          expect(layout.sections[i].firstLevel,
              layout.sections[i - 1].lastLevel + 1);
          expect(layout.sections[i].bottom, layout.sections[i - 1].top);
        }

        // Items tile the map with no gaps.
        var y = 0.0;
        for (var i = 0; i < layout.itemCount; i++) {
          expect(layout.itemBottom(i), closeTo(y, 1e-6));
          y += layout.itemExtent(i);
        }
        expect(y, closeTo(layout.totalHeight, 1e-6));

        var prev = -1.0;
        for (var l = 1; l <= AppConstants.totalLevels; l++) {
          final p = layout.point(l);
          expect(p.dy, greaterThan(prev), reason: 'level $l');
          prev = p.dy;
          // Nodes stay fully on screen.
          expect(p.dx, greaterThanOrEqualTo(40));
          expect(p.dx, lessThanOrEqualTo(width - 40));
          // Each node sits inside its own world's section.
          final s = layout.sections[layout.sectionIndexFor(l)];
          expect(s.world.contains(l), isTrue);
          expect(p.dy, inExclusiveRange(s.bottom, s.top));
          // The trail passes through every node.
          expect(layout.trailXAt(p.dy), closeTo(p.dx, 0.5));
        }
      });
    }

    test('scroll offsets frame the requested level and stay in range', () {
      final layout = LevelMapLayout(
        width: 360,
        totalLevels: AppConstants.totalLevels,
      );
      const vh = 640.0;
      for (final l in [1, 2, 25, 26, 100, 199, AppConstants.totalLevels]) {
        final o = layout.scrollOffsetFor(l, vh);
        expect(o, inInclusiveRange(0, layout.maxScroll(vh)));
        final y = layout.nodeY(l);
        // The level is visible in the viewport.
        expect(y, inInclusiveRange(o, o + vh));
        expect(
          layout.sectionIndexAtOffset(o, vh),
          layout.sectionIndexFor(l),
          reason: 'level $l',
        );
      }
    });

    test('trail points interpolate between neighbouring levels', () {
      final layout = LevelMapLayout(width: 360, totalLevels: 200);
      expect(layout.trailPoint(10, 0), layout.point(10));
      expect(layout.trailPoint(10, 1), layout.point(11));
      final mid = layout.trailPoint(10, 0.5);
      expect(mid.dy, inExclusiveRange(layout.point(10).dy, layout.point(11).dy));
    });

    test('one region per world, distinct names', () {
      final names = {
        for (final w in DifficultyCurve.worlds) MapBiome.forWorld(w.number).name,
      };
      expect(names.length, DifficultyCurve.worlds.length);
      expect(MapBiome.forWorld(1).kind, BiomeKind.forest);
      expect(MapBiome.forWorld(999), MapBiome.all.last);
    });
  });

  group('LevelSelectController node states', () {
    test('follow saved progress and never unlock anything', () {
      final storage = _register(_progressThrough(
        4,
        stars: {1: 3, 2: 2, 3: 1, 4: 3},
      ));
      final c = Get.put(LevelSelectController());
      expect(c.nodeState(1), MapNodeState.completed);
      expect(c.nodeState(4), MapNodeState.completed);
      expect(c.nodeState(5), MapNodeState.current);
      expect(c.nodeState(6), MapNodeState.locked);
      expect(c.nodeState(0), MapNodeState.locked);
      expect(c.nodeState(AppConstants.totalLevels + 1), MapNodeState.locked);
      expect(c.focusLevel, 5);
      expect(storage.progress.highestUnlockedLevel, 5);
    });

    test('an unlocked gap shows as available', () {
      _register(PlayerProgress(highestUnlockedLevel: 6, levelStars: {1: 3, 2: 3}));
      final c = Get.put(LevelSelectController());
      expect(c.nodeState(3), MapNodeState.available);
      expect(c.nodeState(6), MapNodeState.current);
    });

    test('the finished last level is completed, not current', () {
      const n = AppConstants.totalLevels;
      _register(_progressThrough(n));
      final c = Get.put(LevelSelectController());
      expect(c.highestUnlocked, n);
      expect(c.nodeState(n), MapNodeState.completed);
      expect(c.isCampaignComplete, isTrue);
    });

    test('world progress and trophies', () {
      final world1 = DifficultyCurve.worlds.first;
      final perfect = _register(_progressThrough(world1.lastLevel));
      var c = Get.put(LevelSelectController());
      expect(c.worldClearedCount(world1), world1.levelCount);
      expect(c.worldStars(world1), world1.levelCount * 3);
      expect(c.worldTrophy(world1), WorldTrophy.gold);
      expect(c.isWorldUnlocked(DifficultyCurve.worlds[1]), isTrue);
      expect(c.worldTrophy(DifficultyCurve.worlds[1]), WorldTrophy.none);
      expect(perfect.progress.coins, 345);

      final stars = {for (var l = 1; l <= world1.lastLevel; l++) l: 3};
      stars[3] = 1;
      _register(_progressThrough(world1.lastLevel, stars: stars));
      c = Get.put(LevelSelectController());
      expect(c.worldTrophy(world1), WorldTrophy.bronze);

      _register(_progressThrough(world1.lastLevel - 1));
      c = Get.put(LevelSelectController());
      expect(c.worldTrophy(world1), WorldTrophy.none);
      expect(c.isWorldUnlocked(DifficultyCurve.worlds[1]), isFalse);
    });
  });

  group('LevelSelectScreen', () {
    testWidgets('opens on the current level and starts it from the sheet',
        (tester) async {
      await _setScreen(tester, const Size(360, 640));
      final storage = _register(_progressThrough(56));
      await tester.pumpWidget(_app());
      await tester.pump(const Duration(milliseconds: 500));

      // Current level is built and on screen.
      final current = find.text('57');
      expect(current, findsOneWidget);
      final pos = tester.getCenter(current);
      expect(pos.dy, inInclusiveRange(100, 560));
      expect(find.text('Level Map'), findsOneWidget);
      // Header names the region the current level belongs to.
      expect(find.textContaining(MapBiome.forWorld(3).name), findsWidgets);

      await tester.tap(current);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Level 57'), findsOneWidget);
      await tester.tap(find.text('Play'));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('gameplay-probe'), findsOneWidget);
      expect(_GameplayProbe.lastArguments, 57);

      // The map changed nothing.
      expect(storage.progress.highestUnlockedLevel, 57);
      expect(storage.progress.coins, 345);
    });

    testWidgets('locked levels explain how to unlock and do not navigate',
        (tester) async {
      await _setScreen(tester, const Size(360, 640));
      final storage = _register(_progressThrough(56));
      await tester.pumpWidget(_app());
      await tester.pump(const Duration(milliseconds: 500));

      final locked = find.text('58');
      expect(locked, findsOneWidget);
      await tester.tap(locked);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Complete level 57 to unlock it'), findsOneWidget);
      expect(find.text('Level 58'), findsNothing);
      expect(find.text('gameplay-probe'), findsNothing);
      expect(storage.progress.highestUnlockedLevel, 57);
    });

    testWidgets('world navigation scrolls between regions', (tester) async {
      await _setScreen(tester, const Size(360, 640));
      _register(_progressThrough(0));
      await tester.pumpWidget(_app());
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('1'), findsOneWidget);
      expect(find.text('${'World'} 1 · ${MapBiome.forWorld(1).name}'), findsOneWidget);

      await tester.tap(find.byTooltip('Next world'));
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('World 2 · ${MapBiome.forWorld(2).name}'), findsOneWidget);
      expect(find.text('26'), findsOneWidget);

      await tester.tap(find.byTooltip('Current level'));
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('1'), findsOneWidget);
    });

    testWidgets('plays the progression animation once and disposes cleanly',
        (tester) async {
      await _setScreen(tester, const Size(412, 915));
      _register(_progressThrough(25));
      LevelSelectController.justCompletedLevel.value = 25;
      await tester.pumpWidget(_app());
      for (var i = 0; i < 25; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(LevelSelectController.lastAnimatedLevel, 25);
      // The camera followed the marker into the next world.
      expect(find.text('26'), findsOneWidget);
      expect(find.text('World 2 · ${MapBiome.forWorld(2).name}'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Leaving the screen must stop every controller (a ticker left
      // running would fail the test).
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });

    for (final size in const [Size(320, 568), Size(360, 640), Size(800, 1280)]) {
      testWidgets('renders without overflow at ${size.width}x${size.height}',
          (tester) async {
        await _setScreen(tester, size);
        tester.platformDispatcher.textScaleFactorTestValue = 1.3;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        _register(_progressThrough(AppConstants.totalLevels));
        await tester.pumpWidget(_app());
        await tester.pump(const Duration(milliseconds: 500));
        // Finished campaign: the map frames the last level and the summit.
        expect(find.text('${AppConstants.totalLevels}'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });
}


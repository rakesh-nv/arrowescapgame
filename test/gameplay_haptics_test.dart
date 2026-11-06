import 'package:arrowescapegame/game/renderer/arrow_collision.dart';
import 'package:arrowescapegame/core/constants/app_constants.dart';
import 'package:arrowescapegame/data/models/arrow_state.dart';
import 'package:arrowescapegame/data/models/player_progress.dart';
import 'package:arrowescapegame/data/repositories/level_repository.dart';
import 'package:arrowescapegame/data/repositories/progress_repository.dart';
import 'package:arrowescapegame/game/solver/level_solver.dart';
import 'package:arrowescapegame/modules/ads/services/ad_service.dart';
import 'package:arrowescapegame/modules/gameplay/gameplay_controller.dart';
import 'package:arrowescapegame/services/analytics_service.dart';
import 'package:arrowescapegame/services/audio_service.dart';
import 'package:arrowescapegame/services/economy_service.dart';
import 'package:arrowescapegame/services/haptic_service.dart';
import 'package:arrowescapegame/services/storage_service.dart';
import 'package:flutter/services.dart';
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

  /// Haptic types sent to the platform, e.g. 'HapticFeedbackType.lightImpact'.
  final haptics = <String>[];
  late HapticService hapticService;

  setUp(() {
    Get.reset();
    haptics.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'HapticFeedback.vibrate') {
            haptics.add(call.arguments as String? ?? 'vibrate');
          }
          return null;
        });
    final storage = _FakeStorage();
    Get.put<StorageService>(storage);
    Get.put(ProgressRepository(storage));
    Get.put(EconomyService(storage));
    hapticService = Get.put(HapticService());
    Get.put<IAudioService>(NoOpAudioService());
    Get.put<IAnalyticsService>(DebugAnalyticsService());
    Get.put<IAdService>(NoOpAdService());
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
    Get.reset();
  });

  test('a valid tap ticks, the exit bumps lightly, nothing more', () async {
    final gc = Get.put(GameplayController());
    await gc.loadLevel(30);
    final level = LevelRepository.getLevel(30);
    final free = LevelSolver.getAvailableArrows(level.arrows, level.gridSize);

    gc.onArrowTap(free.first.id);
    expect(haptics, ['HapticFeedbackType.selectionClick']);

    await _escapeWait();
    expect(
      gc.arrows.firstWhere((a) => a.id == free.first.id).state,
      ArrowState.removed,
    );
    expect(haptics, [
      'HapticFeedbackType.selectionClick',
      'HapticFeedbackType.lightImpact',
    ]);
  });

  test(
    'a blocked tap gives one distinct medium bump and costs a life',
    () async {
      final gc = Get.put(GameplayController());
      await gc.loadLevel(30);
      final level = LevelRepository.getLevel(30);
      final free = {
        for (final a in LevelSolver.getAvailableArrows(
          level.arrows,
          level.gridSize,
        ))
          a.id,
      };
      final blocked = level.arrows.firstWhere((a) => !free.contains(a.id));

      gc.onArrowTap(blocked.id);
      // The life is spent at once; the bump lands when the arrow, having
      // travelled up to the obstacle, touches it.
      expect(gc.lives.value, AppConstants.startingLives - 1);
      expect(haptics, isEmpty);
      await Future.delayed(
        const Duration(milliseconds: CrashTiming.maxTotalMs + 60),
      );
      expect(haptics, ['HapticFeedbackType.mediumImpact']);
      expect(
        gc.arrows.firstWhere((a) => a.id == blocked.id).state,
        isNot(ArrowState.removed),
      );
    },
  );

  test(
    'haptics switched off in settings: silent, gameplay unchanged',
    () async {
      hapticService.setEnabled(false);
      final gc = Get.put(GameplayController());
      await gc.loadLevel(30);
      final level = LevelRepository.getLevel(30);
      final free = LevelSolver.getAvailableArrows(level.arrows, level.gridSize);
      gc.onArrowTap(free.first.id);
      await _escapeWait();
      expect(haptics, isEmpty);
      expect(
        gc.arrows.firstWhere((a) => a.id == free.first.id).state,
        ArrowState.removed,
      );
    },
  );

  test('a device without a vibrator never breaks a move', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'HapticFeedback.vibrate') {
            throw PlatformException(code: 'no_vibrator');
          }
          return null;
        });
    final gc = Get.put(GameplayController());
    await gc.loadLevel(30);
    final level = LevelRepository.getLevel(30);
    final free = LevelSolver.getAvailableArrows(level.arrows, level.gridSize);
    gc.onArrowTap(free.first.id);
    await _escapeWait();
    expect(
      gc.arrows.firstWhere((a) => a.id == free.first.id).state,
      ArrowState.removed,
    );
  });

  test('clearing the board ends with only the win buzz', () async {
    final gc = Get.put(GameplayController());
    await gc.loadLevel(1);
    final level = LevelRepository.getLevel(1);
    final order = LevelSolver.solve(level.arrows, level.gridSize).solution;
    for (final id in order) {
      gc.onArrowTap(id);
      await Future.delayed(
        Duration(
          milliseconds:
              AppConstants.arrowEscapeDurationForLength(
                level.arrows.firstWhere((a) => a.id == id).length,
              ) +
              30,
        ),
      );
    }
    expect(gc.isCompleting.value, isTrue);
    expect(haptics.last, 'HapticFeedbackType.heavyImpact');
    // The last arrow's exit does not add a light bump before the win buzz.
    expect(haptics[haptics.length - 2], 'HapticFeedbackType.selectionClick');
    expect(
      haptics.where((h) => h == 'HapticFeedbackType.mediumImpact'),
      isEmpty,
    );
  }, timeout: const Timeout(Duration(minutes: 2)));
}

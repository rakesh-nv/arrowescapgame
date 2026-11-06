import 'package:arrowescapegame/data/models/player_progress.dart';
import 'package:arrowescapegame/data/repositories/level_repository.dart';
import 'package:arrowescapegame/data/repositories/progress_repository.dart';
import 'package:arrowescapegame/modules/ads/services/ad_service.dart';
import 'package:arrowescapegame/modules/gameplay/gameplay_controller.dart';
import 'package:arrowescapegame/modules/gameplay/gameplay_screen.dart';
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

/// Rewarded hint ad that is either watched to the end or unavailable.
class _HintAds extends NoOpAdService {
  _HintAds({required this.watched});
  final bool watched;
  int shown = 0;

  @override
  Future<bool> showRewardedHint() async {
    shown++;
    return watched;
  }
}

void main() {
  setUpAll(() => LevelRepository.getLevel(2));

  Future<(GameplayController, EconomyService)> openLevel(
    WidgetTester tester,
    IAdService ads,
  ) async {
    Get.reset();
    final storage = _FakeStorage();
    Get.put<StorageService>(storage);
    Get.put(ProgressRepository(storage));
    final economy = Get.put(EconomyService(storage));
    Get.put(HapticService());
    Get.put<IAudioService>(NoOpAudioService());
    Get.put<IAnalyticsService>(DebugAnalyticsService());
    Get.put<IAdService>(ads);
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      GetMaterialApp(
        initialRoute: '/',
        getPages: [
          GetPage(name: '/', page: () => const SizedBox()),
          GetPage(name: '/g', page: () => const GameplayScreen()),
        ],
      ),
    );
    Get.toNamed('/g', arguments: 2);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    // Out of hints: the button offers a free hint for an ad.
    economy.hints.value = 0;
    await tester.pump();
    expect(find.text('Free Hint'), findsOneWidget);
    return (Get.find<GameplayController>(), economy);
  }

  testWidgets('Free Hint plays the ad at once and uses the hint it earns', (
    tester,
  ) async {
    final ads = _HintAds(watched: true);
    final (gc, economy) = await openLevel(tester, ads);

    await tester.tap(find.text('Free Hint'));
    await tester.pump();

    expect(ads.shown, 1);
    // No "need a hint?" dialog in between.
    expect(find.byType(Dialog), findsNothing);
    expect(find.text('Use Hint Now'), findsNothing);
    // The earned hint was used straight away: an arrow is highlighted.
    expect(gc.hintedArrowId.value, isNotEmpty);
    expect(economy.hints.value, 0);

    await tester.pump(const Duration(seconds: 3));
    Get.reset();
  });

  testWidgets('no ad available: a short message, no hint, no dialog', (
    tester,
  ) async {
    final ads = _HintAds(watched: false);
    final (gc, economy) = await openLevel(tester, ads);

    await tester.tap(find.text('Free Hint'));
    await tester.pump();

    expect(ads.shown, 1);
    expect(find.byType(Dialog), findsNothing);
    expect(find.textContaining('Unable to load video ad'), findsOneWidget);
    expect(gc.hintedArrowId.value, isEmpty);
    expect(economy.hints.value, 0);

    await tester.pump(const Duration(seconds: 3));
    Get.reset();
  });
}

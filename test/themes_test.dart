import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:arrowescapegame/core/constants/app_constants.dart';
import 'package:arrowescapegame/core/utils/format.dart';
import 'package:arrowescapegame/data/models/player_progress.dart';
import 'package:arrowescapegame/data/models/theme_model.dart';
import 'package:arrowescapegame/data/repositories/progress_repository.dart';
import 'package:arrowescapegame/data/repositories/theme_repository.dart';
import 'package:arrowescapegame/modules/themes/themes_controller.dart';
import 'package:arrowescapegame/modules/themes/themes_screen.dart';
import 'package:arrowescapegame/services/analytics_service.dart';
import 'package:arrowescapegame/services/economy_service.dart';
import 'package:arrowescapegame/services/storage_service.dart';

class _FakeStorage extends StorageService {
  PlayerProgress current;
  int saves = 0;

  _FakeStorage(this.current);

  @override
  PlayerProgress get progress => current;

  @override
  Future<void> saveProgress(PlayerProgress p) async {
    saves++;
    current = p;
  }
}

class _FakeAnalytics implements IAnalyticsService {
  final events = <String>[];

  @override
  void logEvent(String name, {Map<String, dynamic>? params}) =>
      events.add(name);
}

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

ThemeModel _theme(String id) => ThemeRepository.getById(id);

const _originalIds = {'classic', 'ocean', 'forest', 'sunset', 'night'};

void main() {
  themesScreenTests();

  group('Theme catalogue and pricing', () {
    const tierPrices = {0, 2000, 3000, 5000, 8000, 10000};

    test('keeps every original theme id', () {
      for (final id in ['classic', 'ocean', 'forest', 'sunset', 'night']) {
        expect(ThemeRepository.exists(id), isTrue, reason: id);
      }
    });

    test('has many themes with unique ids and known categories', () {
      final ids = ThemeRepository.allThemes.map((t) => t.id).toList();
      expect(ids.length, greaterThanOrEqualTo(35));
      expect(ids.toSet().length, ids.length);
      for (final t in ThemeRepository.allThemes) {
        expect(ThemeRepository.categories, contains(t.category), reason: t.id);
        expect(t.backgroundGradient.length, greaterThanOrEqualTo(2));
      }
    });

    test('default theme is free; no paid theme is under 2,000 coins', () {
      expect(_theme(ThemeRepository.defaultThemeId).isFree, isTrue);
      for (final t in ThemeRepository.allThemes) {
        expect(tierPrices, contains(t.coinsRequired), reason: t.id);
        if (!t.isFree) {
          expect(t.coinsRequired, greaterThanOrEqualTo(2000), reason: t.id);
        }
      }
    });

    test('only the two historically free themes stay free', () {
      final free =
          ThemeRepository.allThemes.where((t) => t.isFree).map((t) => t.id);
      expect(free.toSet(), {'classic', 'ocean'});
    });

    test('every paid tier is used', () {
      final used = ThemeRepository.allThemes.map((t) => t.tier).toSet();
      expect(used, containsAll(ThemeTier.values));
      expect(ThemeTier.entry.price, AppConstants.themePriceEntry);
      expect(ThemeTier.rare.price, 10000);
    });

    test('arrows, heads and text stay readable on every background', () {
      final failures = <String>[];
      void check(String what, Color fg, Color bg, double min) {
        final ratio = _contrast(fg, bg);
        if (ratio < min) {
          failures.add('$what ${ratio.toStringAsFixed(2)} < $min');
        }
      }

      for (final t in ThemeRepository.allThemes) {
        final bodies = t.arrowPalette ?? [t.arrowColor];
        for (final bg in t.backgroundGradient) {
          for (final body in bodies) {
            check('${t.id} arrow', body, bg, 3.0);
            check('${t.id} head', t.headColorFor(body), bg, 3.0);
          }
          check('${t.id} text', t.textColor, bg, 4.5);
          // The original five keep their look; new themes need a visible
          // accent (escaping arrows, hint glow, HUD progress).
          if (!_originalIds.contains(t.id)) {
            check('${t.id} accent', t.accentColor, bg, 2.5);
          }
        }
      }
      expect(failures, isEmpty, reason: failures.join('\n'));
    });

    test('palette colour is stable per arrow id', () {
      final rainbow = _theme('rainbow');
      expect(rainbow.arrowColorFor('a007'), rainbow.arrowColorFor('a007'));
      final colours = {
        for (var i = 1; i <= 30; i++)
          rainbow.arrowColorFor('a${i.toString().padLeft(3, '0')}'),
      };
      expect(colours.length, greaterThan(1));
      // Single-colour themes ignore the id.
      expect(_theme('classic').arrowColorFor('a001'),
          _theme('classic').arrowColor);
    });

    test('formatThousands', () {
      expect(formatThousands(0), '0');
      expect(formatThousands(999), '999');
      expect(formatThousands(2000), '2,000');
      expect(formatThousands(10000), '10,000');
      expect(formatThousands(1234567), '1,234,567');
    });
  });

  group('ThemesController purchases', () {
    late _FakeStorage storage;
    late EconomyService economy;
    late _FakeAnalytics analytics;

    ThemesController makeController() {
      Get.delete<ThemesController>(force: true);
      return Get.put(ThemesController());
    }

    void setUpWith(PlayerProgress progress) {
      Get.reset();
      storage = _FakeStorage(progress);
      economy = EconomyService(storage)..onInit();
      analytics = _FakeAnalytics();
      Get.put<ProgressRepository>(ProgressRepository(storage));
      Get.put<EconomyService>(economy);
      Get.put<IAnalyticsService>(analytics);
    }

    tearDown(Get.reset);

    test('unlock deducts the exact price once and applies the theme',
        () async {
      setUpWith(PlayerProgress(coins: 2500));
      final c = makeController();
      final theme = _theme('jungle');

      expect(await c.unlockTheme(theme), ThemeUnlockResult.unlocked);
      expect(economy.coins.value, 500);
      expect(storage.current.coins, 500);
      expect(storage.current.unlockedThemes, contains('jungle'));
      expect(storage.current.currentThemeId, 'jungle');
      expect(c.activeThemeId.value, 'jungle');
      expect(analytics.events, [AnalyticsEvent.themeUnlocked]);
    });

    test('buying an owned theme again never charges', () async {
      setUpWith(PlayerProgress(coins: 9000));
      final c = makeController();
      final theme = _theme('fire');

      expect(await c.unlockTheme(theme), ThemeUnlockResult.unlocked);
      expect(economy.coins.value, 4000);
      expect(await c.unlockTheme(theme), ThemeUnlockResult.alreadyOwned);
      expect(economy.coins.value, 4000);
      expect(
        storage.current.unlockedThemes.where((id) => id == 'fire').length,
        1,
      );
    });

    test('double tap while a purchase is running charges once', () async {
      setUpWith(PlayerProgress(coins: 20000));
      final c = makeController();
      final theme = _theme('golden_luxury');

      final results = await Future.wait([
        c.unlockTheme(theme),
        c.unlockTheme(theme),
      ]);
      expect(results, contains(ThemeUnlockResult.unlocked));
      expect(
        results.where((r) => r == ThemeUnlockResult.unlocked).length,
        1,
      );
      expect(economy.coins.value, 10000);
    });

    test('insufficient balance changes nothing', () async {
      setUpWith(PlayerProgress(coins: 1999));
      final c = makeController();
      final theme = _theme('deep_ocean');

      expect(c.coinsShort(theme), 1);
      expect(await c.unlockTheme(theme),
          ThemeUnlockResult.insufficientCoins);
      expect(economy.coins.value, 1999);
      expect(storage.current.unlockedThemes, isNot(contains('deep_ocean')));
      expect(c.activeThemeId.value, 'classic');
    });

    test('selectTheme refuses a locked theme', () async {
      setUpWith(PlayerProgress(coins: 0));
      final c = makeController();
      expect(await c.selectTheme(_theme('neon_glow')), isFalse);
      expect(storage.current.currentThemeId, 'classic');
      expect(storage.current.unlockedThemes, isNot(contains('neon_glow')));
    });

    test('unlocks and selection persist into a new session', () async {
      setUpWith(PlayerProgress(coins: 6000));
      var c = makeController();
      await c.unlockTheme(_theme('nebula'));
      await c.selectTheme(_theme('ocean'));

      c = makeController();
      expect(c.activeThemeId.value, 'ocean');
      expect(c.isUnlocked(_theme('nebula')), isTrue);
      expect(c.isUnlocked(_theme('galaxy')), isFalse);
      expect(economy.coins.value, 1000);
    });

    test('older saves keep their themes and coins after the reprice',
        () async {
      // A player who bought Forest for 100 coins and is using Sunset.
      setUpWith(PlayerProgress(
        coins: 150,
        currentThemeId: 'sunset',
        unlockedThemes: ['classic', 'ocean', 'forest'],
      ));
      final c = makeController();
      expect(c.isUnlocked(_theme('forest')), isTrue);
      expect(c.isUnlocked(_theme('sunset')), isTrue);
      expect(c.isUnlocked(_theme('night')), isFalse);
      expect(economy.coins.value, 150);
      expect(await c.unlockTheme(_theme('forest')),
          ThemeUnlockResult.alreadyOwned);
      expect(economy.coins.value, 150);
    });

    test('an unknown stored theme id falls back to the default', () {
      setUpWith(PlayerProgress(currentThemeId: 'removed_theme'));
      final c = makeController();
      expect(c.activeThemeId.value, ThemeRepository.defaultThemeId);
      expect(ThemeRepository.getById('removed_theme').id, 'classic');
    });
  });
}

void _registerForScreen(int coins) {
  Get.reset();
  final storage = _FakeStorage(PlayerProgress(coins: coins));
  Get.put<StorageService>(storage);
  Get.put(ProgressRepository(storage));
  Get.put(EconomyService(storage)..onInit());
  Get.put<IAnalyticsService>(_FakeAnalytics());
}

Future<void> _pumpThemes(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const GetMaterialApp(home: ThemesScreen()));
  await tester.pumpAndSettle();
}

void themesScreenTests() {
  group('ThemesScreen', () {
    tearDown(Get.reset);

    for (final size in const [Size(320, 568), Size(412, 915), Size(800, 1280)]) {
      testWidgets('lays out without overflow at ${size.width}x${size.height}',
          (tester) async {
        _registerForScreen(100);
        await _pumpThemes(tester, size);
        expect(tester.takeException(), isNull);
        expect(find.text('Classic'), findsWidgets);
        expect(find.text('In use'), findsOneWidget);
        // Scroll through every category.
        await tester.drag(find.byType(CustomScrollView), const Offset(0, -6000));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('confirm dialog unlocks once and shows success',
        (tester) async {
      _registerForScreen(2500);
      await _pumpThemes(tester, const Size(412, 915));
      final economy = Get.find<EconomyService>();

      await tester.scrollUntilVisible(
        find.text('Deep Forest'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.text('Deep Forest'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Deep Forest'));
      await tester.pumpAndSettle();
      expect(find.text('Unlock Deep Forest?'), findsOneWidget);
      expect(economy.coins.value, 2500, reason: 'nothing taken before confirm');

      await tester.tap(find.text('Unlock for 2,000'));
      await tester.pumpAndSettle();
      expect(economy.coins.value, 500);
      expect(find.text('Deep Forest unlocked and applied!'), findsOneWidget);
      expect(Get.find<ThemesController>().activeThemeId.value, 'deep_forest');
    });

    testWidgets('unaffordable theme cannot be bought', (tester) async {
      _registerForScreen(100);
      await _pumpThemes(tester, const Size(412, 915));
      await tester.scrollUntilVisible(
        find.text('Deep Forest'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.text('Deep Forest'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Deep Forest'));
      await tester.pumpAndSettle();
      expect(find.text('Not enough coins'), findsOneWidget);
      await tester.tap(find.text('Not enough coins'));
      await tester.pumpAndSettle();
      expect(Get.find<EconomyService>().coins.value, 100);
    });
  });
}

import 'package:get/get.dart';
import '../modules/splash/splash_screen.dart';
import '../modules/home/home_screen.dart';
import '../modules/level_select/level_select_screen.dart';
import '../modules/gameplay/gameplay_screen.dart';
import '../modules/daily_challenge/daily_challenge_screen.dart';
import '../modules/themes/themes_screen.dart';
import '../modules/settings/settings_screen.dart';

abstract class AppRoutes {
  static const splash = '/';
  static const home = '/home';
  static const levelSelect = '/level-select';
  static const gameplay = '/gameplay';
  static const dailyChallenge = '/daily-challenge';
  static const themes = '/themes';
  static const settings = '/settings';
}

class AppPages {
  AppPages._();

  static const initial = AppRoutes.splash;

  static final routes = [
    GetPage(
      name: AppRoutes.splash,
      page: () => const SplashScreen(),
      transition: Transition.fade,
    ),
    GetPage(
      name: AppRoutes.home,
      page: () => const HomeScreen(),
      transition: Transition.fadeIn,
    ),
    GetPage(
      name: AppRoutes.levelSelect,
      page: () => const LevelSelectScreen(),
      transition: Transition.rightToLeftWithFade,
    ),
    GetPage(
      name: AppRoutes.gameplay,
      page: () => const GameplayScreen(),
      transition: Transition.rightToLeftWithFade,
    ),
    GetPage(
      name: AppRoutes.dailyChallenge,
      page: () => const DailyChallengeScreen(),
      transition: Transition.rightToLeftWithFade,
    ),
    GetPage(
      name: AppRoutes.themes,
      page: () => const ThemesScreen(),
      transition: Transition.rightToLeftWithFade,
    ),
    GetPage(
      name: AppRoutes.settings,
      page: () => const SettingsScreen(),
      transition: Transition.rightToLeftWithFade,
    ),
  ];
}

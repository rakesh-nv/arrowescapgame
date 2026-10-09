import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../../data/models/difficulty.dart';

/// Spacing scale used for padding and gaps across the app.
class AppSpacing {
  AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;

  /// Horizontal page margin.
  static const double page = 20;
}

/// Corner radii.
class AppRadii {
  AppRadii._();

  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 28;
  static const double pill = 999;
}

/// Animation durations. Gameplay-facing motion stays short so it never gets
/// in the way of the next tap.
class AppDurations {
  AppDurations._();

  static const Duration press = Duration(milliseconds: 110);
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration base = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 400);
}

/// Minimum interactive size (Material accessibility guideline).
const double kMinTouchTarget = 48;

class AppShadows {
  AppShadows._();

  static List<BoxShadow> get soft => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.06),
          blurRadius: 12,
          offset: const Offset(0, 3),
        ),
      ];

  static List<BoxShadow> get raised => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.16),
          blurRadius: 30,
          offset: const Offset(0, 10),
        ),
      ];

  static List<BoxShadow> glow(Color color) => [
        BoxShadow(
          color: color.withValues(alpha: 0.32),
          blurRadius: 14,
          offset: const Offset(0, 4),
        ),
      ];
}

class AppGradients {
  AppGradients._();

  static const LinearGradient background = LinearGradient(
    colors: [AppColors.backgroundLight, AppColors.backgroundLight2],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient primary = AppColors.primaryGradient;

  static const LinearGradient daily = LinearGradient(
    colors: [AppColors.dailyPurple, AppColors.dailyIndigo],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient gold = LinearGradient(
    colors: [Color(0xFFFBBF24), AppColors.coinGold],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient reward = LinearGradient(
    colors: [AppColors.coinGold, AppColors.coinGoldDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

/// Text styles. Sizes follow a small, consistent scale.
class AppTextStyles {
  AppTextStyles._();

  static const TextStyle display = TextStyle(
    fontSize: 40,
    fontWeight: FontWeight.w800,
    color: AppColors.textPrimary,
    letterSpacing: 4,
    height: 1,
  );

  static const TextStyle title = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w800,
    color: AppColors.textPrimary,
    letterSpacing: -0.3,
  );

  static const TextStyle heading = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  static const TextStyle label = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  static const TextStyle body = TextStyle(
    fontSize: 14,
    color: AppColors.textSecondary,
    height: 1.4,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: AppColors.textSecondary,
  );

  static const TextStyle button = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.4,
  );
}

/// Colour for a difficulty label (badges, world headers, map banners).
Color difficultyColor(Difficulty difficulty) => switch (difficulty) {
      Difficulty.easy => AppColors.diffEasy,
      Difficulty.normal => AppColors.diffNormal,
      Difficulty.hard => AppColors.diffHard,
      Difficulty.expert => AppColors.diffExpert,
      Difficulty.extreme => AppColors.diffExtreme,
    };

import 'package:flutter/material.dart';
import '../../data/models/theme_model.dart';
import '../../core/constants/app_colors.dart';

class ThemeRepository {
  ThemeRepository._();

  static const List<ThemeModel> allThemes = [
    ThemeModel(
      id: 'classic',
      name: 'Classic',
      backgroundColor: AppColors.backgroundLight,
      surfaceColor: AppColors.surface,
      arrowColor: AppColors.navyDark,
      accentColor: AppColors.accentBlue,
      textColor: AppColors.navyDark,
      particleColor: AppColors.accentBlue,
      isDark: false,
      coinsRequired: 0,
      backgroundGradient: [Color(0xFFF5F7FF), Color(0xFFEEF2FF)],
    ),
    ThemeModel(
      id: 'ocean',
      name: 'Ocean',
      backgroundColor: AppColors.oceanBg,
      surfaceColor: AppColors.oceanSurface,
      arrowColor: AppColors.oceanArrow,
      accentColor: AppColors.oceanAccent,
      textColor: Colors.white,
      particleColor: AppColors.oceanArrow,
      isDark: true,
      coinsRequired: 0,
      backgroundGradient: [Color(0xFF0F2A3F), Color(0xFF0A1F30)],
    ),
    ThemeModel(
      id: 'forest',
      name: 'Forest',
      backgroundColor: AppColors.forestBg,
      surfaceColor: AppColors.forestSurface,
      arrowColor: AppColors.forestArrow,
      accentColor: AppColors.forestAccent,
      textColor: Colors.white,
      particleColor: AppColors.forestArrow,
      isDark: true,
      coinsRequired: 100,
      backgroundGradient: [Color(0xFF0D2B1A), Color(0xFF091A10)],
    ),
    ThemeModel(
      id: 'sunset',
      name: 'Sunset',
      backgroundColor: AppColors.sunsetBg,
      surfaceColor: AppColors.sunsetSurface,
      arrowColor: AppColors.sunsetArrow,
      accentColor: AppColors.sunsetAccent,
      textColor: AppColors.navyDark,
      particleColor: AppColors.sunsetAccent,
      isDark: false,
      coinsRequired: 150,
      backgroundGradient: [Color(0xFFFFF7ED), Color(0xFFFFEDD8)],
    ),
    ThemeModel(
      id: 'night',
      name: 'Night',
      backgroundColor: AppColors.nightBg,
      surfaceColor: AppColors.nightSurface,
      arrowColor: AppColors.nightArrow,
      accentColor: AppColors.nightAccent,
      textColor: Colors.white,
      particleColor: AppColors.nightArrow,
      isDark: true,
      coinsRequired: 200,
      backgroundGradient: [Color(0xFF0A0E1A), Color(0xFF060811)],
    ),
  ];

  static ThemeModel getById(String id) {
    return allThemes.firstWhere(
      (t) => t.id == id,
      orElse: () => allThemes.first,
    );
  }
}

import 'package:flutter/material.dart';

/// A visual theme for the game board and UI
class ThemeModel {
  final String id;
  final String name;
  final Color backgroundColor;
  final Color surfaceColor;
  final Color arrowColor;
  final Color accentColor;
  final Color textColor;
  final Color particleColor;
  final bool isDark;
  final int coinsRequired; // 0 = free
  final List<Color> backgroundGradient;

  const ThemeModel({
    required this.id,
    required this.name,
    required this.backgroundColor,
    required this.surfaceColor,
    required this.arrowColor,
    required this.accentColor,
    required this.textColor,
    required this.particleColor,
    required this.isDark,
    this.coinsRequired = 0,
    required this.backgroundGradient,
  });

  bool get isFree => coinsRequired == 0;
}

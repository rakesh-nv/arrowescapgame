import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import '../data/models/difficulty.dart';

/// Pill badge showing difficulty level
class DifficultyBadge extends StatelessWidget {
  final Difficulty difficulty;

  const DifficultyBadge({super.key, required this.difficulty});

  Color get _color {
    switch (difficulty) {
      case Difficulty.easy:
        return AppColors.diffEasy;
      case Difficulty.normal:
        return AppColors.diffNormal;
      case Difficulty.hard:
        return AppColors.diffHard;
      case Difficulty.expert:
        return AppColors.diffExpert;
      case Difficulty.extreme:
        return AppColors.diffExtreme;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _color.withOpacity(0.3)),
      ),
      child: Text(
        difficulty.displayName,
        style: TextStyle(
          color: _color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

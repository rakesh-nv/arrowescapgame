import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';

/// Displays heart/life indicators (up to 3)
class HeartDisplay extends StatelessWidget {
  final int lives;
  final int maxLives;

  const HeartDisplay({
    super.key,
    required this.lives,
    this.maxLives = 3,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(maxLives, (i) {
        final filled = i < lives;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Icon(
              filled ? Icons.favorite_rounded : Icons.favorite_outline_rounded,
              color: filled
                  ? AppColors.heartFull
                  : AppColors.heartEmpty,
              size: 26,
              key: ValueKey('heart_${i}_$filled'),
            ),
          ),
        );
      }),
    );
  }
}

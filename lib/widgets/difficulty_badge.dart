import 'package:flutter/material.dart';
import '../core/theme/design_tokens.dart';
import '../data/models/difficulty.dart';

/// Pill badge showing difficulty level
class DifficultyBadge extends StatelessWidget {
  final Difficulty difficulty;
  final bool onDark;

  const DifficultyBadge({
    super.key,
    required this.difficulty,
    this.onDark = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = difficultyColor(difficulty);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: onDark ? 0.25 : 0.12),
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        difficulty.displayName,
        style: TextStyle(
          color: onDark ? Colors.white : color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

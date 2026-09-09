import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';

/// Level card for the level selection grid
class LevelCard extends StatelessWidget {
  final int levelNumber;
  final int stars; // 0 = not completed
  final bool isUnlocked;
  final bool isCurrent;
  final VoidCallback onTap;

  const LevelCard({
    super.key,
    required this.levelNumber,
    required this.stars,
    required this.isUnlocked,
    required this.isCurrent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isUnlocked ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isCurrent
              ? AppColors.accentBlue
              : isUnlocked
                  ? AppColors.surface
                  : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isCurrent
                ? AppColors.accentBlue
                : isUnlocked
                    ? AppColors.cardBorder
                    : Colors.transparent,
            width: isCurrent ? 2 : 1,
          ),
          boxShadow: isCurrent || stars > 0
              ? [
                  BoxShadow(
                    color: isCurrent
                        ? AppColors.accentBlue.withOpacity(0.25)
                        : Colors.black.withOpacity(0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (!isUnlocked)
              Icon(Icons.lock_rounded,
                  color: Colors.grey.shade400, size: 20)
            else
              Text(
                levelNumber.toString(),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: isCurrent ? Colors.white : AppColors.textPrimary,
                ),
              ),
            if (isUnlocked && stars > 0) ...[
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(3, (i) {
                  return Icon(
                    i < stars ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: i < stars
                        ? AppColors.starGold
                        : isCurrent
                            ? Colors.white30
                            : AppColors.starEmpty,
                    size: 12,
                  );
                }),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

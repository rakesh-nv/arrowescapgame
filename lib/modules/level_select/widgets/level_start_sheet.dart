import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../game/config/difficulty_curve.dart';
import '../../../widgets/difficulty_badge.dart';
import '../../../widgets/primary_button.dart';
import '../level_select_controller.dart';
import '../map/map_biome.dart';

/// Bottom sheet shown when an unlocked level is tapped: where it is, how
/// hard it is, the best result so far, and a Play button.
class LevelStartSheet extends StatelessWidget {
  final int level;
  final MapNodeState state;
  final int stars;
  final bool isBoss;
  final bool isChallenge;
  final VoidCallback onPlay;

  const LevelStartSheet({
    super.key,
    required this.level,
    required this.state,
    required this.stars,
    required this.isBoss,
    required this.isChallenge,
    required this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    final world = DifficultyCurve.worldFor(level);
    final biome = MapBiome.forWorld(world.number);
    final completed = state == MapNodeState.completed;
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadii.xl),
          boxShadow: AppShadows.raised,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.cardBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: biome.accent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${AppStrings.world} ${world.number} · ${biome.name}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption,
                  ),
                ),
                DifficultyBadge(difficulty: world.difficulty),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Text('${AppStrings.level} $level', style: AppTextStyles.title),
                if (isBoss || isChallenge) ...[
                  const SizedBox(width: 8),
                  Icon(
                    isBoss
                        ? Icons.workspace_premium_rounded
                        : Icons.bolt_rounded,
                    color: isBoss ? AppColors.coinGold : AppColors.accentPurple,
                  ),
                ],
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                for (var i = 0; i < 3; i++)
                  Icon(
                    Icons.star_rounded,
                    size: 28,
                    color: i < stars ? AppColors.starGold : AppColors.starEmpty,
                  ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    completed
                        ? '${AppStrings.bestScore}: $stars/3'
                        : state == MapNodeState.current
                        ? AppStrings.newLevel
                        : AppStrings.notCompletedYet,
                    style: AppTextStyles.body,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            PrimaryButton(
              label: completed ? AppStrings.replay : AppStrings.play,
              icon: completed ? Icons.replay_rounded : Icons.play_arrow_rounded,
              width: double.infinity,
              gradient: AppGradients.primary,
              onTap: onPlay,
            ),
          ],
        ),
      ),
    );
  }
}

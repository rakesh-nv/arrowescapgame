import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../game/config/difficulty_curve.dart';
import '../map/map_biome.dart';

/// Ribbon shown at each world's gate: region name, world title, difficulty
/// and the player's progress in that world (or what unlocks it).
class WorldBannerWidget extends StatelessWidget {
  final CampaignWorld world;
  final MapBiome biome;
  final bool unlocked;
  final int cleared;
  final int levelCount;
  final int stars;

  const WorldBannerWidget({
    super.key,
    required this.world,
    required this.biome,
    required this.unlocked,
    required this.cleared,
    required this.levelCount,
    required this.stars,
  });

  @override
  Widget build(BuildContext context) {
    final accent = biome.accent;
    final diff = difficultyColor(world.difficulty);
    return Semantics(
      container: true,
      label: '${AppStrings.world} ${world.number}, ${biome.name}',
      child: Container(
        constraints: const BoxConstraints(maxWidth: 300),
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(AppRadii.lg),
          border: Border.all(color: accent.withValues(alpha: 0.55), width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                  ),
                  child: Text(
                    '${AppStrings.world} ${world.number}'.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    biome.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: AppColors.navyDark,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              '${world.name} · ${world.difficulty.displayName}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: diff,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 6),
            if (unlocked)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: SizedBox(
                      width: 110,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: levelCount == 0 ? 0 : cleared / levelCount,
                          minHeight: 6,
                          backgroundColor: accent.withValues(alpha: 0.15),
                          valueColor: AlwaysStoppedAnimation(accent),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$cleared/$levelCount',
                    style: AppTextStyles.caption.copyWith(fontSize: 11),
                  ),
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.star_rounded,
                    size: 13,
                    color: AppColors.starGold,
                  ),
                  Text(
                    '$stars/${levelCount * 3}',
                    style: AppTextStyles.caption.copyWith(fontSize: 11),
                  ),
                ],
              )
            else
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.lock_rounded,
                    size: 13,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      '${AppStrings.clearLevelToEnter} ${world.firstLevel - 1} '
                      '${AppStrings.toEnter}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption.copyWith(fontSize: 11),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

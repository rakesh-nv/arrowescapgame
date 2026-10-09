import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/theme/design_tokens.dart';
import '../../ads/ads_module.dart';
import '../../../services/economy_service.dart';
import '../../../widgets/game_dialog.dart';
import '../../../widgets/pressable_scale.dart';
import '../../../widgets/primary_button.dart';
import '../../../widgets/secondary_button.dart';

class LevelCompleteDialog extends StatefulWidget {
  final int stars;
  final int levelNumber;
  final int moves;

  /// Coins paid for this win. Defaults to the campaign reward for [stars].
  final int? coinsEarned;

  /// A daily win: no level number, and the primary button returns to the
  /// daily screen instead of opening the next level.
  final bool isDailyChallenge;
  final VoidCallback onNextLevel;
  final VoidCallback onReplay;
  final VoidCallback onHome;

  const LevelCompleteDialog({
    super.key,
    required this.stars,
    required this.levelNumber,
    required this.moves,
    this.coinsEarned,
    this.isDailyChallenge = false,
    required this.onNextLevel,
    required this.onReplay,
    required this.onHome,
  });

  @override
  State<LevelCompleteDialog> createState() => _LevelCompleteDialogState();
}

class _LevelCompleteDialogState extends State<LevelCompleteDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _starsController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  late final List<Animation<double>> _starAnims = [
    for (var i = 0; i < 3; i++)
      CurvedAnimation(
        parent: _starsController,
        curve: Interval(i * 0.25, 0.5 + i * 0.2, curve: Curves.elasticOut),
      ),
  ];
  bool _hasDoubledCoins = false;
  bool _isLoadingAd = false;

  int get _baseCoins =>
      widget.coinsEarned ?? 25 + (widget.stars == 3 ? 10 : 0);

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 250), () {
      if (mounted) _starsController.forward();
    });
  }

  @override
  void dispose() {
    _starsController.dispose();
    super.dispose();
  }

  Future<void> _doubleCoins() async {
    setState(() => _isLoadingAd = true);
    final baseCoins = _baseCoins;
    final adService = Get.find<IAdService>();
    final economy = Get.find<EconomyService>();
    final rewarded = await adService.showRewardedCoins();
    if (mounted) {
      setState(() {
        _isLoadingAd = false;
        if (rewarded) {
          _hasDoubledCoins = true;
          economy.addCoins(baseCoins);
        }
      });
    }
  }

  String get _starMessage => switch (widget.stars) {
        3 => 'Flawless — no mistakes!',
        2 => 'Great job! Try again with no mistakes for 3 stars.',
        _ => 'Cleared! Fewer mistakes earn more stars.',
      };

  @override
  Widget build(BuildContext context) {
    return GameDialog(
      icon: const DialogIcon(
        icon: Icons.emoji_events_rounded,
        color: AppColors.coinGold,
        gradient: AppGradients.gold,
      ),
      title: Text(
        widget.isDailyChallenge ? 'Daily Complete!' : AppStrings.levelComplete,
      ),
      message: Text(
        widget.isDailyChallenge
            ? '${AppStrings.dailyChallengeTitle}  •  ${widget.moves} moves'
            : 'Level ${widget.levelNumber}  •  ${widget.moves} moves',
      ),
      children: [
        // Stars
        AnimatedBuilder(
          animation: _starsController,
          builder: (_, _) => Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(3, (i) {
              final filled = i < widget.stars;
              return Transform.scale(
                scale: _starAnims[i].value,
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 4,
                  ).copyWith(bottom: i == 1 ? 10 : 0),
                  child: Icon(
                    filled ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: filled ? AppColors.starGold : AppColors.starEmpty,
                    size: i == 1 ? 54 : 44,
                    semanticLabel: i == 0
                        ? '${widget.stars} of 3 stars'
                        : null,
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          _starMessage,
          textAlign: TextAlign.center,
          style: AppTextStyles.caption,
        ),
        const SizedBox(height: AppSpacing.md),

        // Coins earned (none when replaying an already-completed daily)
        if (_baseCoins > 0) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.coinGold.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadii.sm),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.monetization_on_rounded,
                    color: AppColors.coinGold, size: 20),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    _hasDoubledCoins
                        ? '+${_baseCoins * 2} coins earned (2x Bonus!)'
                        : '+$_baseCoins coins earned',
                    style: const TextStyle(
                      color: AppColors.coinGoldDark,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          if (!_hasDoubledCoins) ...[
            const SizedBox(height: AppSpacing.sm),
            PressableScale(
              onTap: _isLoadingAd ? null : _doubleCoins,
              semanticLabel: '2x Coins, watch ad',
              child: Container(
                width: double.infinity,
                constraints: const BoxConstraints(minHeight: 44),
                decoration: BoxDecoration(
                  gradient: AppGradients.reward,
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.movie_creation_rounded,
                        color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        _isLoadingAd ? 'Loading Ad...' : '2x Coins (Watch Ad)',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],

        const SizedBox(height: AppSpacing.lg),

        PrimaryButton(
          label: widget.isDailyChallenge
              ? AppStrings.backToDaily
              : AppStrings.nextLevel,
          onTap: widget.onNextLevel,
          width: double.infinity,
          icon: widget.isDailyChallenge
              ? Icons.check_rounded
              : Icons.arrow_forward_rounded,
        ),
        const SizedBox(height: AppSpacing.sm + 2),
        Row(
          children: [
            Expanded(
              child: SecondaryButton(
                label: AppStrings.replay,
                icon: Icons.replay_rounded,
                onTap: widget.onReplay,
              ),
            ),
            const SizedBox(width: AppSpacing.sm + 2),
            Expanded(
              child: SecondaryButton(
                label: AppStrings.home,
                icon: Icons.home_rounded,
                onTap: widget.onHome,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

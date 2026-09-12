import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../services/ad_service.dart';
import '../../../services/economy_service.dart';
import '../../../widgets/primary_button.dart';
import '../../../widgets/secondary_button.dart';

class LevelCompleteDialog extends StatefulWidget {
  final int stars;
  final int levelNumber;
  final int moves;
  final VoidCallback onNextLevel;
  final VoidCallback onReplay;
  final VoidCallback onHome;

  const LevelCompleteDialog({
    super.key,
    required this.stars,
    required this.levelNumber,
    required this.moves,
    required this.onNextLevel,
    required this.onReplay,
    required this.onHome,
  });

  @override
  State<LevelCompleteDialog> createState() => _LevelCompleteDialogState();
}

class _LevelCompleteDialogState extends State<LevelCompleteDialog>
    with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late AnimationController _starsController;
  late Animation<double> _scaleAnim;
  final List<Animation<double>> _starAnims = [];
  bool _hasDoubledCoins = false;
  bool _isLoadingAd = false;

  @override
  void initState() {
    super.initState();

    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _starsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _scaleAnim = CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    );

    for (int i = 0; i < 3; i++) {
      _starAnims.add(
        Tween<double>(begin: 0, end: 1).animate(
          CurvedAnimation(
            parent: _starsController,
            curve: Interval(i * 0.25, 0.5 + i * 0.2, curve: Curves.elasticOut),
          ),
        ),
      );
    }

    _scaleController.forward().then((_) => _starsController.forward());
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _starsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: ScaleTransition(
        scale: _scaleAnim,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Medal icon
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFBBF24), Color(0xFFF59E0B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.coinGold.withOpacity(0.4),
                      blurRadius: 16,
                    ),
                  ],
                ),
                child: const Icon(Icons.emoji_events_rounded,
                    color: Colors.white, size: 40),
              ),

              const SizedBox(height: 16),

              Text(
                AppStrings.levelComplete,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppColors.navyDark,
                ),
              ),

              Text(
                'Level ${widget.levelNumber}  •  ${widget.moves} moves',
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),

              const SizedBox(height: 20),

              // Stars
              AnimatedBuilder(
                animation: _starsController,
                builder: (_, __) => Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(3, (i) {
                    final filled = i < widget.stars;
                    final scale = _starAnims[i].value;
                    return Transform.scale(
                      scale: scale,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Icon(
                          filled
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          color: filled
                              ? AppColors.starGold
                              : AppColors.starEmpty,
                          size: 44,
                        ),
                      ),
                    );
                  }),
                ),
              ),

              const SizedBox(height: 12),

              // Coins earned
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.coinGold.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.monetization_on_rounded,
                        color: AppColors.coinGold, size: 20),
                    const SizedBox(width: 6),
                    Text(
                      _hasDoubledCoins
                          ? '+${(25 + (widget.stars == 3 ? 10 : 0)) * 2} coins earned (2x Bonus!)'
                          : '+${25 + (widget.stars == 3 ? 10 : 0)} coins earned',
                      style: const TextStyle(
                        color: AppColors.coinGoldDark,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // 2x Coins Rewarded Ad Button
              if (!_hasDoubledCoins)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: GestureDetector(
                    onTap: _isLoadingAd
                        ? null
                        : () async {
                            setState(() {
                              _isLoadingAd = true;
                            });
                            final baseCoins = 25 + (widget.stars == 3 ? 10 : 0);
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
                          },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.coinGold.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.movie_creation_rounded,
                              color: Colors.white, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            _isLoadingAd ? 'Loading Ad...' : '2x Coins (Watch Ad)',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              const SizedBox(height: 12),

              // Buttons
              PrimaryButton(
                label: AppStrings.nextLevel,
                onTap: widget.onNextLevel,
                width: double.infinity,
                icon: Icons.arrow_forward_rounded,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: SecondaryButton(
                      label: AppStrings.replay,
                      onTap: widget.onReplay,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SecondaryButton(
                      label: AppStrings.home,
                      onTap: widget.onHome,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

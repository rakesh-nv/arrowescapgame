import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/app_strings.dart';
import '../../core/theme/design_tokens.dart';
import '../../data/models/arrow_direction.dart';
import '../../game/config/difficulty_curve.dart';
import '../../services/economy_service.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_icon_button.dart';
import '../../widgets/coin_badge.dart';
import '../../widgets/difficulty_badge.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/secondary_button.dart';
import '../../widgets/stat_pill.dart';
import '../ads/ads_module.dart';
import 'home_controller.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(HomeController());
    final economy = Get.find<EconomyService>();

    void open(String route, {Object? arguments}) {
      Get.toNamed(route, arguments: arguments)
          ?.then((_) => controller.loadProgress());
    }

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppGradients.background),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) => SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.page,
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 480),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(height: AppSpacing.md),
                              _TopBar(
                                controller: controller,
                                economy: economy,
                                onSettings: () => open('/settings'),
                                onThemes: () => open('/themes'),
                              ),
                              const SizedBox(height: AppSpacing.xl),
                              const _Title(),
                              const SizedBox(height: AppSpacing.lg),
                              const _HeroIllustration(),
                              const SizedBox(height: AppSpacing.xl),
                              // Read the observables inside each Obx builder;
                              // reads in a child's build() are not tracked.
                              Obx(() => _ProgressCard(
                                    world: controller.currentWorld,
                                    done: controller.levelsCompleted.value,
                                    stars: controller.totalStars.value,
                                    maxStars: controller.maxStars,
                                  )),
                              const SizedBox(height: AppSpacing.lg),
                              Obx(() => _PlayButton(
                                    level: controller.currentLevel,
                                    isResuming: controller.isResuming,
                                    campaignComplete:
                                        controller.campaignComplete,
                                    hasProgress: controller.hasProgress,
                                    onPlay: () => controller.campaignComplete &&
                                            !controller.isResuming
                                        ? open('/level-select')
                                        : open(
                                            '/gameplay',
                                            arguments: controller.currentLevel,
                                          ),
                                  )),
                              const SizedBox(height: AppSpacing.md),
                              SecondaryButton(
                                label: AppStrings.levelMap,
                                icon: Icons.map_rounded,
                                onTap: () => open('/level-select'),
                              ),
                              const SizedBox(height: AppSpacing.lg),
                              Obx(() => _DailyCard(
                                    done: controller.dailyDoneToday.value,
                                    streak: controller.dailyStreak.value,
                                    onTap: () => open('/daily-challenge'),
                                  )),
                              const SizedBox(height: AppSpacing.lg),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // Bottom Banner Ad
              const BannerAdWidget(),
              const SizedBox(height: 4),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final HomeController controller;
  final EconomyService economy;
  final VoidCallback onSettings;
  final VoidCallback onThemes;

  const _TopBar({
    required this.controller,
    required this.economy,
    required this.onSettings,
    required this.onThemes,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        AppIconButton(
          icon: Icons.settings_rounded,
          tooltip: AppStrings.settings,
          onTap: onSettings,
        ),
        const Spacer(),
        Obx(
          () => StatPill(
            icon: Icons.star_rounded,
            value: '${controller.totalStars.value}',
            color: AppColors.starGold,
            semanticLabel: '${controller.totalStars.value} stars',
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Obx(() => CoinBadge(coins: economy.coins.value, fontSize: 14)),
        const Spacer(),
        AppIconButton(
          icon: Icons.palette_rounded,
          tooltip: AppStrings.themes,
          onTap: onThemes,
        ),
      ],
    );
  }
}

class _Title extends StatelessWidget {
  const _Title();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      label: AppStrings.appName,
      child: ExcludeSemantics(
        child: Column(
          children: [
            const FittedBox(
              child: Text('ARROW', style: AppTextStyles.display),
            ),
            ShaderMask(
              shaderCallback: (bounds) =>
                  AppGradients.primary.createShader(bounds),
              child: FittedBox(
                child: Text(
                  'ESCAPE',
                  style: AppTextStyles.display.copyWith(color: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              AppStrings.tagline,
              textAlign: TextAlign.center,
              style: AppTextStyles.body,
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  final CampaignWorld world;
  final int done;
  final int stars;
  final int maxStars;

  const _ProgressCard({
    required this.world,
    required this.done,
    required this.stars,
    required this.maxStars,
  });

  @override
  Widget build(BuildContext context) {
    final total = AppConstants.totalLevels;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${AppStrings.world} ${world.number} of '
                      '${total ~/ AppConstants.levelsPerWorld}',
                      style: AppTextStyles.caption,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      world.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.heading,
                    ),
                  ],
                ),
              ),
              DifficultyBadge(difficulty: world.difficulty),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Semantics(
            label: '$done of $total levels cleared',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: total == 0 ? 0 : done / total,
                backgroundColor: AppColors.cardBorder,
                color: difficultyColor(world.difficulty),
                minHeight: 6,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: Text(
                  '$done / $total ${AppStrings.levelsCleared}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              const Icon(Icons.star_rounded,
                  size: 16, color: AppColors.starGold),
              const SizedBox(width: 2),
              Text(
                '$stars / $maxStars',
                style: AppTextStyles.caption,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PlayButton extends StatelessWidget {
  final int level;
  final bool isResuming;
  final bool campaignComplete;
  final bool hasProgress;
  final VoidCallback onPlay;

  const _PlayButton({
    required this.level,
    required this.isResuming,
    required this.campaignComplete,
    required this.hasProgress,
    required this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    final String label;
    final String? subtitle;
    if (isResuming) {
      label = '${AppStrings.continueLevel} · ${AppStrings.level} $level';
      subtitle = 'Pick up where you left off';
    } else if (campaignComplete) {
      label = AppStrings.campaignComplete;
      subtitle = 'Replay any level for 3 stars';
    } else if (hasProgress) {
      label = '${AppStrings.play} · ${AppStrings.level} $level';
      subtitle = null;
    } else {
      label = AppStrings.play;
      subtitle = 'Start with ${AppStrings.level} 1';
    }
    return PrimaryButton(
      label: label,
      subtitle: subtitle,
      icon: Icons.play_arrow_rounded,
      width: double.infinity,
      onTap: onPlay,
    );
  }
}

class _DailyCard extends StatelessWidget {
  final bool done;
  final int streak;
  final VoidCallback onTap;

  const _DailyCard({
    required this.done,
    required this.streak,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final subtitle = done
        ? 'Completed today${streak > 0 ? ' · $streak-day streak' : ''}'
        : '+${AppConstants.coinsDailyChallenge} coins · a new puzzle every day';
    return AppCard(
      gradient: AppGradients.daily,
      onTap: onTap,
      semanticLabel: '${AppStrings.dailyChallenge}. $subtitle',
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg + 4,
        vertical: AppSpacing.md + 2,
      ),
      child: Row(
        children: [
          Icon(
            done ? Icons.check_circle_rounded : Icons.wb_sunny_rounded,
            color: done ? Colors.greenAccent : Colors.amber,
            size: 28,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  AppStrings.dailyChallenge,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(AppRadii.pill),
            ),
            child: Text(
              done ? 'View' : AppStrings.play,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroIllustration extends StatefulWidget {
  const _HeroIllustration();

  @override
  State<_HeroIllustration> createState() => _HeroIllustrationState();
}

class _HeroIllustrationState extends State<_HeroIllustration>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  )..repeat(reverse: true);
  late final Animation<double> _anim =
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _anim,
          builder: (_, _) => CustomPaint(
            size: const Size(200, 100),
            painter: _HeroPainter(t: _anim.value),
          ),
        ),
      ),
    );
  }
}

class _HeroPainter extends CustomPainter {
  final double t;

  const _HeroPainter({required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    // Snake 1: main dark navy snake path with two 90-degree turns
    p.color = AppColors.navyDark;
    final x1 = 15.0 + t * 14;
    final path1 = Path()
      ..moveTo(x1, 75)
      ..lineTo(x1 + 55, 75)
      ..lineTo(x1 + 55, 30)
      ..lineTo(x1 + 115, 30);
    canvas.drawPath(path1, p);
    _drawHead(canvas, Offset(x1 + 115, 30), AppColors.accentBlue,
        ArrowDirection.right);

    // Snake 2: secondary snake with a 90-degree turn
    p.color = AppColors.navyDark.withValues(alpha: 0.55);
    final path2 = Path()
      ..moveTo(135, 15)
      ..lineTo(135, 55)
      ..lineTo(175, 55)
      ..lineTo(175, 85);
    canvas.drawPath(path2, p);
    _drawHead(canvas, const Offset(175, 85), AppColors.accentPurple,
        ArrowDirection.down);
  }

  void _drawHead(Canvas canvas, Offset tip, Color color, ArrowDirection dir) {
    final hp = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final path = Path();
    const hs = 13.0;

    switch (dir) {
      case ArrowDirection.right:
        path
          ..moveTo(tip.dx, tip.dy)
          ..lineTo(tip.dx - hs, tip.dy - hs * 0.55)
          ..lineTo(tip.dx - hs * 0.85, tip.dy)
          ..lineTo(tip.dx - hs, tip.dy + hs * 0.55);
      case ArrowDirection.left:
        path
          ..moveTo(tip.dx, tip.dy)
          ..lineTo(tip.dx + hs, tip.dy - hs * 0.55)
          ..lineTo(tip.dx + hs * 0.85, tip.dy)
          ..lineTo(tip.dx + hs, tip.dy + hs * 0.55);
      case ArrowDirection.down:
        path
          ..moveTo(tip.dx, tip.dy)
          ..lineTo(tip.dx - hs * 0.55, tip.dy - hs)
          ..lineTo(tip.dx, tip.dy - hs * 0.85)
          ..lineTo(tip.dx + hs * 0.55, tip.dy - hs);
      case ArrowDirection.up:
        path
          ..moveTo(tip.dx, tip.dy)
          ..lineTo(tip.dx - hs * 0.55, tip.dy + hs)
          ..lineTo(tip.dx, tip.dy + hs * 0.85)
          ..lineTo(tip.dx + hs * 0.55, tip.dy + hs);
    }
    path.close();
    canvas.drawPath(path, hp);
  }

  @override
  bool shouldRepaint(_HeroPainter old) => old.t != t;
}

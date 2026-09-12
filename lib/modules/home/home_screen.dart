import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/constants/app_constants.dart';
import '../../data/models/arrow_direction.dart';
import '../../services/economy_service.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/coin_badge.dart';
import '../ads/widgets/banner_ad_widget.dart';
import 'home_controller.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(HomeController());
    final economy = Get.find<EconomyService>();

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF5F7FF), Color(0xFFEEF2FF)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight,
                  ),
                  child: IntrinsicHeight(
                    child: Column(
                      children: [
                        // Top bar
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              GameIconButtonSmall(
                                icon: Icons.settings_rounded,
                                onTap: () => Get.toNamed('/settings')
                                    ?.then((_) => controller.loadProgress()),
                              ),
                              Obx(() => CoinBadge(coins: economy.coins.value)),
                              GameIconButtonSmall(
                                icon: Icons.palette_rounded,
                                onTap: () => Get.toNamed('/themes')
                                    ?.then((_) => controller.loadProgress()),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Title
                        const Text(
                          'ARROW',
                          style: TextStyle(
                            fontSize: 44,
                            fontWeight: FontWeight.w800,
                            color: AppColors.navyDark,
                            letterSpacing: 6,
                            height: 1,
                          ),
                        ),
                        ShaderMask(
                          shaderCallback: (bounds) =>
                              AppColors.primaryGradient.createShader(bounds),
                          child: const Text(
                            'ESCAPE',
                            style: TextStyle(
                              fontSize: 44,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 6,
                              height: 1,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          AppStrings.tagline,
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Hero arrow illustration
                        const _HeroIllustration(),
                        const SizedBox(height: 24),
                        // Continue card
                        Obx(() {
                          if (controller.hasProgress) {
                            return Padding(
                              padding: const EdgeInsets.only(
                                left: 32,
                                right: 32,
                                bottom: 16,
                              ),
                              child: _ContinueCard(
                                levelNumber: controller.currentLevel,
                                onTap: () => Get.toNamed(
                                  '/gameplay',
                                  arguments: controller.currentLevel,
                                )?.then((_) => controller.loadProgress()),
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        }),

                        // Play button
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: PrimaryButton(
                            label: AppStrings.play,
                            onTap: () => Get.toNamed('/level-select')
                                ?.then((_) => controller.loadProgress()),
                            width: double.infinity,
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Daily challenge
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: _DailyChallengeBanner(
                            onTap: () => Get.toNamed('/daily-challenge')
                                ?.then((_) => controller.loadProgress()),
                          ),
                        ),

                        const Spacer(),

                        // Bottom nav
                        Padding(
                          padding: const EdgeInsets.only(top: 12, bottom: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _BottomNavItem(
                                icon: Icons.emoji_events_rounded,
                                label: AppStrings.achievements,
                                onTap: () {},
                              ),
                            ],
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
            },
          ),
        ),
      ),
    );
  }
}

class _ContinueCard extends StatelessWidget {
  final int levelNumber;
  final VoidCallback onTap;

  const _ContinueCard({required this.levelNumber, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.only(bottom: 0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.cardBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.accentBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.play_circle_rounded,
                color: AppColors.accentBlue,
                size: 28,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${AppStrings.continueLevel} ${AppStrings.level} $levelNumber',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: levelNumber / AppConstants.totalLevels,
                      backgroundColor: AppColors.cardBorder,
                      color: AppColors.accentBlue,
                      minHeight: 5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${levelNumber - 1} / ${AppConstants.totalLevels}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

class _DailyChallengeBanner extends StatelessWidget {
  final VoidCallback onTap;

  const _DailyChallengeBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF7C3AED), Color(0xFF6C63FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF7C3AED).withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.wb_sunny_rounded, color: Colors.amber, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Daily Challenge',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    '+${AppConstants.coinsDailyChallenge} coins reward',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Play',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
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
  late AnimationController _controller;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => CustomPaint(
        size: const Size(200, 100),
        painter: _HeroPainter(t: _anim.value),
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

    // Snake 1: Main dark navy continuous snake path with two 90-degree turns
    p.color = AppColors.navyDark;
    final x1 = 15.0 + t * 14;
    final path1 = Path()
      ..moveTo(x1, 75)
      ..lineTo(x1 + 55, 75)
      ..lineTo(x1 + 55, 30)
      ..lineTo(x1 + 115, 30);
    canvas.drawPath(path1, p);
    _drawHead(canvas, Offset(x1 + 115, 30), AppColors.accentBlue, ArrowDirection.right);

    // Snake 2: Secondary continuous snake with 90-degree turn
    p.color = AppColors.navyDark.withOpacity(0.55);
    final path2 = Path()
      ..moveTo(135, 15)
      ..lineTo(135, 55)
      ..lineTo(175, 55)
      ..lineTo(175, 85);
    canvas.drawPath(path2, p);
    _drawHead(canvas, const Offset(175, 85), AppColors.accentPurple, ArrowDirection.down);
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
        break;
      case ArrowDirection.left:
        path
          ..moveTo(tip.dx, tip.dy)
          ..lineTo(tip.dx + hs, tip.dy - hs * 0.55)
          ..lineTo(tip.dx + hs * 0.85, tip.dy)
          ..lineTo(tip.dx + hs, tip.dy + hs * 0.55);
        break;
      case ArrowDirection.down:
        path
          ..moveTo(tip.dx, tip.dy)
          ..lineTo(tip.dx - hs * 0.55, tip.dy - hs)
          ..lineTo(tip.dx, tip.dy - hs * 0.85)
          ..lineTo(tip.dx + hs * 0.55, tip.dy - hs);
        break;
      case ArrowDirection.up:
        path
          ..moveTo(tip.dx, tip.dy)
          ..lineTo(tip.dx - hs * 0.55, tip.dy + hs)
          ..lineTo(tip.dx, tip.dy + hs * 0.85)
          ..lineTo(tip.dx + hs * 0.55, tip.dy + hs);
        break;
    }
    path.close();
    canvas.drawPath(path, hp);
  }

  @override
  bool shouldRepaint(_HeroPainter old) => old.t != t;
}

class GameIconButtonSmall extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const GameIconButtonSmall({
    super.key,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.07),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, color: AppColors.navyDark, size: 22),
      ),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _BottomNavItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.textSecondary, size: 24),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

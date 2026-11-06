import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/app_strings.dart';
import '../../core/theme/design_tokens.dart';
import '../../game/config/difficulty_curve.dart';
import '../../services/economy_service.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_icon_button.dart';
import '../../widgets/coin_badge.dart';
import '../../widgets/difficulty_badge.dart';
import '../../widgets/player_welcome_banner.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/secondary_button.dart';
import '../../widgets/stat_pill.dart';
import '../ads/ads_module.dart';
import '../update/update_banner.dart';
import '../update/update_prompts.dart';
import 'home_controller.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(HomeController());
    final economy = Get.find<EconomyService>();

    void open(String route, {Object? arguments}) {
      Get.toNamed(route, arguments: arguments)?.then((_) {
        controller.loadProgress();
        UpdatePrompts.onHomeVisible();
      });
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
                              const UpdateBanner(),
                              // Only for players signed in to Play Games; the
                              // level is their real one from saved progress,
                              // refreshed whenever Home comes back into view.
                              Obx(
                                () => PlayerWelcomeBanner(
                                  level: controller.highestUnlockedLevel.value,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.xl),
                              const _Title(),
                              const SizedBox(height: AppSpacing.lg),
                              const _HeroIllustration(),
                              const SizedBox(height: AppSpacing.xl),
                              // Read the observables inside each Obx builder;
                              // reads in a child's build() are not tracked.
                              Obx(
                                () => _ProgressCard(
                                  world: controller.currentWorld,
                                  done: controller.levelsCompleted.value,
                                  stars: controller.totalStars.value,
                                  maxStars: controller.maxStars,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.lg),
                              Obx(
                                () => _PlayButton(
                                  level: controller.currentLevel,
                                  isResuming: controller.isResuming,
                                  campaignComplete: controller.campaignComplete,
                                  hasProgress: controller.hasProgress,
                                  onPlay: () =>
                                      controller.campaignComplete &&
                                          !controller.isResuming
                                      ? open('/level-select')
                                      : open(
                                          '/gameplay',
                                          arguments: controller.currentLevel,
                                        ),
                                ),
                              ),
                              const SizedBox(height: AppSpacing.md),
                              SecondaryButton(
                                label: AppStrings.levelMap,
                                icon: Icons.map_rounded,
                                onTap: () => open('/level-select'),
                              ),
                              const SizedBox(height: AppSpacing.lg),
                              Obx(
                                () => _DailyCard(
                                  done: controller.dailyDoneToday.value,
                                  streak: controller.dailyStreak.value,
                                  onTap: () => open('/daily-challenge'),
                                ),
                              ),
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
            const FittedBox(child: Text('ARROW', style: AppTextStyles.display)),
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
              const Icon(
                Icons.star_rounded,
                size: 16,
                color: AppColors.starGold,
              ),
              const SizedBox(width: 2),
              Text('$stars / $maxStars', style: AppTextStyles.caption),
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
    duration: const Duration(milliseconds: 3600),
  )..repeat();

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
          animation: _controller,
          builder: (_, _) => CustomPaint(
            size: const Size(200, 100),
            painter: _HeroPainter(t: _controller.value),
          ),
        ),
      ),
    );
  }
}

/// A tiny playable-looking board: navy arrows on a dot grid, and a blue arrow
/// that gets tapped and slides out along its clear lane, on a loop.
class _HeroPainter extends CustomPainter {
  /// Position in the loop, 0 to 1.
  final double t;

  const _HeroPainter({required this.t});

  static const double _cell = 25;
  static const double _stroke = 6.5;
  static const double _headLength = 12;

  // (row, col) cells, tail to head, like ArrowModel.points.
  static const List<List<(int, int)>> _navy = [
    [(2, 1), (3, 1), (3, 0), (2, 0), (1, 0)],
    [(0, 6), (0, 5), (0, 4), (0, 3), (0, 2), (1, 2), (1, 1)],
    [(2, 5), (2, 6), (2, 7), (3, 7), (3, 6), (3, 5), (3, 4)],
  ];
  static const List<(int, int)> _blue = [
    (3, 2),
    (2, 2),
    (2, 3),
    (1, 3),
    (1, 4),
  ];

  static Offset _centre((int, int) p) =>
      Offset((p.$2 + 0.5) * _cell, (p.$1 + 0.5) * _cell);

  /// Polyline through [pts] with rounded corners.
  static Path _rounded(List<Offset> pts) {
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    const radius = _cell * 0.3;
    for (var i = 1; i < pts.length - 1; i++) {
      final corner = pts[i];
      final toPrev = pts[i - 1] - corner;
      final toNext = pts[i + 1] - corner;
      final inPoint = corner + toPrev / toPrev.distance * radius;
      final outPoint = corner + toNext / toNext.distance * radius;
      path.lineTo(inPoint.dx, inPoint.dy);
      path.quadraticBezierTo(corner.dx, corner.dy, outPoint.dx, outPoint.dy);
    }
    path.lineTo(pts.last.dx, pts.last.dy);
    return path;
  }

  /// Draws the stretch [from]..[to] of [track] as an arrow whose tip is at [to].
  void _drawArrow(
    Canvas canvas,
    PathMetric track,
    double from,
    double to,
    Color color,
  ) {
    final tangent = track.getTangentForOffset(to);
    if (tangent == null) return;
    final body = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(track.extractPath(from, to - _headLength * 0.7), body);

    final tip = tangent.position;
    final dir = tangent.vector;
    final normal = Offset(-dir.dy, dir.dx);
    final base = tip - dir * _headLength;
    canvas.drawPath(
      Path()
        ..moveTo(tip.dx, tip.dy)
        ..lineTo(
          base.dx + normal.dx * _headLength * 0.62,
          base.dy + normal.dy * _headLength * 0.62,
        )
        ..lineTo(
          base.dx - normal.dx * _headLength * 0.62,
          base.dy - normal.dy * _headLength * 0.62,
        )
        ..close(),
      Paint()
        ..color = color
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = 2
        ..style = PaintingStyle.fill,
    );
  }

  /// [t] mapped so it runs 0 to 1 between [start] and [end].
  double _phase(double start, double end) =>
      ((t - start) / (end - start)).clamp(0.0, 1.0);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);

    // Timeline: rest, tap ripple, slide out, empty beat, fade back in.
    final ripple = _phase(0.22, 0.42);
    final slide = Curves.easeInCubic.transform(_phase(0.36, 0.68));
    final appear = Curves.easeOut.transform(_phase(0.84, 1.0));
    final gone = t >= 0.68;
    final opacity = gone ? appear : 1.0;

    final dot = Paint()..color = AppColors.navyDark.withValues(alpha: 0.12);
    for (var r = 0; r < 4; r++) {
      for (var c = 0; c < 8; c++) {
        canvas.drawCircle(_centre((r, c)), 1.6, dot);
      }
    }

    // The clear lane lights up while the arrow is about to use it.
    final laneGlow = t < 0.36 ? _phase(0.0, 0.2) : 1 - _phase(0.5, 0.68);
    if (laneGlow > 0) {
      final lane = Paint()
        ..color = AppColors.accentBlue.withValues(alpha: 0.45 * laneGlow);
      for (var c = 5; c < 8; c++) {
        canvas.drawCircle(_centre((1, c)), 2.6, lane);
      }
    }

    for (final points in _navy) {
      final centres = points.map(_centre).toList();
      final dir = centres.last - centres[centres.length - 2];
      final path = _rounded([
        ...centres.sublist(0, centres.length - 1),
        centres.last + dir / dir.distance * (_cell * 0.35),
      ]);
      final metric = path.computeMetrics().first;
      _drawArrow(canvas, metric, 0, metric.length, AppColors.navyDark);
    }

    // The track runs along the arrow's path and on past the board edge.
    final centres = _blue.map(_centre).toList();
    final restTip = centres.last + const Offset(_cell * 0.35, 0);
    final rest = _rounded([
      ...centres.sublist(0, centres.length - 1),
      restTip,
    ]).computeMetrics().first;
    final length = rest.length;
    final track = _rounded([
      ...centres.sublist(0, centres.length - 1),
      Offset(size.width + length + _cell, restTip.dy),
    ]).computeMetrics().first;
    final shift = gone ? 0.0 : (track.length - length) * slide;

    if (ripple > 0 && ripple < 1) {
      canvas.drawCircle(
        centres[2],
        4 + ripple * 20,
        Paint()
          ..color = AppColors.accentBlue.withValues(alpha: 0.4 * (1 - ripple))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }

    if (opacity > 0) {
      if (slide > 0 && !gone) {
        canvas.drawPath(
          track.extractPath((shift - 36).clamp(0.0, track.length), shift),
          Paint()
            ..color = AppColors.accentBlue.withValues(alpha: 0.3)
            ..style = PaintingStyle.stroke
            ..strokeWidth = _stroke
            ..strokeCap = StrokeCap.round
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
        );
      }
      canvas.drawPath(
        track.extractPath(shift, shift + length),
        Paint()
          ..color = AppColors.accentBlue.withValues(alpha: 0.28 * opacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = _stroke + 3
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
      // One layer, so body and head fade together without a darker overlap.
      canvas.saveLayer(
        Offset.zero & size,
        Paint()..color = Colors.black.withValues(alpha: opacity),
      );
      _drawArrow(canvas, track, shift, shift + length, AppColors.accentBlue);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_HeroPainter old) => old.t != t;
}

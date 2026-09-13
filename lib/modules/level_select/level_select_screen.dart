import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/app_strings.dart';
import '../../services/economy_service.dart';
import '../../widgets/coin_badge.dart';
import '../ads/widgets/banner_ad_widget.dart';
import 'level_select_controller.dart';
import 'widgets/level_map_background.dart';
import 'widgets/level_map_node.dart';
import 'widgets/level_map_painter.dart';
import 'widgets/player_avatar_marker.dart';
import 'widgets/world_banner_widget.dart';

class LevelSelectScreen extends StatefulWidget {
  const LevelSelectScreen({super.key});

  @override
  State<LevelSelectScreen> createState() => _LevelSelectScreenState();
}

class _LevelSelectScreenState extends State<LevelSelectScreen>
    with SingleTickerProviderStateMixin {
  late LevelSelectController controller;
  late ScrollController _scrollController;
  late AnimationController _progressionAnimController;

  late Animation<double> _popAnim;
  late Animation<double> _glowAnim;
  late Animation<double> _travelAnim;
  late Animation<double> _unlockAnim;

  bool _isAnimatingProgression = false;
  int _completedLvl = 0;
  int _nextLvl = 0;

  static const double rowHeight = 96.0;
  static const double paddingBottom = 160.0;
  static const double paddingTop = 140.0;

  double get totalHeight =>
      (AppConstants.totalLevels * rowHeight) + paddingBottom + paddingTop;

  @override
  void initState() {
    super.initState();
    controller = Get.put(LevelSelectController());

    final initialLvl = LevelSelectController.justCompletedLevel.value > 0
        ? LevelSelectController.justCompletedLevel.value
        : controller.highestUnlocked;
    final initialY = controller.getNodeY(
      initialLvl,
      totalHeight,
      rowHeight,
      paddingBottom,
    );
    final initialScroll = (initialY - 350.0).clamp(0.0, totalHeight);
    _scrollController = ScrollController(initialScrollOffset: initialScroll);

    _progressionAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    // Stage 1: Completed node pop & scale (0.0 to 0.2)
    _popAnim = Tween<double>(begin: 1.0, end: 1.35).animate(
      CurvedAnimation(
        parent: _progressionAnimController,
        curve: const Interval(0.0, 0.2, curve: Curves.elasticOut),
      ),
    );

    // Stage 2: Glow & particle burst (0.15 to 0.35)
    _glowAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _progressionAnimController,
        curve: const Interval(0.15, 0.35, curve: Curves.easeOut),
      ),
    );

    // Stage 3 & 4: Camera scroll & player marker path traversal (0.35 to 0.8)
    _travelAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _progressionAnimController,
        curve: const Interval(0.35, 0.8, curve: Curves.easeInOutCubic),
      ),
    );

    // Stage 5 & 6: Next level unlock scale & bounce (0.8 to 1.0)
    _unlockAnim = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _progressionAnimController,
        curve: const Interval(0.8, 1.0, curve: Curves.elasticOut),
      ),
    );

    _travelAnim.addListener(_onTravelAnimUpdate);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndRunProgressionAnimation();
    });
  }

  void _onTravelAnimUpdate() {
    if (_isAnimatingProgression && _scrollController.hasClients) {
      final viewportHeight = MediaQuery.of(context).size.height;
      final maxScroll = _scrollController.position.maxScrollExtent;

      final fromY = controller.getNodeY(
          _completedLvl, totalHeight, rowHeight, paddingBottom);
      final toY = controller.getNodeY(
          _nextLvl, totalHeight, rowHeight, paddingBottom);
      final currentY = fromY + (toY - fromY) * _travelAnim.value;

      final targetScroll = currentY - (viewportHeight / 2);
      _scrollController.jumpTo(targetScroll.clamp(0.0, maxScroll));
    }
  }

  void _checkAndRunProgressionAnimation() {
    final justCompleted = LevelSelectController.justCompletedLevel.value;
    final lastAnimated = LevelSelectController.lastAnimatedLevel;
    final screenWidth = MediaQuery.of(context).size.width;
    final viewportHeight = MediaQuery.of(context).size.height;

    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;

    if (justCompleted > 0 && justCompleted != lastAnimated) {
      // Trigger Upward Progression Sequence
      _completedLvl = justCompleted;
      _nextLvl = (justCompleted + 1).clamp(1, AppConstants.totalLevels);
      LevelSelectController.lastAnimatedLevel = justCompleted;

      final initialScroll = controller.getScrollOffsetForLevel(
        _completedLvl,
        totalHeight,
        rowHeight,
        paddingBottom,
        viewportHeight,
        maxScroll,
      );
      _scrollController.jumpTo(initialScroll);

      setState(() {
        _isAnimatingProgression = true;
      });

      _progressionAnimController.forward(from: 0).then((_) {
        if (mounted) {
          setState(() {
            _isAnimatingProgression = false;
          });
        }
      });
    } else {
      // Normal entrance: center map around current highest unlocked level
      final targetScroll = controller.getScrollOffsetForLevel(
        controller.highestUnlocked,
        totalHeight,
        rowHeight,
        paddingBottom,
        viewportHeight,
        maxScroll,
      );
      _scrollController.animateTo(
        targetScroll,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _travelAnim.removeListener(_onTravelAnimUpdate);
    _scrollController.dispose();
    _progressionAnimController.dispose();
    super.dispose();
  }

  Offset _calculateMarkerPosition(double screenWidth) {
    if (_isAnimatingProgression && _completedLvl > 0 && _nextLvl > 0) {
      final t = _travelAnim.value;
      final fromX = controller.getNodeX(_completedLvl, screenWidth);
      final fromY = controller.getNodeY(
          _completedLvl, totalHeight, rowHeight, paddingBottom);
      final toX = controller.getNodeX(_nextLvl, screenWidth);
      final toY = controller.getNodeY(
          _nextLvl, totalHeight, rowHeight, paddingBottom);

      final midY = (fromY + toY) / 2;

      // Cubic Bezier curve matching LevelMapPainter curve
      final u = 1 - t;
      final tt = t * t;
      final uu = u * u;
      final uuu = uu * u;
      final ttt = tt * t;

      final x = uuu * fromX + 3 * uu * t * fromX + 3 * u * tt * toX + ttt * toX;
      final y = uuu * fromY + 3 * uu * t * midY + 3 * u * tt * midY + ttt * toY;

      return Offset(x, y);
    } else {
      final targetLvl = controller.highestUnlocked;
      final x = controller.getNodeX(targetLvl, screenWidth);
      final y = controller.getNodeY(
          targetLvl, totalHeight, rowHeight, paddingBottom);
      return Offset(x, y);
    }
  }

  @override
  Widget build(BuildContext context) {
    final economy = Get.find<EconomyService>();
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FF),
      body: Stack(
        children: [
          // 1. Scrollable Vertical Map Viewport
          SingleChildScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            child: SizedBox(
              width: screenWidth,
              height: totalHeight,
              child: AnimatedBuilder(
                animation: _progressionAnimController,
                builder: (context, child) {
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Background Sky & Biomes
                      LevelMapBackground(
                        totalHeight: totalHeight,
                        screenWidth: screenWidth,
                      ),

                      // Winding Path CustomPainter
                      CustomPaint(
                        size: Size(screenWidth, totalHeight),
                        painter: LevelMapPainter(
                          controller: controller,
                          totalLevels: AppConstants.totalLevels,
                          highestUnlocked: controller.highestUnlocked,
                          totalHeight: totalHeight,
                          rowHeight: rowHeight,
                          paddingBottom: paddingBottom,
                        ),
                      ),

                      // World Landmark Banners
                      ..._buildWorldBanners(screenWidth),

                      // Level Nodes (1 to 100)
                      ..._buildLevelNodes(screenWidth),

                      // Player Avatar Marker
                      PlayerAvatarMarker(
                        position: _calculateMarkerPosition(screenWidth),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),

          // 2. Floating Top Header Bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildTopHeader(economy),
          ),

          // 3. Bottom Banner Ad
          const Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  BannerAdWidget(),
                  SizedBox(height: 4),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildWorldBanners(double screenWidth) {
    final List<Widget> banners = [];
    final worlds = [
      {'lvl': 1, 'title': AppStrings.world1, 'sub': AppStrings.world1Sub, 'color': AppColors.diffEasy},
      {'lvl': 21, 'title': AppStrings.world2, 'sub': AppStrings.world2Sub, 'color': AppColors.diffNormal},
      {'lvl': 51, 'title': AppStrings.world3, 'sub': AppStrings.world3Sub, 'color': AppColors.diffHard},
      {'lvl': 81, 'title': AppStrings.world4, 'sub': AppStrings.world4Sub, 'color': AppColors.diffExpert},
    ];

    for (final w in worlds) {
      final lvl = w['lvl'] as int;
      final y = controller.getNodeY(lvl, totalHeight, rowHeight, paddingBottom) + 48;
      banners.add(
        Positioned(
          left: (screenWidth - 180) / 2,
          top: y,
          child: WorldBannerWidget(
            title: w['title'] as String,
            subtitle: w['sub'] as String,
            accentColor: w['color'] as Color,
          ),
        ),
      );
    }
    return banners;
  }

  List<Widget> _buildLevelNodes(double screenWidth) {
    final List<Widget> nodes = [];

    for (int lvl = 1; lvl <= AppConstants.totalLevels; lvl++) {
      final x = controller.getNodeX(lvl, screenWidth);
      final y = controller.getNodeY(lvl, totalHeight, rowHeight, paddingBottom);

      final isUnlocked = controller.isUnlocked(lvl);
      final isCurrent = controller.isCurrent(lvl);
      final isCompleted = controller.isCompleted(lvl);
      final stars = controller.starsForLevel(lvl);
      final isBoss = controller.isBossLevel(lvl);
      final isChallenge = controller.isChallengeLevel(lvl);

      double nodeScale = 1.0;
      bool showGlow = false;

      if (_isAnimatingProgression) {
        if (lvl == _completedLvl) {
          nodeScale = _popAnim.value;
          showGlow = _glowAnim.value > 0.1;
        } else if (lvl == _nextLvl) {
          nodeScale = _unlockAnim.value;
          showGlow = _unlockAnim.value > 0.85;
        }
      }

      nodes.add(
        Positioned(
          left: x - 36,
          top: y - 36,
          child: LevelMapNode(
            levelNumber: lvl,
            stars: stars,
            isUnlocked: isUnlocked || (_isAnimatingProgression && lvl == _nextLvl),
            isCurrent: isCurrent && !_isAnimatingProgression,
            isCompleted: isCompleted,
            isBoss: isBoss,
            isChallenge: isChallenge,
            scaleOverride: nodeScale,
            showGlow: showGlow,
            onTap: () {
              Get.toNamed('/gameplay', arguments: lvl);
            },
          ),
        ),
      );
    }

    return nodes;
  }

  Widget _buildTopHeader(EconomyService economy) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        bottom: 12,
        left: 16,
        right: 16,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          // Back button
          GestureDetector(
            onTap: () => Get.back(),
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 18,
                color: AppColors.navyDark,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Title
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  AppStrings.levelSelect,
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: AppColors.navyDark,
                  ),
                ),
                Text(
                  'Progression Map',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          // Total Stars Badge
          Obx(
            () => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.starGold.withOpacity(0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.starGold.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.star_rounded, color: AppColors.starGold, size: 18),
                  const SizedBox(width: 4),
                  Text(
                    '${controller.totalStars}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: AppColors.navyDark,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Coin Badge
          Obx(() => CoinBadge(coins: economy.coins.value, fontSize: 13)),
        ],
      ),
    );
  }
}

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/app_strings.dart';
import '../../core/theme/design_tokens.dart';
import '../../services/economy_service.dart';
import '../../services/haptic_service.dart';
import '../../widgets/app_icon_button.dart';
import '../../widgets/coin_badge.dart';
import '../ads/ads_module.dart';
import 'level_select_controller.dart';
import 'map/level_map_layout.dart';
import 'map/map_biome.dart';
import 'widgets/level_map_node.dart';
import 'widgets/level_start_sheet.dart';
import 'widgets/map_ambient_painter.dart';
import 'widgets/map_scene_painter.dart';
import 'widgets/milestone_trophy.dart';
import 'widgets/player_avatar_marker.dart';
import 'widgets/world_banner_widget.dart';

/// Adventure-style level map: one themed region per campaign world, laid
/// out bottom (level 1) to top along a winding trail.
///
/// Performance: the map is a lazily built, reversed list with one item per
/// world, so only the regions on screen exist. Each item's scenery is
/// painted once into its own layer; a single looping controller drives the
/// ambient particles, the current level's halo and the player marker, and
/// nothing else rebuilds per frame. No level is generated to draw the map.
class LevelSelectScreen extends StatefulWidget {
  const LevelSelectScreen({super.key});

  @override
  State<LevelSelectScreen> createState() => _LevelSelectScreenState();
}

class _LevelSelectScreenState extends State<LevelSelectScreen>
    with TickerProviderStateMixin {
  late final LevelSelectController controller;

  /// Long seamless loop for ambient motion (particles, halo, marker bob).
  late final AnimationController _ambient;

  /// One-shot progression after a level was completed.
  late final AnimationController _progression;
  late final Animation<double> _popAnim;
  late final Animation<double> _burstAnim;
  late final Animation<double> _travelAnim;
  late final Animation<double> _unlockAnim;

  ScrollController? _scroll;
  LevelMapLayout? _layout;
  double _viewportHeight = 0;
  final ValueNotifier<int> _sectionInView = ValueNotifier(0);
  Worker? _progressWorker;

  bool _animatingProgression = false;
  int _completedLvl = 0;
  int _nextLvl = 0;

  @override
  void initState() {
    super.initState();
    controller = Get.put(LevelSelectController());
    controller.refreshProgress();

    _ambient = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 40),
    );

    _progression = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    // Completed node pops (0.0–0.2) and bursts (0.1–0.4).
    _popAnim =
        TweenSequence<double>([
          TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.3), weight: 1),
          TweenSequenceItem(tween: Tween(begin: 1.3, end: 1.0), weight: 1),
        ]).animate(
          CurvedAnimation(
            parent: _progression,
            curve: const Interval(0.0, 0.25, curve: Curves.easeOut),
          ),
        );
    _burstAnim = CurvedAnimation(
      parent: _progression,
      curve: const Interval(0.1, 0.4, curve: Curves.easeOut),
    );
    // Marker walks the trail to the next level while the camera follows.
    _travelAnim = CurvedAnimation(
      parent: _progression,
      curve: const Interval(0.35, 0.8, curve: Curves.easeInOutCubic),
    );
    // Next level unlocks with a bounce.
    _unlockAnim = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(
        parent: _progression,
        curve: const Interval(0.8, 1.0, curve: Curves.elasticOut),
      ),
    );
    _progression.addListener(_followTravel);

    _progressWorker = ever(controller.progressVersion, (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _ambient.stop();
    } else if (!_ambient.isAnimating) {
      _ambient.repeat();
    }
  }

  @override
  void dispose() {
    _progressWorker?.dispose();
    _progression.removeListener(_followTravel);
    _scroll?.removeListener(_onScroll);
    _scroll?.dispose();
    _ambient.dispose();
    _progression.dispose();
    _sectionInView.dispose();
    super.dispose();
  }

  // ── Layout and scrolling ──────────────────────────────────────────────

  LevelMapLayout _ensureLayout(double width, double height) {
    var layout = _layout;
    if (layout == null || layout.width != width) {
      layout = LevelMapLayout(
        width: width,
        totalLevels: AppConstants.totalLevels,
      );
      _layout = layout;
    }
    _viewportHeight = height;
    if (_scroll == null) {
      final pending = _pendingProgressionLevel();
      final focus = pending > 0 ? pending : controller.focusLevel;
      final offset = layout.scrollOffsetFor(focus, height);
      _sectionInView.value = layout.sectionIndexAtOffset(offset, height);
      _scroll = ScrollController(initialScrollOffset: offset)
        ..addListener(_onScroll);
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _maybeRunProgression(),
      );
    }
    return layout;
  }

  double get _offset {
    final s = _scroll;
    if (s == null) return 0;
    return s.hasClients ? s.offset : s.initialScrollOffset;
  }

  void _onScroll() {
    final layout = _layout;
    if (layout == null) return;
    final i = layout.sectionIndexAtOffset(_offset, _viewportHeight);
    if (_sectionInView.value != i) _sectionInView.value = i;
  }

  Future<void> _animateToY(double y) async {
    final s = _scroll;
    final layout = _layout;
    if (s == null || layout == null || !s.hasClients) return;
    final target = layout.scrollOffsetForY(y, _viewportHeight);
    final distance = (target - s.offset).abs();
    if (distance < 1) return;
    await s.animateTo(
      target,
      duration: Duration(milliseconds: (distance / 4).clamp(350, 1200).round()),
      curve: Curves.easeInOutCubic,
    );
  }

  void _scrollToCurrent() {
    final layout = _layout;
    if (layout == null) return;
    _animateToY(layout.nodeY(controller.focusLevel));
  }

  void _scrollToSection(int index) {
    final layout = _layout;
    if (layout == null) return;
    final i = index.clamp(0, layout.sections.length - 1);
    // Frame the gate banner and the first levels of the world.
    _animateToY(layout.gateBannerY(i) + 140);
  }

  // ── Progression animation ─────────────────────────────────────────────

  int _pendingProgressionLevel() {
    final done = LevelSelectController.justCompletedLevel.value;
    if (done <= 0 || done == LevelSelectController.lastAnimatedLevel) return 0;
    if (done > AppConstants.totalLevels) return 0;
    return done;
  }

  void _maybeRunProgression() {
    if (!mounted) return;
    final done = _pendingProgressionLevel();
    if (done == 0) return;
    LevelSelectController.lastAnimatedLevel = done;
    final next = done + 1;
    _completedLvl = done;
    // Travel only when this completion unlocked the next level; replays
    // just celebrate in place.
    _nextLvl =
        next <= AppConstants.totalLevels &&
            next == controller.highestUnlocked &&
            !controller.isCompleted(next)
        ? next
        : 0;

    final layout = _layout;
    final s = _scroll;
    if (layout != null && s != null && s.hasClients) {
      s.jumpTo(layout.scrollOffsetFor(done, _viewportHeight));
    }
    setState(() => _animatingProgression = true);
    _progression.forward(from: 0).whenCompleteOrCancel(() {
      if (mounted) setState(() => _animatingProgression = false);
    });
  }

  void _followTravel() {
    if (!_animatingProgression || _nextLvl == 0) return;
    final layout = _layout;
    final s = _scroll;
    if (layout == null || s == null || !s.hasClients) return;
    final p = layout.trailPoint(_completedLvl, _travelAnim.value);
    s.jumpTo(layout.scrollOffsetForY(p.dy, _viewportHeight));
  }

  Offset _markerPoint(LevelMapLayout layout) {
    if (_animatingProgression && _completedLvl > 0) {
      if (_nextLvl == 0) return layout.point(_completedLvl);
      return layout.trailPoint(_completedLvl, _travelAnim.value);
    }
    return layout.point(controller.focusLevel);
  }

  // ── Interaction ───────────────────────────────────────────────────────

  HapticService? get _haptics =>
      Get.isRegistered<HapticService>() ? Get.find<HapticService>() : null;

  void _showMessage(String text) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(text),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        margin: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          MediaQuery.paddingOf(context).bottom + 72,
        ),
      ),
    );
  }

  void _onNodeTap(int level) {
    final state = controller.nodeState(level);
    if (state == MapNodeState.locked) {
      _haptics?.lightTap();
      _showMessage(
        '${AppStrings.levelLockedHint} ${controller.focusLevel} '
        '${AppStrings.toUnlock}',
      );
      return;
    }
    _haptics?.selectionClick();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      elevation: 0,
      builder: (sheetContext) => LevelStartSheet(
        level: level,
        state: state,
        stars: controller.starsForLevel(level),
        isBoss: controller.isBossLevel(level),
        isChallenge: controller.isChallengeLevel(level),
        onPlay: () {
          Navigator.of(sheetContext).pop();
          _startLevel(level);
        },
      ),
    );
  }

  Future<void> _startLevel(int level) async {
    // Re-check: the sheet may have stayed open while progress changed.
    if (!controller.isUnlocked(level)) return;
    await Get.toNamed('/gameplay', arguments: level);
    if (!mounted) return;
    controller.refreshProgress();
    _maybeRunProgression();
  }

  void _onTrophyTap(int sectionIndex) {
    final world = _layout!.sections[sectionIndex].world;
    final trophy = controller.worldTrophy(world);
    final count = controller.worldLevelCount(world);
    final detail =
        '${controller.worldClearedCount(world)}/$count · '
        '★ ${controller.worldStars(world)}/${count * 3}';
    final text = switch (trophy) {
      WorldTrophy.none => AppStrings.trophyLocked,
      WorldTrophy.bronze => AppStrings.trophyBronze,
      WorldTrophy.gold => AppStrings.trophyGold,
    };
    _haptics?.selectionClick();
    _showMessage('${AppStrings.worldTrophy}: $text ($detail)');
  }

  // ── Build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final economy = Get.find<EconomyService>();
    return Scaffold(
      backgroundColor: MapBiome.all.first.groundBottom,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final layout = _ensureLayout(
            constraints.maxWidth,
            constraints.maxHeight,
          );
          return Stack(
            children: [
              ListView.builder(
                controller: _scroll,
                reverse: true,
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.zero,
                itemCount: layout.itemCount,
                itemExtentBuilder: (index, _) =>
                    index < layout.itemCount ? layout.itemExtent(index) : null,
                itemBuilder: (context, index) => _buildItem(layout, index),
              ),
              Positioned.fill(
                child: IgnorePointer(child: _buildMarker(layout)),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: _buildHeader(economy, layout),
              ),
              Positioned(
                right: AppSpacing.md,
                bottom: MediaQuery.paddingOf(context).bottom + 70,
                child: _buildNavControls(layout),
              ),
              const Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [BannerAdWidget(), SizedBox(height: 4)],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildItem(LevelMapLayout layout, int index) {
    final extent = layout.itemExtent(index);
    final top = layout.itemBottom(index) + extent;
    double localY(double y) => top - y;

    final MapBiome biome;
    if (index == 0) {
      biome = MapBiome.forWorld(1);
    } else if (index == layout.summitIndex) {
      biome = MapBiome.forWorld(layout.sections.last.world.number);
    } else {
      biome = MapBiome.forWorld(layout.sections[index - 1].world.number);
    }

    final children = <Widget>[
      Positioned.fill(
        child: RepaintBoundary(
          child: CustomPaint(
            painter: MapScenePainter(
              layout: layout,
              itemIndex: index,
              highestUnlocked: controller.highestUnlocked,
            ),
          ),
        ),
      ),
      Positioned.fill(
        child: IgnorePointer(
          child: RepaintBoundary(
            child: CustomPaint(
              painter: MapAmbientPainter(
                animation: _ambient,
                biome: biome,
                seed: index * 101 + 3,
              ),
            ),
          ),
        ),
      ),
    ];

    if (index == 0) {
      final p = layout.point(0);
      children.add(
        Positioned(
          left: 0,
          right: 0,
          top: localY(p.dy) - 11,
          child: Center(
            child: _MapChip(label: AppStrings.mapStart, color: biome.accent),
          ),
        ),
      );
    } else if (index == layout.summitIndex) {
      children.add(
        Positioned(
          left: AppSpacing.lg,
          right: AppSpacing.lg,
          top: 132,
          child: Center(child: _buildSummitCard(biome)),
        ),
      );
    } else {
      final si = index - 1;
      final section = layout.sections[si];
      final world = section.world;
      children.add(
        Positioned(
          left: AppSpacing.lg,
          right: AppSpacing.lg,
          top: localY(layout.gateBannerY(si)) - 38,
          child: Center(
            child: WorldBannerWidget(
              world: world,
              biome: biome,
              unlocked: controller.isWorldUnlocked(world),
              cleared: controller.worldClearedCount(world),
              levelCount: controller.worldLevelCount(world),
              stars: controller.worldStars(world),
            ),
          ),
        ),
      );

      // Trophy beside the world's last level, on the roomier side.
      final last = section.lastLevel;
      final lx = layout.nodeX(last);
      final tx = (lx > layout.width / 2 ? lx - 88 : lx + 88).clamp(
        MilestoneTrophy.size / 2 + 4,
        layout.width - MilestoneTrophy.size / 2 - 4,
      );
      children.add(
        Positioned(
          left: tx - MilestoneTrophy.size / 2,
          top: localY(layout.nodeY(last)) - MilestoneTrophy.size / 2 - 6,
          child: MilestoneTrophy(
            trophy: controller.worldTrophy(world),
            onTap: () => _onTrophyTap(si),
          ),
        ),
      );

      for (var lvl = section.firstLevel; lvl <= section.lastLevel; lvl++) {
        children.add(
          Positioned(
            left: layout.nodeX(lvl) - LevelMapNode.width / 2,
            top: localY(layout.nodeY(lvl)) - LevelMapNode.centerY,
            child: _buildNode(lvl, biome),
          ),
        );
      }
    }

    return SizedBox(
      height: extent,
      child: Stack(children: children),
    );
  }

  Widget _buildNode(int lvl, MapBiome biome) {
    LevelMapNode node(MapNodeState state, double scale, double burst) =>
        LevelMapNode(
          levelNumber: lvl,
          state: state,
          stars: controller.starsForLevel(lvl),
          isBoss: controller.isBossLevel(lvl),
          isChallenge: controller.isChallengeLevel(lvl),
          darkGround: biome.dark,
          pulse: state == MapNodeState.current ? _ambient : null,
          scale: scale,
          burst: burst,
          onTap: () => _onNodeTap(lvl),
        );

    final animated =
        _animatingProgression &&
        (lvl == _completedLvl || (lvl == _nextLvl && _nextLvl > 0));
    if (!animated) return node(controller.nodeState(lvl), 1, 0);

    return AnimatedBuilder(
      animation: _progression,
      builder: (context, _) {
        if (lvl == _completedLvl) {
          return node(
            controller.nodeState(lvl),
            _popAnim.value,
            _burstAnim.value,
          );
        }
        // The next level stays shut until the marker arrives.
        if (_progression.value < 0.8) return node(MapNodeState.locked, 1, 0);
        final t = ((_progression.value - 0.8) / 0.2).clamp(0.0, 1.0);
        return node(controller.nodeState(lvl), _unlockAnim.value, t);
      },
    );
  }

  Widget _buildMarker(LevelMapLayout layout) {
    return AnimatedBuilder(
      animation: Listenable.merge([_scroll, _progression, _ambient]),
      builder: (context, _) {
        final p = _markerPoint(layout);
        final screenY = _viewportHeight - (p.dy - _offset);
        if (screenY < -120 || screenY > _viewportHeight + 120) {
          return const SizedBox.shrink();
        }
        final bob =
            -4 * (0.5 + 0.5 * math.sin(_ambient.value * math.pi * 2 * 30));
        return Stack(
          children: [
            Positioned(
              left: p.dx - PlayerAvatarMarker.size / 2,
              top: screenY - 84,
              child: PlayerAvatarMarker(bob: bob),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSummitCard(MapBiome biome) {
    final done = controller.isCampaignComplete;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(
          color: biome.accent.withValues(alpha: 0.6),
          width: 2,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            done ? Icons.emoji_events_rounded : Icons.flag_rounded,
            color: biome.accent,
            size: 28,
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  done ? AppStrings.campaignComplete : AppStrings.journeyEnd,
                  style: AppTextStyles.label,
                ),
                Text(
                  '${controller.completedCount}/${AppConstants.totalLevels} '
                  '${AppStrings.levelsCleared}',
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(EconomyService economy, LevelMapLayout layout) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.paddingOf(context).top + AppSpacing.sm,
        bottom: AppSpacing.md,
        left: AppSpacing.lg,
        right: AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(AppRadii.lg),
        ),
        boxShadow: AppShadows.soft,
      ),
      child: Row(
        children: [
          AppIconButton(
            icon: Icons.arrow_back_ios_new_rounded,
            tooltip: 'Back',
            onTap: () => Get.back(),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: ValueListenableBuilder<int>(
              valueListenable: _sectionInView,
              builder: (context, si, _) {
                final section =
                    layout.sections[si.clamp(0, layout.sections.length - 1)];
                final world = section.world;
                final biome = MapBiome.forWorld(world.number);
                final count = controller.worldLevelCount(world);
                final cleared = controller.worldClearedCount(world);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      AppStrings.levelMap,
                      maxLines: 1,
                      style: AppTextStyles.caption.copyWith(fontSize: 11),
                    ),
                    AnimatedSwitcher(
                      duration: AppDurations.base,
                      child: Text(
                        '${AppStrings.world} ${world.number} · ${biome.name}',
                        key: ValueKey(world.number),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.heading.copyWith(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              value: count == 0 ? 0 : cleared / count,
                              minHeight: 5,
                              backgroundColor: biome.accent.withValues(
                                alpha: 0.15,
                              ),
                              valueColor: AlwaysStoppedAnimation(biome.accent),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Obx(
                            () => Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(text: '$cleared/$count  '),
                                  const TextSpan(
                                    text: '★ ',
                                    style: TextStyle(color: AppColors.starGold),
                                  ),
                                  TextSpan(
                                    text: '${controller.totalStarsCount.value}',
                                  ),
                                ],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              semanticsLabel:
                                  '$cleared of $count cleared, '
                                  '${controller.totalStarsCount.value} stars',
                              style: AppTextStyles.caption.copyWith(
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Obx(() => CoinBadge(coins: economy.coins.value, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildNavControls(LevelMapLayout layout) {
    return ValueListenableBuilder<int>(
      valueListenable: _sectionInView,
      builder: (context, si, _) {
        final last = layout.sections.length - 1;
        return Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(AppRadii.pill),
            boxShadow: AppShadows.soft,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _NavButton(
                icon: Icons.keyboard_arrow_up_rounded,
                tooltip: AppStrings.nextWorld,
                onTap: si < last ? () => _scrollToSection(si + 1) : null,
              ),
              _NavButton(
                icon: Icons.my_location_rounded,
                tooltip: AppStrings.jumpToCurrent,
                onTap: _scrollToCurrent,
              ),
              _NavButton(
                icon: Icons.keyboard_arrow_down_rounded,
                tooltip: AppStrings.previousWorld,
                onTap: si > 0 ? () => _scrollToSection(si - 1) : null,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _NavButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  const _NavButton({required this.icon, required this.tooltip, this.onTap});

  @override
  Widget build(BuildContext context) => IconButton(
    icon: Icon(icon),
    tooltip: tooltip,
    onPressed: onTap,
    color: AppColors.accentBlue,
    disabledColor: AppColors.textHint.withValues(alpha: 0.5),
    constraints: const BoxConstraints.tightFor(
      width: kMinTouchTarget,
      height: kMinTouchTarget,
    ),
    padding: EdgeInsets.zero,
  );
}

class _MapChip extends StatelessWidget {
  final String label;
  final Color color;

  const _MapChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(AppRadii.pill),
      border: Border.all(color: Colors.white, width: 2),
    ),
    child: Text(
      label.toUpperCase(),
      style: const TextStyle(
        color: Colors.white,
        fontSize: 11,
        fontWeight: FontWeight.w900,
        letterSpacing: 1,
      ),
    ),
  );
}

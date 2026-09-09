import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:confetti/confetti.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../data/models/arrow_state.dart';
import '../../data/models/level_model.dart';
import '../../data/models/theme_model.dart';
import '../../game/renderer/arrow_board_widget.dart';
import '../../services/economy_service.dart';
import '../../widgets/coin_badge.dart';
import '../../widgets/difficulty_badge.dart';
import '../../widgets/heart_display.dart';
import 'gameplay_controller.dart';
import 'widgets/level_complete_dialog.dart';
import 'widgets/tutorial_overlay.dart';

class GameplayScreen extends StatefulWidget {
  const GameplayScreen({super.key});

  @override
  State<GameplayScreen> createState() => _GameplayScreenState();
}

class _GameplayScreenState extends State<GameplayScreen>
    with TickerProviderStateMixin {
  late GameplayController _controller;
  late ConfettiController _confetti;
  bool _dialogShown = false;
  bool _tutorialShown = false;
  late AnimationController _rewardController;

  @override
  void initState() {
    super.initState();
    _confetti = ConfettiController(duration: const Duration(seconds: 3));
    _rewardController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 620),
    );

    _controller = Get.isRegistered<GameplayController>()
        ? Get.find<GameplayController>()
        : Get.put(GameplayController());

    final args = Get.arguments;
    if (args is LevelModel) {
      _controller.loadLevelModel(args);
    } else if (args is int) {
      _controller.loadLevel(args);
    } else {
      _controller.loadLevel(1);
    }

    // Listen for level completion
    ever(_controller.isComplete, (bool done) {
      if (done && !_dialogShown) {
        _dialogShown = true;
        _confetti.play();
        Future.delayed(const Duration(milliseconds: 120), _showCompleteDialog);
      }
    });
    ever(_controller.isCompleting, (bool active) {
      if (active) _rewardController.forward(from: 0);
    });
  }

  @override
  void dispose() {
    _confetti.dispose();
    _rewardController.dispose();
    if (Get.isRegistered<GameplayController>()) {
      Get.delete<GameplayController>();
    }
    super.dispose();
  }

  void _showCompleteDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => LevelCompleteDialog(
        stars: _controller.calculatedStars,
        levelNumber: _controller.currentLevelNumber,
        moves: _controller.moves.value,
        onNextLevel: () {
          Get.back();
          _dialogShown = false;
          _controller.loadLevel(_controller.currentLevelNumber + 1);
        },
        onReplay: () {
          Get.back();
          _dialogShown = false;
          _controller.onReset();
        },
        onHome: () {
          Get.back();
          Get.offNamed('/home');
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final theme = _controller.theme;
      return _buildScaffold(theme);
    });
  }

  Widget _buildScaffold(ThemeModel theme) {
    return Scaffold(
      backgroundColor: theme.backgroundColor,
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: theme.backgroundGradient,
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),

          // Main content
          SafeArea(
            child: Column(
              children: [
                _buildTopBar(theme),
                _buildHUD(theme),
                const SizedBox(height: 8),
                _buildBoard(theme),
                const SizedBox(height: 12),
                _buildBottomBar(theme),
                const SizedBox(height: 16),
              ],
            ),
          ),

          // Confetti
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confetti,
              blastDirectionality: BlastDirectionality.explosive,
              colors: [
                AppColors.accentBlue,
                AppColors.accentPurple,
                AppColors.starGold,
                AppColors.success,
              ],
              emissionFrequency: 0.05,
              numberOfParticles: 20,
            ),
          ),

          // A few light coins travel from the board toward the counter during
          // the completion beat. This is intentionally compact and particle-free.
          IgnorePointer(
            child: AnimatedBuilder(
              animation: _rewardController,
              builder: (context, _) {
                final t = Curves.easeInOutCubic.transform(_rewardController.value);
                return Stack(
                  children: List.generate(3, (index) {
                    final stagger = (t - index * 0.11).clamp(0.0, 1.0);
                    final progress = Curves.easeOutCubic.transform(stagger);
                    return Positioned(
                      left: MediaQuery.of(context).size.width * (0.48 - progress * (0.18 + index * 0.035)),
                      top: MediaQuery.of(context).size.height * (0.53 - progress * (0.38 + index * 0.025)),
                      child: Opacity(
                        opacity: (1 - progress * 0.35) * (stagger > 0 ? 1 : 0),
                        child: const Icon(Icons.monetization_on_rounded,
                            color: AppColors.coinGold, size: 18),
                      ),
                    );
                  }),
                );
              },
            ),
          ),

          // Tutorial overlay
          if (!_tutorialShown &&
              _controller.isTutorialLevel.value &&
              !_controller.isComplete.value)
            TutorialOverlay(
              onDismiss: () {
                setState(() => _tutorialShown = true);
                _controller.markTutorialSeen();
              },
            ),
        ],
      ),
    );
  }

  Widget _buildTopBar(ThemeModel theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Back button
          GestureDetector(
            onTap: () => Get.back(),
            child: _HudButton(
              icon: Icons.arrow_back_ios_new_rounded,
              theme: theme,
            ),
          ),

          // Level number
          Obx(
            () => Text(
              '${AppStrings.level} ${_controller.currentLevelNumber}',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: theme.textColor,
              ),
            ),
          ),

          // Settings
          GestureDetector(
            onTap: () => Get.toNamed('/settings'),
            child: _HudButton(icon: Icons.settings_rounded, theme: theme),
          ),
        ],
      ),
    );
  }

  Widget _buildHUD(ThemeModel theme) {
    final economy = Get.find<EconomyService>();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Coins
          Obx(() => CoinBadge(coins: economy.coins.value, fontSize: 14)),

          // Difficulty badge
          Obx(
            () => _controller.arrows.isNotEmpty
                ? DifficultyBadge(difficulty: _controller.difficulty)
                : const SizedBox.shrink(),
          ),

          // Hearts
          Obx(() => HeartDisplay(lives: _controller.lives.value)),
        ],
      ),
    );
  }

  Widget _buildBoard(ThemeModel theme) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Obx(() {
          final visibleArrows = _controller.arrows
              .where((a) => a.state != ArrowState.removed)
              .toList();

          return ArrowBoardWidget(
            arrows: visibleArrows,
            gridSize: _controller.gridSize,
            theme: theme,
            hintedArrowId: _controller.hintedArrowId.value.isEmpty
                ? null
                : _controller.hintedArrowId.value,
            newlyAvailableArrowIds:
                _controller.newlyAvailableArrowIds.toSet(),
            hasEscapeInProgress:
                _controller.animatingArrowId.value.isNotEmpty,
            isCompleting: _controller.isCompleting.value,
            onArrowTap: _controller.onArrowTap,
          );
        }),
      ),
    );
  }

  Widget _buildBottomBar(ThemeModel theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Hint
          Obx(() {
            final economy = Get.find<EconomyService>();
            return _BottomActionButton(
              icon: Icons.lightbulb_rounded,
              label: 'Hint',
              badge: '${economy.hints.value}',
              color: Colors.amber,
              theme: theme,
              onTap: () {
                if (!_controller.onHint()) {
                  Get.snackbar(
                    'No Hints',
                    'Complete levels to earn more hints!',
                    duration: const Duration(seconds: 2),
                    snackPosition: SnackPosition.BOTTOM,
                  );
                }
              },
            );
          }),

          // Moves counter
          Obx(
            () => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${_controller.moves.value}',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: theme.textColor,
                  ),
                ),
                Text(
                  'moves',
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.textColor.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ),

          // Undo
          Obx(
            () => _BottomActionButton(
              icon: Icons.undo_rounded,
              label: 'Undo',
              color: AppColors.accentBlue,
              theme: theme,
              enabled: _controller.arrows.any(
                (a) => a.state == ArrowState.removed,
              ),
              onTap: _controller.onUndo,
            ),
          ),
        ],
      ),
    );
  }
}

class _HudButton extends StatelessWidget {
  final IconData icon;
  final ThemeModel theme;

  const _HudButton({required this.icon, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: theme.isDark
            ? Colors.white.withOpacity(0.1)
            : Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8),
        ],
      ),
      child: Icon(
        icon,
        color: theme.isDark ? Colors.white : AppColors.navyDark,
        size: 20,
      ),
    );
  }
}

class _BottomActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? badge;
  final Color color;
  final ThemeModel theme;
  final VoidCallback onTap;
  final bool enabled;

  const _BottomActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.theme,
    required this.onTap,
    this.badge,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Opacity(
        opacity: enabled ? 1.0 : 0.4,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: color.withOpacity(theme.isDark ? 0.2 : 0.1),
                    shape: BoxShape.circle,
                    border: Border.all(color: color.withOpacity(0.3)),
                  ),
                  child: Icon(icon, color: color, size: 26),
                ),
                if (badge != null)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        badge!,
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: theme.textColor.withOpacity(0.6),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

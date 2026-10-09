import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:confetti/confetti.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/theme/design_tokens.dart';
import '../../data/models/level_model.dart';
import '../../data/models/theme_model.dart';
import '../../game/config/difficulty_curve.dart';
import '../../game/renderer/arrow_board_widget.dart';
import '../../services/economy_service.dart';
import '../../widgets/app_icon_button.dart';
import '../../widgets/coin_badge.dart';
import '../../widgets/difficulty_badge.dart';
import '../../widgets/game_dialog.dart';
import '../../widgets/heart_display.dart';
import '../../widgets/pressable_scale.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/secondary_button.dart';
import '../settings/settings_controller.dart';
import 'gameplay_controller.dart';
import 'widgets/game_over_dialog.dart';
import 'widgets/hint_ad_dialog.dart';
import 'widgets/level_complete_dialog.dart';
import 'widgets/tutorial_overlay.dart';
import '../ads/ads_module.dart';

class GameplayScreen extends StatefulWidget {
  const GameplayScreen({super.key});

  @override
  State<GameplayScreen> createState() => _GameplayScreenState();
}

class _GameplayScreenState extends State<GameplayScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late GameplayController _controller;
  late ConfettiController _confetti;
  bool _dialogShown = false;
  bool _gameOverShown = false;
  late AnimationController _rewardController;
  final List<Worker> _workers = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
      // The daily screen has already loaded this board along with its date;
      // reloading would only repeat the work.
      if (!identical(_controller.currentLevel, args)) {
        _controller.loadLevelModel(args);
      }
    } else if (args is int) {
      _controller.loadLevel(args);
    } else {
      _controller.loadLevel(1);
    }

    _workers.addAll([
      ever(_controller.isComplete, (bool done) {
        if (done && !_dialogShown) {
          _dialogShown = true;
          _confetti.play();
          Future.delayed(
            const Duration(milliseconds: 120),
            _showCompleteDialog,
          );
        }
      }),
      ever(_controller.isCompleting, (bool active) {
        if (active) _rewardController.forward(from: 0);
      }),
      ever(_controller.isGameOver, (bool over) {
        if (over && !_gameOverShown) {
          _gameOverShown = true;
          Future.delayed(
            const Duration(milliseconds: 250),
            _showGameOverDialog,
          );
        }
      }),
    ]);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      _controller.saveCurrentGame();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    for (final w in _workers) {
      w.dispose();
    }
    _controller.saveCurrentGame();
    _confetti.dispose();
    _rewardController.dispose();
    if (Get.isRegistered<GameplayController>()) {
      Get.delete<GameplayController>();
    }
    super.dispose();
  }

  // ── Dialogs ───────────────────────────────────────────────────────────────

  void _showGameOverDialog() {
    if (!mounted) return;
    showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => GameOverDialog(
        levelNumber: _controller.currentLevelNumber,
        onRetry: () {
          Navigator.of(dialogContext).pop();
          _gameOverShown = false;
          _controller.onReset();
        },
        onHome: () {
          Navigator.of(dialogContext).pop();
          _gameOverShown = false;
          Get.offNamed('/home');
        },
        onWatchAd: () => _controller.watchAdContinue(),
      ),
    ).then((adWatched) {
      // If the dialog was dismissed via ad (pop(true)), reset the guard so
      // a subsequent game-over can show the dialog again.
      if (adWatched == true) _gameOverShown = false;
    });
  }

  void _showCompleteDialog() {
    if (!mounted) return;
    // Every button closes the dialog with `true`. A null result means the
    // system back button closed it, which would leave the finished, empty
    // board on screen, so back leaves the level instead.
    showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => LevelCompleteDialog(
        stars: _controller.calculatedStars,
        levelNumber: _controller.currentLevelNumber,
        moves: _controller.moves.value,
        coinsEarned: _controller.lastCoinsEarned,
        isDailyChallenge: _controller.isDailyChallenge.value,
        onNextLevel: () {
          Navigator.of(dialogContext).pop(true);
          _dialogShown = false;
          if (_controller.isDailyChallenge.value) {
            // There is no "next" daily; return to the daily screen.
            Get.back();
            return;
          }
          _controller.loadLevel(_controller.currentLevelNumber + 1);
        },
        onReplay: () {
          Navigator.of(dialogContext).pop(true);
          _dialogShown = false;
          _controller.onReset();
        },
        onHome: () {
          Navigator.of(dialogContext).pop(true);
          Get.offNamed('/home');
        },
      ),
    ).then((handled) {
      if (handled != true && mounted) {
        // Back to where the level was opened from (level map, home, daily).
        Navigator.of(context).maybePop();
      }
    });
  }

  void _showHintAdDialog() {
    showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) =>
          HintAdDialog(onWatchAd: () => _controller.watchAdForHint()),
    ).then((useNow) {
      if (useNow == true) {
        _controller.onHint();
      }
    });
  }

  Future<void> _confirmRestart() async {
    if (_controller.moves.value == 0 && _controller.mistakes.value == 0) {
      _controller.onReset();
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => GameDialog(
        icon: const DialogIcon(
          icon: Icons.refresh_rounded,
          color: AppColors.accentBlue,
        ),
        title: const Text('Restart level?'),
        message: const Text(
          'The board resets to its start and your hearts refill.',
        ),
        children: [
          PrimaryButton(
            label: 'Restart',
            icon: Icons.refresh_rounded,
            width: double.infinity,
            onTap: () => Navigator.of(ctx).pop(true),
          ),
          const SizedBox(height: AppSpacing.sm),
          SecondaryButton(
            label: AppStrings.cancel,
            textColor: AppColors.textSecondary,
            borderColor: AppColors.cardBorder,
            onTap: () => Navigator.of(ctx).pop(false),
          ),
        ],
      ),
    );
    if (ok == true) _controller.onReset();
  }

  void _openPauseMenu() {
    _controller.saveCurrentGame();
    final settings = Get.isRegistered<SettingsController>()
        ? Get.find<SettingsController>()
        : Get.put(SettingsController());
    final isDaily = _controller.isDailyChallenge.value;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        void close() => Navigator.of(sheetContext).pop();
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.all(AppSpacing.md),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.md,
              AppSpacing.xl,
              AppSpacing.xl,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadii.xl),
            ),
            child: SingleChildScrollView(
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
                  const SizedBox(height: AppSpacing.lg),
                  const Text(AppStrings.pause, style: AppTextStyles.title),
                  const SizedBox(height: AppSpacing.xs),
                  Text(_titleText(), style: AppTextStyles.caption),
                  const SizedBox(height: AppSpacing.lg),
                  PrimaryButton(
                    label: AppStrings.resume,
                    icon: Icons.play_arrow_rounded,
                    width: double.infinity,
                    onTap: close,
                  ),
                  const SizedBox(height: AppSpacing.sm + 2),
                  Row(
                    children: [
                      Expanded(
                        child: SecondaryButton(
                          label: 'Restart',
                          icon: Icons.refresh_rounded,
                          onTap: () {
                            close();
                            _confirmRestart();
                          },
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm + 2),
                      Expanded(
                        child: SecondaryButton(
                          label: AppStrings.howToPlay,
                          icon: Icons.help_outline_rounded,
                          onTap: () {
                            close();
                            _controller.showTutorial();
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Obx(
                    () => Column(
                      children: [
                        _PauseToggle(
                          icon: Icons.volume_up_rounded,
                          label: AppStrings.sound,
                          value: settings.settings.value.soundOn,
                          onChanged: (_) => settings.toggleSound(),
                        ),
                        _PauseToggle(
                          icon: Icons.vibration_rounded,
                          label: AppStrings.haptics,
                          value: settings.settings.value.hapticsOn,
                          onChanged: (_) => settings.toggleHaptics(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: SecondaryButton(
                          label: isDaily
                              ? AppStrings.dailyChallenge
                              : AppStrings.levelMap,
                          icon: isDaily
                              ? Icons.wb_sunny_rounded
                              : Icons.map_rounded,
                          textColor: AppColors.textSecondary,
                          borderColor: AppColors.cardBorder,
                          onTap: () {
                            close();
                            if (isDaily) {
                              Get.back();
                            } else {
                              Get.offNamed('/level-select');
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm + 2),
                      Expanded(
                        child: SecondaryButton(
                          label: AppStrings.home,
                          icon: Icons.home_rounded,
                          textColor: AppColors.textSecondary,
                          borderColor: AppColors.cardBorder,
                          onTap: () {
                            close();
                            Get.offNamed('/home');
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _titleText() {
    if (_controller.isDailyChallenge.value) {
      return AppStrings.dailyChallengeTitle;
    }
    final n = _controller.currentLevelNumber;
    final world = DifficultyCurve.worldFor(n);
    return 'World ${world.number} · ${world.name}';
  }

  // ── Layout ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final theme = _controller.theme;
      return PopScope(canPop: true, child: _buildScaffold(theme));
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
                const SizedBox(height: AppSpacing.xs),
                _buildBoard(theme),
                const SizedBox(height: AppSpacing.sm),
                _buildBottomBar(theme),
                const SizedBox(height: 8),
                const BannerAdWidget(),
                const SizedBox(height: 4),
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
          // the completion beat.
          IgnorePointer(
            child: AnimatedBuilder(
              animation: _rewardController,
              builder: (context, _) {
                if (_rewardController.value == 0) {
                  return const SizedBox.shrink();
                }
                final size = MediaQuery.sizeOf(context);
                final t = Curves.easeInOutCubic.transform(
                  _rewardController.value,
                );
                return Stack(
                  children: List.generate(3, (index) {
                    final stagger = (t - index * 0.11).clamp(0.0, 1.0);
                    final progress = Curves.easeOutCubic.transform(stagger);
                    return Positioned(
                      left:
                          size.width *
                          (0.48 - progress * (0.30 + index * 0.035)),
                      top:
                          size.height *
                          (0.53 - progress * (0.40 + index * 0.025)),
                      child: Opacity(
                        opacity: (1 - progress * 0.35) * (stagger > 0 ? 1 : 0),
                        child: const Icon(
                          Icons.monetization_on_rounded,
                          color: AppColors.coinGold,
                          size: 18,
                        ),
                      ),
                    );
                  }),
                );
              },
            ),
          ),

          // How-to-play overlay
          if (_controller.isTutorialLevel.value &&
              !_controller.isComplete.value)
            TutorialOverlay(onDismiss: _controller.dismissTutorial),
        ],
      ),
    );
  }

  Widget _buildTopBar(ThemeModel theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.xs,
      ),
      child: Row(
        children: [
          AppIconButton(
            icon: Icons.pause_rounded,
            tooltip: AppStrings.pause,
            onDark: theme.isDark,
            onTap: _openPauseMenu,
          ),
          Expanded(
            child: Obx(() {
              final isDaily = _controller.isDailyChallenge.value;
              final n = _controller.currentLevelNumber;
              final grid = _controller.isLoadingLevel.value
                  ? null
                  : _controller.gridSize;
              final shape = _controller.isLoadingLevel.value
                  ? null
                  : _controller.shapeName;
              final sub = grid == null
                  ? (isDaily ? '' : DifficultyCurve.worldFor(n).name)
                  : '${shape ?? (isDaily ? 'Daily board' : DifficultyCurve.worldFor(n).name)}'
                        '  ·  $grid×$grid';
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isDaily
                        ? AppStrings.dailyChallengeTitle
                        : '${AppStrings.level} $n',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.heading.copyWith(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: theme.textColor,
                    ),
                  ),
                  if (sub.isNotEmpty)
                    Text(
                      sub,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption.copyWith(
                        color: theme.textColor.withValues(alpha: 0.6),
                      ),
                    ),
                ],
              );
            }),
          ),
          Obx(
            () => _controller.isLoadingLevel.value
                ? const SizedBox(width: kMinTouchTarget)
                : DifficultyBadge(
                    difficulty: _controller.difficulty,
                    onDark: theme.isDark,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHUD(ThemeModel theme) {
    final economy = Get.find<EconomyService>();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Row(
        children: [
          Obx(() => CoinBadge(coins: economy.coins.value, fontSize: 14)),
          const SizedBox(width: AppSpacing.md),
          // Board progress: arrows cleared out of total.
          Expanded(
            child: Obx(() {
              final total = _controller.totalArrows;
              final cleared = _controller.clearedArrows;
              final value = total == 0 ? 0.0 : cleared / total;
              return Semantics(
                label: '$cleared of $total arrows cleared',
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(end: value),
                        duration: AppDurations.base,
                        builder: (_, v, _) => LinearProgressIndicator(
                          value: v,
                          minHeight: 6,
                          backgroundColor: theme.textColor.withValues(
                            alpha: 0.10,
                          ),
                          color: theme.accentColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      total == 0 ? ' ' : '$cleared / $total arrows',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.caption.copyWith(
                        fontSize: 11,
                        color: theme.textColor.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
          const SizedBox(width: AppSpacing.md),
          Obx(
            () => Semantics(
              label: '${_controller.displayHearts} hearts left',
              child: HeartDisplay(lives: _controller.displayHearts),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBoard(ThemeModel theme) {
    return Expanded(
      // Edge to edge: the picture already keeps a half-cell margin.
      child: Obx(() {
        if (_controller.isLoadingLevel.value) {
          return _LoadingBoard(theme: theme);
        }
        return ArrowBoardWidget(
          key: ValueKey(
            '${_controller.isDailyChallenge.value ? 'daily' : 'level'}_'
            '${_controller.currentLevelNumber}',
          ),
          arrows: _controller.arrows.toList(),
          gridSize: _controller.gridSize,
          theme: theme,
          hintedArrowId: _controller.hintedArrowId.value.isEmpty
              ? null
              : _controller.hintedArrowId.value,
          blockerArrowId: _controller.blockerArrowId.value.isEmpty
              ? null
              : _controller.blockerArrowId.value,
          newlyAvailableArrowIds: _controller.newlyAvailableArrowIds.toSet(),
          hasEscapeInProgress: _controller.animatingArrowId.value.isNotEmpty,
          isCompleting: _controller.isCompleting.value,
          shapeCells: _controller.shapeCells,
          onArrowTap: _controller.onArrowTap,
        );
      }),
    );
  }

  Widget _buildBottomBar(ThemeModel theme) {
    final economy = Get.find<EconomyService>();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      // Equal slots: on narrow phones the controls shrink to fit rather than
      // overflowing.
      child: Row(
        children: [
          for (final item in <Widget>[
            // Hint
            Obx(() {
              final hasHints = economy.hints.value > 0;
              return _BottomActionButton(
                icon: hasHints
                    ? Icons.lightbulb_rounded
                    : Icons.smart_display_rounded,
                label: hasHints ? AppStrings.hint : 'Free Hint',
                badge: hasHints ? '${economy.hints.value}' : 'Ad',
                color: AppColors.coinGold,
                theme: theme,
                enabled: !_controller.isLoadingLevel.value,
                onTap: () {
                  if (hasHints) {
                    _controller.onHint();
                  } else {
                    _showHintAdDialog();
                  }
                },
              );
            }),

            // Restart
            Obx(
              () => _BottomActionButton(
                icon: Icons.refresh_rounded,
                label: 'Restart',
                color: theme.isDark ? Colors.white : AppColors.navyMid,
                theme: theme,
                enabled:
                    !_controller.isLoadingLevel.value &&
                    (_controller.moves.value > 0 ||
                        _controller.mistakes.value > 0),
                onTap: _confirmRestart,
              ),
            ),

            // Moves counter
            Obx(
              () => Semantics(
                label: '${_controller.moves.value} moves',
                child: Column(
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
                        color: theme.textColor.withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Undo
            Obx(
              () => _BottomActionButton(
                icon: Icons.undo_rounded,
                label: AppStrings.undo,
                color: AppColors.accentBlue,
                theme: theme,
                enabled: _controller.clearedArrows > 0,
                onTap: _controller.onUndo,
              ),
            ),
          ])
            Expanded(child: Center(child: item)),
        ],
      ),
    );
  }
}

class _LoadingBoard extends StatelessWidget {
  final ThemeModel theme;

  const _LoadingBoard({required this.theme});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: theme.accentColor,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Preparing level…',
            style: AppTextStyles.caption.copyWith(
              color: theme.textColor.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

class _PauseToggle extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _PauseToggle({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    // Own transparent Material so the tile's ink is not hidden by the sheet's
    // coloured background.
    return Material(
      type: MaterialType.transparency,
      child: SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        secondary: Icon(icon, color: AppColors.navyMid),
        title: Text(label, style: AppTextStyles.label),
        value: value,
        activeTrackColor: AppColors.accentBlue,
        onChanged: onChanged,
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
    return PressableScale(
      onTap: enabled ? onTap : null,
      pressedScale: 0.9,
      semanticLabel: badge == null ? label : '$label, $badge',
      child: AnimatedOpacity(
        duration: AppDurations.fast,
        opacity: enabled ? 1.0 : 0.4,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: theme.isDark ? 0.2 : 0.1),
                    shape: BoxShape.circle,
                    border: Border.all(color: color.withValues(alpha: 0.3)),
                  ),
                  child: Icon(icon, color: color, size: 26),
                ),
                if (badge != null)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      constraints: const BoxConstraints(
                        minWidth: 18,
                        minHeight: 18,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(10),
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
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 11,
                  color: theme.textColor.withValues(alpha: 0.65),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/app_strings.dart';
import '../../core/theme/design_tokens.dart';
import '../../widgets/app_icon_button.dart';
import '../../widgets/primary_button.dart';
import '../gameplay/gameplay_controller.dart';
import 'daily_challenge_controller.dart';

class DailyChallengeScreen extends StatelessWidget {
  const DailyChallengeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(DailyChallengeController());
    final now = DateTime.now();

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppGradients.daily),
        child: SafeArea(
          child: Column(
            children: [
              // App bar
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
                child: Row(
                  children: [
                    AppIconButton(
                      icon: Icons.arrow_back_ios_new_rounded,
                      tooltip: 'Back',
                      onDark: true,
                      onTap: () => Get.back(),
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          AppStrings.dailyChallengeTitle,
                          style: AppTextStyles.heading.copyWith(
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: kMinTouchTarget),
                  ],
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) => SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xxl,
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            children: [
                              const SizedBox(height: AppSpacing.lg),
                              Text(
                                '${_monthName(now.month)} ${now.day}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 36,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                '${now.year}',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.65),
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.xl),
                              Obx(() => _StreakCard(
                                    streak: controller.streak.value,
                                    isCompletedToday:
                                        controller.isCompletedToday.value,
                                  )),
                              const SizedBox(height: AppSpacing.lg),
                              Obx(() => _InfoRow(
                                    gridSize: controller.isChallengeLoading.value
                                        ? null
                                        : controller.challengeLevel?.gridSize,
                                    completed:
                                        controller.isCompletedToday.value,
                                  )),
                              const SizedBox(height: AppSpacing.md),
                              Text(
                                'One new puzzle every day, separate from your '
                                'campaign progress.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.7),
                                  fontSize: 13,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: AppSpacing.xl,
                            ),
                            child: Obx(() => _buildAction(controller)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAction(DailyChallengeController controller) {
    if (controller.isCompletedToday.value) {
      return Column(
        children: [
          const Icon(Icons.check_circle_rounded,
              color: Colors.greenAccent, size: 56),
          const SizedBox(height: AppSpacing.md),
          const Text(
            "Today's challenge complete!",
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Come back tomorrow to keep your streak going.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: 13,
            ),
          ),
          if (controller.challengeLevel != null) ...[
            const SizedBox(height: AppSpacing.lg),
            PrimaryButton(
              label: 'Play Again',
              subtitle: 'For fun — no extra rewards',
              backgroundColor: Colors.white,
              textColor: AppColors.dailyPurple,
              width: double.infinity,
              icon: Icons.replay_rounded,
              onTap: () => _launchChallenge(controller),
            ),
          ],
        ],
      );
    }
    if (controller.isChallengeLoading.value) {
      return const PrimaryButton(
        label: 'Preparing challenge…',
        onTap: null,
        loading: true,
        backgroundColor: Colors.white,
        textColor: AppColors.dailyPurple,
        width: double.infinity,
      );
    }
    if (controller.challengeLoadError.value.isNotEmpty) {
      return Column(
        children: [
          Text(
            controller.challengeLoadError.value,
            style: const TextStyle(color: Colors.white),
          ),
          const SizedBox(height: AppSpacing.md),
          PrimaryButton(
            label: 'Try Again',
            onTap: controller.retryChallengeLoad,
            backgroundColor: Colors.white,
            textColor: AppColors.dailyPurple,
            width: double.infinity,
            icon: Icons.refresh_rounded,
          ),
        ],
      );
    }
    return PrimaryButton(
      label: 'Start Challenge',
      onTap: () => _launchChallenge(controller),
      backgroundColor: Colors.white,
      textColor: AppColors.dailyPurple,
      width: double.infinity,
      icon: Icons.arrow_forward_rounded,
    );
  }

  void _launchChallenge(DailyChallengeController dc) {
    final level = dc.challengeLevel;
    if (level == null) return;
    final gc = Get.isRegistered<GameplayController>()
        ? Get.find<GameplayController>()
        : Get.put(GameplayController());
    gc.loadLevelModel(level, dailyDateKey: dc.todayKey);
    dc.watchCompletion(gc);
    Get.toNamed('/gameplay', arguments: level);
  }

  String _monthName(int month) {
    const months = [
      '',
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return months[month];
  }
}


class _InfoRow extends StatelessWidget {
  final int? gridSize;
  final bool completed;

  const _InfoRow({required this.gridSize, required this.completed});

  @override
  Widget build(BuildContext context) {
    Widget chip(IconData icon, String text) => Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(AppRadii.md),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.amber, size: 20),
              const SizedBox(width: 6),
              Text(
                text,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        );

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        chip(
          Icons.monetization_on_rounded,
          completed
              ? 'Reward collected'
              : '+${AppConstants.coinsDailyChallenge} coins',
        ),
        if (gridSize != null)
          chip(Icons.grid_4x4_rounded, '$gridSize×$gridSize board'),
      ],
    );
  }
}

class _StreakCard extends StatelessWidget {
  final int streak;
  final bool isCompletedToday;

  const _StreakCard({required this.streak, required this.isCompletedToday});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$streak day streak',
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(AppRadii.md),
          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🔥', style: TextStyle(fontSize: 32)),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$streak ${AppStrings.days}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  AppStrings.streak,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 13,
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

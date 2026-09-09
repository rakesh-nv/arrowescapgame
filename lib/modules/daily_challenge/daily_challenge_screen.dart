import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/app_strings.dart';
import '../../widgets/primary_button.dart';
import '../gameplay/gameplay_controller.dart';
import 'daily_challenge_controller.dart';

class DailyChallengeScreen extends StatelessWidget {
  const DailyChallengeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(DailyChallengeController());
    final now = DateTime.now();
    final monthName = _monthName(now.month);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF7C3AED), Color(0xFF4F46E5)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // App bar
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Get.back(),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.arrow_back_ios_new_rounded,
                            color: Colors.white, size: 18),
                      ),
                    ),
                    const Expanded(
                      child: Center(
                        child: Text(
                          AppStrings.dailyChallengeTitle,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 44),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              Text(
                '$monthName ${now.day}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                '${now.year}',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 16,
                ),
              ),

              const SizedBox(height: 24),

              Obx(() => _StreakCard(
                    streak: controller.streak.value,
                    isCompletedToday: controller.isCompletedToday.value,
                  )),

              const SizedBox(height: 24),

              Container(
                margin: const EdgeInsets.symmetric(horizontal: 32),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.monetization_on_rounded,
                        color: Colors.amber, size: 28),
                    const SizedBox(width: 8),
                    Text(
                      '+${AppConstants.coinsDailyChallenge} coins reward',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                child: Obx(() {
                  if (controller.isCompletedToday.value) {
                    return Column(
                      children: [
                        const Icon(Icons.check_circle_rounded,
                            color: Colors.greenAccent, size: 60),
                        const SizedBox(height: 12),
                        const Text(
                          "Today's challenge complete!",
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700),
                        ),
                      ],
                    );
                  }
                  return PrimaryButton(
                    label: 'Start Challenge',
                    onTap: () => _launchChallenge(controller),
                    backgroundColor: Colors.white,
                    textColor: const Color(0xFF7C3AED),
                    width: double.infinity,
                    icon: Icons.arrow_forward_rounded,
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _launchChallenge(DailyChallengeController dc) {
    final gc = Get.isRegistered<GameplayController>()
        ? Get.find<GameplayController>()
        : Get.put(GameplayController());
    gc.loadLevelModel(dc.challengeLevel);
    ever(gc.isComplete, (bool done) {
      if (done) dc.onChallengeComplete(gc.calculatedStars);
    });
    Get.toNamed('/gameplay', arguments: dc.challengeLevel);
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

class _StreakCard extends StatelessWidget {
  final int streak;
  final bool isCompletedToday;

  const _StreakCard({required this.streak, required this.isCompletedToday});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 32),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
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
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

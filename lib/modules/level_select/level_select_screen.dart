import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/app_strings.dart';
import '../../widgets/level_card.dart';
import 'level_select_controller.dart';

class LevelSelectScreen extends StatelessWidget {
  const LevelSelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(LevelSelectController());

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FF),
      body: SafeArea(
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
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.07),
                              blurRadius: 8)
                        ],
                      ),
                      child: const Icon(Icons.arrow_back_ios_new_rounded,
                          size: 18, color: AppColors.navyDark),
                    ),
                  ),
                  const Expanded(
                    child: Center(
                      child: Text(
                        AppStrings.levelSelect,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppColors.navyDark,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 44),
                ],
              ),
            ),

            // Worlds
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _WorldSection(
                    title: AppStrings.world1,
                    subtitle: AppStrings.world1Sub,
                    startLevel: AppConstants.easyLevelsStart,
                    endLevel: AppConstants.easyLevelsEnd,
                    color: AppColors.diffEasy,
                    controller: controller,
                  ),
                  _WorldSection(
                    title: AppStrings.world2,
                    subtitle: AppStrings.world2Sub,
                    startLevel: AppConstants.normalLevelsStart,
                    endLevel: AppConstants.normalLevelsEnd,
                    color: AppColors.diffNormal,
                    controller: controller,
                  ),
                  _WorldSection(
                    title: AppStrings.world3,
                    subtitle: AppStrings.world3Sub,
                    startLevel: AppConstants.hardLevelsStart,
                    endLevel: AppConstants.hardLevelsEnd,
                    color: AppColors.diffHard,
                    controller: controller,
                  ),
                  _WorldSection(
                    title: AppStrings.world4,
                    subtitle: AppStrings.world4Sub,
                    startLevel: AppConstants.expertLevelsStart,
                    endLevel: AppConstants.expertLevelsEnd,
                    color: AppColors.diffExpert,
                    controller: controller,
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WorldSection extends StatelessWidget {
  final String title;
  final String subtitle;
  final int startLevel;
  final int endLevel;
  final Color color;
  final LevelSelectController controller;

  const _WorldSection({
    required this.title,
    required this.subtitle,
    required this.startLevel,
    required this.endLevel,
    required this.color,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 20, bottom: 12),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 28,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navyDark,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 5,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 1,
          ),
          itemCount: endLevel - startLevel + 1,
          itemBuilder: (_, i) {
            final level = startLevel + i;
            return LevelCard(
              levelNumber: level,
              stars: controller.starsForLevel(level),
              isUnlocked: controller.isUnlocked(level),
              isCurrent: controller.isCurrent(level),
              onTap: () =>
                  Get.toNamed('/gameplay', arguments: level),
            );
          },
        ),
      ],
    );
  }
}

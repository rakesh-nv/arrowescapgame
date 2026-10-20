import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/theme/design_tokens.dart';
import '../../services/update/update_service.dart';
import 'update_prompts.dart';

/// Small Home-screen card for app updates: download progress, "ready to
/// install", or an available update the player postponed. Takes no space when
/// there is nothing to show. Also starts the session's update check a moment
/// after Home appears, so startup is never delayed by it.
class UpdateBanner extends StatefulWidget {
  const UpdateBanner({super.key});

  /// Delay before the automatic check, so Home is drawn and interactive first.
  static const Duration checkDelay = Duration(seconds: 2);

  @override
  State<UpdateBanner> createState() => _UpdateBannerState();
}

class _UpdateBannerState extends State<UpdateBanner> {
  @override
  void initState() {
    super.initState();
    if (!Get.isRegistered<UpdateService>() ||
        !Get.find<UpdateService>().isSupported) {
      return;
    }
    Future.delayed(UpdateBanner.checkDelay, () {
      if (mounted) UpdatePrompts.onHomeVisible();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<UpdateService>()) return const SizedBox.shrink();
    final service = Get.find<UpdateService>();
    if (!service.isSupported) return const SizedBox.shrink();

    return Obx(() {
      final status = service.status.value;
      final progress = service.downloadProgress.value;
      final Widget? card = switch (status) {
        UpdateStatus.downloading => _BannerCard(
            icon: Icons.downloading_rounded,
            color: AppColors.accentBlue,
            title: AppStrings.updateDownloading,
            trailingText:
                progress == null ? null : '${(progress * 100).round()}%',
            progress: progress,
            showProgress: true,
          ),
        UpdateStatus.downloaded => _BannerCard(
            icon: Icons.restart_alt_rounded,
            color: AppColors.success,
            title: AppStrings.updateReadyTitle,
            actionLabel: 'Restart',
            onAction: UpdatePrompts.showRestartDialog,
          ),
        UpdateStatus.installing => const _BannerCard(
            icon: Icons.system_update_rounded,
            color: AppColors.success,
            title: AppStrings.updateInstalling,
            showProgress: true,
          ),
        UpdateStatus.available when service.decision != null => _BannerCard(
            icon: Icons.system_update_rounded,
            color: service.isRequired
                ? AppColors.accentPurple
                : AppColors.accentBlue,
            title: service.isRequired
                ? AppStrings.updateRequiredTitle
                : AppStrings.updateAvailableTitle,
            actionLabel: 'Update',
            onAction: UpdatePrompts.showUpdateDialog,
          ),
        _ => null,
      };
      return AnimatedSize(
        duration: AppDurations.base,
        curve: Curves.easeOutCubic,
        child: card == null
            ? const SizedBox(width: double.infinity)
            : Padding(
                padding: const EdgeInsets.only(top: AppSpacing.md),
                child: card,
              ),
      );
    });
  }
}

class _BannerCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String? trailingText;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool showProgress;
  final double? progress;

  const _BannerCard({
    required this.icon,
    required this.color,
    required this.title,
    this.trailingText,
    this.actionLabel,
    this.onAction,
    this.showProgress = false,
    this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: color.withValues(alpha: 0.25)),
        boxShadow: AppShadows.soft,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.label.copyWith(fontSize: 14),
                ),
              ),
              if (trailingText != null)
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.xs),
                  child: Text(
                    trailingText!,
                    style: AppTextStyles.caption.copyWith(color: color),
                  ),
                ),
              if (actionLabel != null)
                TextButton(
                  onPressed: onAction,
                  style: TextButton.styleFrom(
                    foregroundColor: color,
                    minimumSize: const Size(64, kMinTouchTarget),
                    textStyle: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  child: Text(actionLabel!),
                ),
            ],
          ),
          if (showProgress)
            Padding(
              padding: const EdgeInsets.only(
                top: AppSpacing.xs,
                right: AppSpacing.xs,
                bottom: AppSpacing.xs,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadii.pill),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  color: color,
                  backgroundColor: color.withValues(alpha: 0.12),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/theme/design_tokens.dart';
import '../../widgets/app_icon_button.dart';
import '../../widgets/game_dialog.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/secondary_button.dart';
import '../gameplay/widgets/tutorial_overlay.dart';
import 'settings_controller.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static const _privacyUrl =
      'https://smooth-hyacinth-f03.notion.site/Privacy-Policy-for-Arrow-Escape-3d64cd92f5a880b18f15dcc5840c7380';

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(SettingsController());

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: SafeArea(
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
                    onTap: () => Get.back(),
                  ),
                  const Expanded(
                    child: Center(
                      child: Text(
                        AppStrings.settings,
                        style: AppTextStyles.heading,
                      ),
                    ),
                  ),
                  const SizedBox(width: kMinTouchTarget),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.page,
                  vertical: AppSpacing.md,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _SectionHeader('AUDIO & HAPTICS'),
                        _SettingsCard(
                          children: [
                            Obx(
                              () => _SwitchTile(
                                icon: Icons.volume_up_rounded,
                                iconColor: AppColors.accentBlue,
                                title: AppStrings.sound,
                                subtitle: 'Play sound effects during gameplay',
                                value: controller.settings.value.soundOn,
                                onChanged: (_) => controller.toggleSound(),
                              ),
                            ),
                            const _TileDivider(),
                            Obx(
                              () => _SwitchTile(
                                icon: Icons.vibration_rounded,
                                iconColor: const Color(0xFF06B6D4),
                                title: AppStrings.haptics,
                                subtitle: 'Vibrate on moves, blocked taps and wins',
                                value: controller.settings.value.hapticsOn,
                                onChanged: (_) => controller.toggleHaptics(),
                              ),
                            ),
                          ],
                        ),
                        const _SectionHeader('HELP'),
                        _SettingsCard(
                          children: [
                            _ActionTile(
                              icon: Icons.help_outline_rounded,
                              color: AppColors.accentPurple,
                              title: AppStrings.howToPlay,
                              subtitle: 'A 3-step refresher on the rules',
                              onTap: () => _showHowToPlay(context),
                            ),
                          ],
                        ),
                        const _SectionHeader('DATA'),
                        _SettingsCard(
                          children: [
                            _ActionTile(
                              icon: Icons.delete_forever_rounded,
                              color: AppColors.error,
                              title: AppStrings.resetProgress,
                              titleColor: AppColors.error,
                              subtitle: 'Reset all levels, stars and coins',
                              onTap: () => _showResetDialog(context, controller),
                            ),
                          ],
                        ),
                        const _SectionHeader('LEGAL'),
                        _SettingsCard(
                          children: [
                            _ActionTile(
                              icon: Icons.shield_rounded,
                              color: AppColors.accentBlue,
                              title: AppStrings.privacyPolicy,
                              subtitle: 'View our privacy policy',
                              trailing: Icons.open_in_new_rounded,
                              onTap: () async {
                                final uri = Uri.parse(_privacyUrl);
                                if (await canLaunchUrl(uri)) {
                                  await launchUrl(
                                    uri,
                                    mode: LaunchMode.externalApplication,
                                  );
                                }
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xxl),
                        const _AppInfo(),
                        const SizedBox(height: AppSpacing.xl),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showHowToPlay(BuildContext context) {
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      pageBuilder: (ctx, _, _) => Material(
        type: MaterialType.transparency,
        child: TutorialOverlay(onDismiss: () => Navigator.of(ctx).pop()),
      ),
    );
  }

  void _showResetDialog(BuildContext context, SettingsController controller) {
    showDialog(
      context: context,
      builder: (ctx) => GameDialog(
        icon: const DialogIcon(
          icon: Icons.warning_amber_rounded,
          color: AppColors.error,
        ),
        title: const Text(AppStrings.resetConfirmTitle),
        message: const Text(AppStrings.resetConfirmBody),
        children: [
          PrimaryButton(
            label: AppStrings.confirm,
            backgroundColor: AppColors.error,
            width: double.infinity,
            onTap: () {
              Navigator.of(ctx).pop();
              controller.resetProgress();
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          SecondaryButton(
            label: AppStrings.cancel,
            textColor: AppColors.textSecondary,
            borderColor: AppColors.cardBorder,
            onTap: () => Navigator.of(ctx).pop(),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        top: AppSpacing.lg,
        bottom: AppSpacing.sm + 2,
        left: AppSpacing.xs,
      ),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.textLight,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;

  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.md),
        boxShadow: AppShadows.soft,
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.md),
        child: Material(
          color: AppColors.surface,
          child: Column(children: children),
        ),
      ),
    );
  }
}

class _TileDivider extends StatelessWidget {
  const _TileDivider();

  @override
  Widget build(BuildContext context) => const Divider(
        height: 1,
        indent: 56,
        endIndent: 16,
        color: AppColors.surfaceMuted,
      );
}

class _TileIcon extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _TileIcon(this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: color, size: 22),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            _TileIcon(icon, iconColor),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTextStyles.label),
                  const SizedBox(height: 2),
                  Text(subtitle, style: AppTextStyles.caption),
                ],
              ),
            ),
            Switch.adaptive(
              value: value,
              activeTrackColor: AppColors.accentBlue,
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final Color? titleColor;
  final IconData trailing;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.titleColor,
    this.trailing = Icons.chevron_right_rounded,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: _TileIcon(icon, color),
      title: Text(
        title,
        style: AppTextStyles.label.copyWith(
          fontSize: 16,
          color: titleColor ?? AppColors.navyDark,
        ),
      ),
      subtitle: Text(subtitle, style: AppTextStyles.caption),
      trailing: Icon(trailing, color: titleColor ?? AppColors.textSecondary),
      onTap: onTap,
    );
  }
}

class _AppInfo extends StatelessWidget {
  const _AppInfo();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.navyDark, AppColors.accentBlue],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: AppShadows.glow(AppColors.accentBlue),
            ),
            child: const Icon(
              Icons.navigation_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          const Text(AppStrings.appName, style: AppTextStyles.label),
          const SizedBox(height: AppSpacing.xs),
          const Text(AppStrings.tagline, style: AppTextStyles.body),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'Version 1.0.0',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.textLight,
            ),
          ),
        ],
      ),
    );
  }
}

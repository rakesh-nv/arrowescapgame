import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/utils/format.dart';
import '../../data/models/theme_model.dart';
import '../../data/repositories/theme_repository.dart';
import '../../widgets/app_icon_button.dart';
import '../../widgets/coin_badge.dart';
import '../../widgets/game_dialog.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/secondary_button.dart';
import 'themes_controller.dart';
import 'widgets/theme_preview.dart';

class ThemesScreen extends StatelessWidget {
  const ThemesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(ThemesController());

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
                        AppStrings.themes,
                        style: AppTextStyles.heading,
                      ),
                    ),
                  ),
                  Obx(() => CoinBadge(
                        coins: controller.coins.value,
                        fontSize: 14,
                      )),
                ],
              ),
            ),

            Expanded(
              child: Obx(() {
                // Read every observable the cards depend on so they rebuild.
                final activeId = controller.activeThemeId.value;
                final _ = controller.unlockedThemeIds.length;
                final coins = controller.coins.value;
                return CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: _OwnedSummary(
                        owned: controller.ownedCount,
                        total: controller.allThemes.length,
                      ),
                    ),
                    for (final category in ThemeRepository.categories)
                      ..._categorySlivers(
                        context,
                        controller,
                        category,
                        activeId,
                        coins,
                      ),
                    const SliverToBoxAdapter(
                      child: SizedBox(height: AppSpacing.xl),
                    ),
                  ],
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _categorySlivers(
    BuildContext context,
    ThemesController controller,
    String category,
    String activeId,
    int coins,
  ) {
    final themes = ThemeRepository.byCategory(category);
    if (themes.isEmpty) return const [];
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.page,
            AppSpacing.lg,
            AppSpacing.page,
            AppSpacing.sm,
          ),
          child: Text(
            category.toUpperCase(),
            style: AppTextStyles.caption.copyWith(letterSpacing: 1.2),
          ),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        sliver: SliverGrid(
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 220,
            mainAxisSpacing: AppSpacing.md,
            crossAxisSpacing: AppSpacing.md,
            childAspectRatio: 0.74,
          ),
          delegate: SliverChildBuilderDelegate(
            (_, i) {
              final theme = themes[i];
              final unlocked = controller.isUnlocked(theme);
              return _ThemeCard(
                theme: theme,
                isActive: activeId == theme.id,
                isUnlocked: unlocked,
                canAfford: coins >= theme.coinsRequired,
                onTap: () => _onThemeTap(context, controller, theme),
              );
            },
            childCount: themes.length,
          ),
        ),
      ),
    ];
  }

  Future<void> _onThemeTap(
    BuildContext context,
    ThemesController controller,
    ThemeModel theme,
  ) async {
    if (controller.isActive(theme)) {
      _showMessage(context, '${theme.name} is already in use.');
      return;
    }
    if (controller.isUnlocked(theme)) {
      await controller.selectTheme(theme);
      if (context.mounted) {
        _showMessage(context, '${theme.name} applied.', success: true);
      }
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (_) => _UnlockDialog(
        theme: theme,
        controller: controller,
        onResult: (result) {
          if (!context.mounted) return;
          switch (result) {
            case ThemeUnlockResult.unlocked:
              _showMessage(
                context,
                '${theme.name} unlocked and applied!',
                success: true,
              );
            case ThemeUnlockResult.alreadyOwned:
              _showMessage(context, '${theme.name} applied.', success: true);
            case ThemeUnlockResult.insufficientCoins:
              _showMessage(
                context,
                'Not enough coins. You need '
                '${formatThousands(controller.coinsShort(theme))} more.',
                error: true,
              );
            case ThemeUnlockResult.busy:
              break;
          }
        },
      ),
    );
  }

  void _showMessage(
    BuildContext context,
    String text, {
    bool success = false,
    bool error = false,
  }) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: error
            ? AppColors.error
            : (success ? AppColors.success : AppColors.navyDark),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.sm),
        ),
        content: Row(
          children: [
            Icon(
              error
                  ? Icons.error_outline_rounded
                  : (success
                      ? Icons.check_circle_rounded
                      : Icons.info_outline_rounded),
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OwnedSummary extends StatelessWidget {
  final int owned;
  final int total;

  const _OwnedSummary({required this.owned, required this.total});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadii.lg),
          border: Border.all(color: AppColors.cardBorder),
          boxShadow: AppShadows.soft,
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.accentPurple.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadii.sm),
              ),
              child: const Icon(
                Icons.palette_rounded,
                color: AppColors.accentPurple,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$owned of $total themes owned',
                      style: AppTextStyles.label),
                  const SizedBox(height: 2),
                  const Text(
                    'Earn coins by clearing levels and daily challenges.',
                    style: AppTextStyles.caption,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemeCard extends StatelessWidget {
  final ThemeModel theme;
  final bool isActive;
  final bool isUnlocked;
  final bool canAfford;
  final VoidCallback onTap;

  const _ThemeCard({
    required this.theme,
    required this.isActive,
    required this.isUnlocked,
    required this.canAfford,
    required this.onTap,
  });

  String get _semanticsLabel {
    if (isActive) return '${theme.name} theme, in use';
    if (isUnlocked) return '${theme.name} theme, owned. Tap to apply';
    return '${theme.name} theme, locked, '
        '${formatThousands(theme.coinsRequired)} coins';
  }

  @override
  Widget build(BuildContext context) {
    final fg = theme.textColor;
    return Semantics(
      button: true,
      label: _semanticsLabel,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppDurations.base,
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: theme.backgroundGradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(AppRadii.lg),
            border: Border.all(
              color: isActive
                  ? theme.accentColor
                  : (theme.isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : AppColors.cardBorder),
              width: isActive ? 3 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: (isActive ? theme.accentColor : Colors.black)
                    .withValues(alpha: isActive ? 0.35 : 0.08),
                blurRadius: isActive ? 16 : 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Opacity(
                        opacity: isUnlocked ? 1 : 0.85,
                        child: ThemePreview(theme: theme),
                      ),
                    ),
                    Positioned(
                      top: 6,
                      right: 6,
                      child: _StatusBadge(
                        theme: theme,
                        isActive: isActive,
                        isUnlocked: isUnlocked,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  theme.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: fg,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  theme.tier.label,
                  style: TextStyle(
                    color: fg.withValues(alpha: 0.65),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              _CardAction(
                theme: theme,
                isActive: isActive,
                isUnlocked: isUnlocked,
                canAfford: canAfford,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final ThemeModel theme;
  final bool isActive;
  final bool isUnlocked;

  const _StatusBadge({
    required this.theme,
    required this.isActive,
    required this.isUnlocked,
  });

  @override
  Widget build(BuildContext context) {
    if (isUnlocked && !isActive) return const SizedBox.shrink();
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: isActive
            ? theme.accentColor
            : Colors.black.withValues(alpha: 0.45),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      child: Icon(
        isActive ? Icons.check_rounded : Icons.lock_rounded,
        color: Colors.white,
        size: 15,
      ),
    );
  }
}

/// Bottom row of a card: "In use", "Apply", or the exact unlock price.
class _CardAction extends StatelessWidget {
  final ThemeModel theme;
  final bool isActive;
  final bool isUnlocked;
  final bool canAfford;

  const _CardAction({
    required this.theme,
    required this.isActive,
    required this.isUnlocked,
    required this.canAfford,
  });

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color fg;
    final IconData icon;
    final String label;
    Gradient? gradient;

    if (isActive) {
      bg = theme.accentColor;
      fg = theme.accentColor.computeLuminance() > 0.5
          ? AppColors.navyDark
          : Colors.white;
      icon = Icons.check_circle_rounded;
      label = 'In use';
    } else if (isUnlocked) {
      bg = theme.isDark
          ? Colors.white.withValues(alpha: 0.16)
          : AppColors.navyDark.withValues(alpha: 0.08);
      fg = theme.textColor;
      icon = Icons.brush_rounded;
      label = theme.isFree ? 'Free · Apply' : 'Owned · Apply';
    } else if (canAfford) {
      bg = AppColors.coinGold;
      gradient = AppGradients.gold;
      fg = Colors.white;
      icon = Icons.lock_open_rounded;
      label = formatThousands(theme.coinsRequired);
    } else {
      bg = theme.isDark
          ? Colors.black.withValues(alpha: 0.35)
          : Colors.white.withValues(alpha: 0.85);
      fg = theme.isDark ? Colors.white : AppColors.navyDark;
      icon = Icons.lock_rounded;
      label = formatThousands(theme.coinsRequired);
    }

    final showCoin = !isUnlocked;
    return Container(
      height: 34,
      decoration: BoxDecoration(
        color: gradient == null ? bg : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 15, color: fg),
          const SizedBox(width: 5),
          if (showCoin) ...[
            Icon(
              Icons.monetization_on_rounded,
              size: 15,
              color: canAfford ? Colors.white : AppColors.coinGold,
            ),
            const SizedBox(width: 3),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: fg,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Confirms a purchase before any coins are taken.
class _UnlockDialog extends StatelessWidget {
  final ThemeModel theme;
  final ThemesController controller;
  final void Function(ThemeUnlockResult result) onResult;

  const _UnlockDialog({
    required this.theme,
    required this.controller,
    required this.onResult,
  });

  @override
  Widget build(BuildContext context) {
    return GameDialog(
      icon: const DialogIcon(
        icon: Icons.palette_rounded,
        color: AppColors.accentPurple,
      ),
      title: Text('Unlock ${theme.name}?'),
      message: Obx(() {
        final coins = controller.coins.value;
        final short = controller.coinsShort(theme);
        return Column(
          children: [
            SizedBox(
              height: 120,
              child: ThemePreview(theme: theme),
            ),
            const SizedBox(height: AppSpacing.md),
            _PriceRow(label: 'Price', value: theme.coinsRequired),
            _PriceRow(label: 'Your balance', value: coins),
            if (short == 0)
              _PriceRow(
                label: 'After unlock',
                value: coins - theme.coinsRequired,
                bold: true,
              )
            else ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                'You need ${formatThousands(short)} more coins. '
                'Clear levels and daily challenges to earn more.',
                style: AppTextStyles.body.copyWith(color: AppColors.error),
              ),
            ],
          ],
        );
      }),
      children: [
        Obx(() {
          final affordable = controller.canAfford(theme);
          final busy = controller.isPurchasing.value;
          return PrimaryButton(
            label: affordable
                ? 'Unlock for ${formatThousands(theme.coinsRequired)}'
                : 'Not enough coins',
            icon: affordable ? Icons.lock_open_rounded : Icons.lock_rounded,
            gradient: affordable ? AppGradients.gold : null,
            backgroundColor: affordable ? null : AppColors.textHint,
            width: double.infinity,
            loading: busy,
            onTap: affordable && !busy
                ? () async {
                    final navigator = Navigator.of(context);
                    final result = await controller.unlockTheme(theme);
                    if (result == ThemeUnlockResult.busy) return;
                    if (navigator.canPop()) navigator.pop();
                    onResult(result);
                  }
                : null,
          );
        }),
        const SizedBox(height: AppSpacing.sm),
        SecondaryButton(
          label: AppStrings.cancel,
          textColor: AppColors.textSecondary,
          borderColor: AppColors.cardBorder,
          onTap: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}

class _PriceRow extends StatelessWidget {
  final String label;
  final int value;
  final bool bold;

  const _PriceRow({
    required this.label,
    required this.value,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    final style = AppTextStyles.body.copyWith(
      color: AppColors.textPrimary,
      fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(label, style: AppTextStyles.body),
          const Spacer(),
          const Icon(
            Icons.monetization_on_rounded,
            color: AppColors.coinGold,
            size: 16,
          ),
          const SizedBox(width: 4),
          Text(formatThousands(value), style: style),
        ],
      ),
    );
  }
}

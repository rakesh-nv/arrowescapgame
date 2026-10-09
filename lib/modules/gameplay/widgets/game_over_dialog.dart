import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../widgets/game_dialog.dart';
import '../../../widgets/heart_display.dart';
import '../../../widgets/primary_button.dart';
import '../../../widgets/secondary_button.dart';

class GameOverDialog extends StatefulWidget {
  final int levelNumber;
  final VoidCallback onRetry;
  final VoidCallback onHome;
  /// Called when user taps "Watch Ad". Resolves to true if the ad was watched
  /// to the end (lives granted), false if it was skipped or unavailable.
  final Future<bool> Function() onWatchAd;

  const GameOverDialog({
    super.key,
    required this.levelNumber,
    required this.onRetry,
    required this.onHome,
    required this.onWatchAd,
  });

  @override
  State<GameOverDialog> createState() => _GameOverDialogState();
}

class _GameOverDialogState extends State<GameOverDialog> {
  bool _loadingAd = false;
  bool _adGranted = false;

  Future<void> _handleWatchAd() async {
    if (_loadingAd) return;
    setState(() => _loadingAd = true);
    final granted = await widget.onWatchAd();
    if (!mounted) return;
    if (granted) {
      setState(() {
        _adGranted = true;
        _loadingAd = false;
      });
      // Brief delay so the user sees the hearts refill, then close
      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted) Navigator.of(context).pop(true);
    } else {
      setState(() => _loadingAd = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No ad available right now. Try again later!'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GameDialog(
      icon: AnimatedSwitcher(
        duration: AppDurations.slow,
        child: _adGranted
            ? const DialogIcon(
                key: ValueKey('hearts_full'),
                icon: Icons.favorite_rounded,
                color: AppColors.success,
              )
            : const DialogIcon(
                key: ValueKey('hearts_empty'),
                icon: Icons.heart_broken_rounded,
                color: AppColors.error,
              ),
      ),
      title: AnimatedSwitcher(
        duration: AppDurations.base,
        child: Text(
          _adGranted ? 'Lives Restored!' : 'Out of Lives!',
          key: ValueKey(_adGranted),
        ),
      ),
      message: AnimatedSwitcher(
        duration: AppDurations.base,
        child: Text(
          _adGranted
              ? 'Your hearts are full again.\nKeep going and clear the board!'
              : 'That tap was blocked. Your progress on this board is kept '
                  'if you continue.',
          key: ValueKey(_adGranted),
        ),
      ),
      children: [
        AnimatedSwitcher(
          duration: AppDurations.slow,
          child: HeartDisplay(
            key: ValueKey(_adGranted),
            lives: _adGranted ? 3 : 0,
            maxLives: 3,
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        if (!_adGranted) ...[
          PrimaryButton(
            label: 'Continue  +♥',
            subtitle: 'Watch a short ad',
            icon: Icons.play_circle_filled_rounded,
            gradient: AppGradients.reward,
            loading: _loadingAd,
            width: double.infinity,
            onTap: _handleWatchAd,
          ),
          const SizedBox(height: AppSpacing.sm + 2),
          SecondaryButton(
            label: 'Restart Level',
            icon: Icons.refresh_rounded,
            onTap: _loadingAd ? null : widget.onRetry,
          ),
          const SizedBox(height: AppSpacing.sm + 2),
        ],
        SecondaryButton(
          label: 'Main Menu',
          icon: Icons.home_rounded,
          textColor: AppColors.textSecondary,
          borderColor: AppColors.cardBorder,
          onTap: _loadingAd ? null : widget.onHome,
        ),
      ],
    );
  }
}

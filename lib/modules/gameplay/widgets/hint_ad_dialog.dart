import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../widgets/game_dialog.dart';
import '../../../widgets/primary_button.dart';

/// Modal dialog shown when the user is out of hints (has used all 3 hints)
/// and offers watching a rewarded video ad to receive 1 hint.
class HintAdDialog extends StatefulWidget {
  final Future<bool> Function() onWatchAd;

  const HintAdDialog({
    super.key,
    required this.onWatchAd,
  });

  @override
  State<HintAdDialog> createState() => _HintAdDialogState();
}

class _HintAdDialogState extends State<HintAdDialog> {
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
    } else {
      setState(() => _loadingAd = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to load video ad. Check your connection and try again!'),
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
        duration: AppDurations.base,
        child: _adGranted
            ? const DialogIcon(
                key: ValueKey('granted_icon'),
                icon: Icons.check_circle_rounded,
                color: AppColors.success,
              )
            : const DialogIcon(
                key: ValueKey('hint_icon'),
                icon: Icons.lightbulb_rounded,
                color: AppColors.coinGold,
              ),
      ),
      title: Text(_adGranted ? '1 Hint Added!' : 'Need a Hint?'),
      message: Text(
        _adGranted
            ? 'You received 1 free hint! Would you like to reveal the next move now?'
            : 'You have used all 3 hints.\nWatch a short video ad to get 1 hint!',
      ),
      children: [
        if (_adGranted) ...[
          PrimaryButton(
            label: 'Use Hint Now',
            icon: Icons.lightbulb_rounded,
            gradient: AppGradients.reward,
            width: double.infinity,
            onTap: () => Navigator.of(context).pop(true),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(
              'Keep for Later',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ] else ...[
          PrimaryButton(
            label: 'Watch Ad (+1 Hint)',
            icon: Icons.play_circle_fill_rounded,
            gradient: AppGradients.reward,
            loading: _loadingAd,
            width: double.infinity,
            onTap: _handleWatchAd,
          ),
          const SizedBox(height: AppSpacing.sm),
          TextButton(
            onPressed:
                _loadingAd ? null : () => Navigator.of(context).pop(false),
            child: const Text(
              'Not Now',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

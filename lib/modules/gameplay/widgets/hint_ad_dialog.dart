import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

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

class _HintAdDialogState extends State<HintAdDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late Animation<double> _scaleAnim;
  bool _loadingAd = false;
  bool _adGranted = false;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnim = CurvedAnimation(
      parent: _animCtrl,
      curve: Curves.easeOutBack,
    );
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

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
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: ScaleTransition(
        scale: _scaleAnim,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Icon ──────────────────────────────────────────────────────
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _adGranted
                    ? Container(
                        key: const ValueKey('granted_icon'),
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check_circle_rounded,
                          color: AppColors.success,
                          size: 40,
                        ),
                      )
                    : Container(
                        key: const ValueKey('hint_icon'),
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.lightbulb_rounded,
                          color: Colors.amber,
                          size: 40,
                        ),
                      ),
              ),

              const SizedBox(height: 18),

              // ── Title ─────────────────────────────────────────────────────
              Text(
                _adGranted ? '1 Hint Added!' : 'Need a Hint?',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppColors.navyDark,
                  letterSpacing: -0.5,
                ),
              ),

              const SizedBox(height: 8),

              // ── Description ───────────────────────────────────────────────
              Text(
                _adGranted
                    ? 'You received 1 free hint! Would you like to reveal the next move now?'
                    : 'You have used all 3 hints.\nWatch a short video ad to get 1 hint!',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),

              const SizedBox(height: 24),

              // ── Actions ───────────────────────────────────────────────────
              if (_adGranted) ...[
                // Use hint right now
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.of(context).pop(true),
                    icon: const Icon(Icons.lightbulb_rounded, color: Colors.white, size: 20),
                    label: const Text(
                      'Use Hint Now',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber.shade700,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
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
                // Watch Ad Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _loadingAd ? null : _handleWatchAd,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber.shade700,
                      disabledBackgroundColor: Colors.amber.shade300,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _loadingAd
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.play_circle_fill_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Watch Ad (+1 Hint)',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: _loadingAd ? null : () => Navigator.of(context).pop(false),
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
          ),
        ),
      ),
    );
  }
}

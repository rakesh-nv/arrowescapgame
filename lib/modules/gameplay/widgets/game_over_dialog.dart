import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../widgets/heart_display.dart';

class GameOverDialog extends StatefulWidget {
  final int levelNumber;
  final VoidCallback onRetry;
  final VoidCallback onHome;
  /// Called when user taps "Watch Ad". Receives a callback the caller
  /// should invoke with [true] if the ad was successfully watched (grants
  /// 3 lives) or [false] if it was skipped/unavailable.
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

class _GameOverDialogState extends State<GameOverDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;
  bool _loadingAd = false;
  bool _adGranted = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _scaleAnim = CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
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
      // Brief delay so the user sees the heart fill-up animation, then close
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
    return Dialog(
      backgroundColor: Colors.transparent,
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
              // ── Icon ────────────────────────────────────────────────────
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                child: _adGranted
                    ? _CircleIcon(
                        key: const ValueKey('hearts_full'),
                        icon: Icons.favorite_rounded,
                        bg: AppColors.success.withValues(alpha: 0.13),
                        iconColor: AppColors.success,
                      )
                    : _CircleIcon(
                        key: const ValueKey('hearts_empty'),
                        icon: Icons.heart_broken_rounded,
                        bg: AppColors.error.withValues(alpha: 0.12),
                        iconColor: AppColors.error,
                      ),
              ),

              const SizedBox(height: 18),

              // ── Title ────────────────────────────────────────────────────
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Text(
                  _adGranted ? 'Lives Restored!' : 'Out of Lives!',
                  key: ValueKey(_adGranted),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppColors.navyDark,
                    letterSpacing: -0.5,
                  ),
                ),
              ),

              const SizedBox(height: 8),

              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Text(
                  _adGranted
                      ? 'You got 3 lives back!\nKeep going and clear all arrows!'
                      : 'You ran out of lives on this level.',
                  key: ValueKey(_adGranted),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // ── Hearts display ───────────────────────────────────────────
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                child: HeartDisplay(
                  key: ValueKey(_adGranted),
                  lives: _adGranted ? 3 : 0,
                  maxLives: 3,
                ),
              ),

              const SizedBox(height: 24),

              // ── Watch Ad button ──────────────────────────────────────────
              if (!_adGranted)
                _WatchAdButton(
                  loading: _loadingAd,
                  onTap: _handleWatchAd,
                ),

              if (!_adGranted) const SizedBox(height: 10),

              // ── Restart button ───────────────────────────────────────────
              if (!_adGranted)
                _ActionButton(
                  label: 'RESTART',
                  icon: Icons.refresh_rounded,
                  onTap: widget.onRetry,
                  primary: false,
                ),

              if (!_adGranted) const SizedBox(height: 10),

              // ── Main Menu ────────────────────────────────────────────────
              _ActionButton(
                label: 'MAIN MENU',
                icon: Icons.home_rounded,
                onTap: widget.onHome,
                primary: false,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Helper widgets ────────────────────────────────────────────────────────────

class _CircleIcon extends StatelessWidget {
  final IconData icon;
  final Color bg;
  final Color iconColor;

  const _CircleIcon({
    super.key,
    required this.icon,
    required this.bg,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 76,
      height: 76,
      decoration: BoxDecoration(shape: BoxShape.circle, color: bg),
      child: Center(child: Icon(icon, color: iconColor, size: 44)),
    );
  }
}

/// Watch Ad button — amber/gold gradient with play icon and loading indicator.
class _WatchAdButton extends StatefulWidget {
  final bool loading;
  final VoidCallback onTap;

  const _WatchAdButton({required this.loading, required this.onTap});

  @override
  State<_WatchAdButton> createState() => _WatchAdButtonState();
}

class _WatchAdButtonState extends State<_WatchAdButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _press;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _press = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _press, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _press.forward(),
      onTapUp: (_) {
        _press.reverse();
        if (!widget.loading) widget.onTap();
      },
      onTapCancel: () => _press.reverse(),
      child: AnimatedBuilder(
        animation: _scale,
        builder: (_, __) => Transform.scale(
          scale: _scale.value,
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 54),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.40),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: widget.loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.play_circle_filled_rounded,
                            color: Colors.white, size: 22),
                        SizedBox(width: 8),
                        Text(
                          'WATCH AD  +3 ♥',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Generic outlined/filled action button used for Restart / Main Menu.
class _ActionButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool primary;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.primary,
  });

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _press;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _press = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _press, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _press.forward(),
      onTapUp: (_) {
        _press.reverse();
        widget.onTap();
      },
      onTapCancel: () => _press.reverse(),
      child: AnimatedBuilder(
        animation: _scale,
        builder: (_, __) => Transform.scale(
          scale: _scale.value,
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 48),
            decoration: BoxDecoration(
              color: widget.primary ? AppColors.accentBlue : Colors.transparent,
              border: Border.all(
                color: AppColors.accentBlue.withValues(alpha: 0.35),
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  widget.icon,
                  color: widget.primary ? Colors.white : AppColors.accentBlue,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  widget.label,
                  style: TextStyle(
                    color: widget.primary ? Colors.white : AppColors.accentBlue,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

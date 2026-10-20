import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

/// Map pin that marks the player's position: a brand-coloured badge with the
/// game's arrow, above a small ground shadow. Purely decorative.
class PlayerAvatarMarker extends StatelessWidget {
  static const double size = 40;

  /// Vertical bob offset (pixels, up is negative).
  final double bob;

  const PlayerAvatarMarker({super.key, this.bob = 0});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size + 18,
      child: Stack(
        alignment: Alignment.topCenter,
        clipBehavior: Clip.none,
        children: [
          Positioned(
            bottom: 0,
            child: Container(
              width: 18 - bob.abs() * 0.8,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          Positioned(
            top: bob,
            child: Column(
              children: [
                Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2563EB), Color(0xFF6C63FF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accentBlue.withValues(alpha: 0.35),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.navigation_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                CustomPaint(size: const Size(14, 8), painter: _PinTipPainter()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PinTipPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      Path()
        ..moveTo(0, 0)
        ..lineTo(size.width, 0)
        ..lineTo(size.width / 2, size.height)
        ..close(),
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

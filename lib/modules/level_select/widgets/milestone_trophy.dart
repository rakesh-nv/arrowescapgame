import 'package:flutter/material.dart';

import '../../../core/constants/app_strings.dart';
import '../../../widgets/pressable_scale.dart';
import '../level_select_controller.dart';

/// Trophy beside each world's last level. Grey until the world is cleared,
/// bronze when every level is cleared, gold when every level has 3 stars.
/// It is a progress marker only and never awards currency.
class MilestoneTrophy extends StatelessWidget {
  static const double size = 52;

  final WorldTrophy trophy;
  final VoidCallback onTap;

  const MilestoneTrophy({super.key, required this.trophy, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final (colors, icon) = switch (trophy) {
      WorldTrophy.none => (
        const [Color(0xFFE2E8F0), Color(0xFF94A3B8)],
        const Color(0xFF64748B),
      ),
      WorldTrophy.bronze => (
        const [Color(0xFFF3C08A), Color(0xFFB4693A)],
        Colors.white,
      ),
      WorldTrophy.gold => (
        const [Color(0xFFFFE58A), Color(0xFFF59E0B)],
        Colors.white,
      ),
    };
    return PressableScale(
      onTap: onTap,
      semanticLabel: AppStrings.worldTrophy,
      child: SizedBox(
        width: size,
        height: size + 8,
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            Positioned(
              bottom: 0,
              child: Container(
                width: size * 0.8,
                height: 10,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: colors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(color: Colors.white, width: 3),
              ),
              child: Icon(
                trophy == WorldTrophy.none
                    ? Icons.emoji_events_outlined
                    : Icons.emoji_events_rounded,
                color: icon,
                size: 28,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

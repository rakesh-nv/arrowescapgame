import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import '../core/theme/design_tokens.dart';

/// Displays coin count with gold icon — used in HUD and home screen
class CoinBadge extends StatelessWidget {
  final int coins;
  final double fontSize;

  const CoinBadge({super.key, required this.coins, this.fontSize = 16});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$coins coins',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          gradient: AppGradients.gold,
          borderRadius: BorderRadius.circular(AppRadii.pill),
          boxShadow: AppShadows.glow(AppColors.coinGold),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.monetization_on_rounded,
                color: Colors.white, size: 18),
            const SizedBox(width: 5),
            Text(
              coins.toString(),
              style: TextStyle(
                color: Colors.white,
                fontSize: fontSize,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

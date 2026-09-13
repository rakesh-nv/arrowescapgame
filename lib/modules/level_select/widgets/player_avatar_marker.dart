import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class PlayerAvatarMarker extends StatelessWidget {
  final Offset position;

  const PlayerAvatarMarker({
    super.key,
    required this.position,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: position.dx - 18,
      top: position.dy - 44, // Positioned right above node center
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [Color(0xFF2563EB), Color(0xFF6C63FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: Colors.white, width: 2.5),
          boxShadow: [
            BoxShadow(
              color: AppColors.accentBlue.withOpacity(0.4),
              blurRadius: 10,
              spreadRadius: 2,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: const Center(
          child: Icon(
            Icons.navigation_rounded,
            color: Colors.white,
            size: 18,
          ),
        ),
      ),
    );
  }
}

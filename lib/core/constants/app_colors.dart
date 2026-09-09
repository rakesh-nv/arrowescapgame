import 'package:flutter/material.dart';

/// App color palette for Arrow Escape
class AppColors {
  AppColors._();

  // --- Classic Theme (default) ---
  static const Color backgroundLight = Color(0xFFF5F7FF);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color cardBorder = Color(0xFFE8ECF4);

  static const Color navyDark = Color(0xFF1A2340);
  static const Color navyMid = Color(0xFF243055);
  static const Color accentBlue = Color(0xFF2563EB);
  static const Color accentPurple = Color(0xFF6C63FF);
  static const Color accentBlueLight = Color(0xFF60A5FA);

  static const Color arrowNormal = Color(0xFF1A2340);
  static const Color arrowSelected = Color(0xFF2563EB);
  static const Color arrowAvailable = Color(0xFF1A2340);
  static const Color arrowBlocked = Color(0xFF94A3B8);
  static const Color arrowEscaping = Color(0xFF2563EB);

  static const Color heartFull = Color(0xFFEF4444);
  static const Color heartEmpty = Color(0xFFE2E8F0);

  static const Color coinGold = Color(0xFFF59E0B);
  static const Color coinGoldDark = Color(0xFFD97706);

  static const Color textPrimary = Color(0xFF1A2340);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textHint = Color(0xFF94A3B8);
  static const Color textLight = Color(0xFF94A3B8);

  static const Color success = Color(0xFF10B981);
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);

  static const Color starGold = Color(0xFFFBBF24);
  static const Color starEmpty = Color(0xFFE2E8F0);

  // Difficulty colors
  static const Color diffEasy = Color(0xFF10B981);
  static const Color diffNormal = Color(0xFF2563EB);
  static const Color diffHard = Color(0xFFF59E0B);
  static const Color diffExpert = Color(0xFFEF4444);
  static const Color diffExtreme = Color(0xFF7C3AED);

  // Gradient presets
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF2563EB), Color(0xFF6C63FF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient backgroundGradient = LinearGradient(
    colors: [Color(0xFFF5F7FF), Color(0xFFEEF2FF)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient goldGradient = LinearGradient(
    colors: [Color(0xFFFBBF24), Color(0xFFF59E0B)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // Ocean theme
  static const Color oceanBg = Color(0xFF0F2A3F);
  static const Color oceanSurface = Color(0xFF163650);
  static const Color oceanArrow = Color(0xFF00D4FF);
  static const Color oceanAccent = Color(0xFF00B4D8);

  // Forest theme
  static const Color forestBg = Color(0xFF0D2B1A);
  static const Color forestSurface = Color(0xFF143D25);
  static const Color forestArrow = Color(0xFF4ADE80);
  static const Color forestAccent = Color(0xFF16A34A);

  // Sunset theme
  static const Color sunsetBg = Color(0xFFFFF7ED);
  static const Color sunsetSurface = Color(0xFFFFFFFF);
  static const Color sunsetArrow = Color(0xFFEA580C);
  static const Color sunsetAccent = Color(0xFFF97316);

  // Night theme
  static const Color nightBg = Color(0xFF0A0E1A);
  static const Color nightSurface = Color(0xFF111827);
  static const Color nightArrow = Color(0xFF60A5FA);
  static const Color nightAccent = Color(0xFF3B82F6);
}

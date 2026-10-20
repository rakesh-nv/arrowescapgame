import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';

/// Price tier of a theme. The tier fixes the coin price, so every theme in a
/// tier costs the same.
enum ThemeTier {
  free(0, 'Free'),
  entry(AppConstants.themePriceEntry, 'Entry'),
  standard(AppConstants.themePriceStandard, 'Standard'),
  advanced(AppConstants.themePriceAdvanced, 'Advanced'),
  premium(AppConstants.themePricePremium, 'Premium'),
  rare(AppConstants.themePriceRare, 'Rare');

  final int price;
  final String label;
  const ThemeTier(this.price, this.label);
}

/// A visual theme for the game board and UI
class ThemeModel {
  final String id;
  final String name;
  final String category;
  final ThemeTier tier;
  final Color backgroundColor;
  final Color surfaceColor;
  final Color arrowColor;
  final Color accentColor;
  final Color textColor;
  final Color particleColor;
  final bool isDark;
  final List<Color> backgroundGradient;

  /// Arrowhead colour; the body colour when null.
  final Color? headColor;

  /// Tint of the panel drawn behind the board; no panel when null.
  final Color? boardColor;

  /// Colour of the grid dots; a faded [textColor] when null.
  final Color? dotColor;

  /// When set, idle arrows take a colour from this list (stable per arrow)
  /// instead of [arrowColor].
  final List<Color>? arrowPalette;

  const ThemeModel({
    required this.id,
    required this.name,
    this.category = 'Classic',
    this.tier = ThemeTier.free,
    required this.backgroundColor,
    required this.surfaceColor,
    required this.arrowColor,
    required this.accentColor,
    required this.textColor,
    required this.particleColor,
    required this.isDark,
    required this.backgroundGradient,
    this.headColor,
    this.boardColor,
    this.dotColor,
    this.arrowPalette,
  });

  /// Coins needed to unlock; 0 = free.
  int get coinsRequired => tier.price;

  bool get isFree => coinsRequired == 0;

  Color get gridDotColor => dotColor ?? textColor.withValues(alpha: 0.32);

  /// Idle body colour for the arrow with [arrowId].
  Color arrowColorFor(String arrowId) {
    final palette = arrowPalette;
    if (palette == null || palette.isEmpty) return arrowColor;
    // Own hash: String.hashCode is not guaranteed stable between runs.
    var h = 0;
    for (final unit in arrowId.codeUnits) {
      h = (h * 31 + unit) & 0x7fffffff;
    }
    return palette[h % palette.length];
  }

  /// Arrowhead colour for an arrow whose body is [bodyColor].
  Color headColorFor(Color bodyColor) =>
      arrowPalette == null ? (headColor ?? bodyColor) : bodyColor;
}

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_strings.dart';
import '../core/theme/design_tokens.dart';
import '../services/play_games_service.dart';

/// "Hey there, [name] · Level [n]" pill on the Home screen, shown only to a
/// player signed in to Google Play Games. Guests (not signed in, offline,
/// Play Games unavailable) see nothing, and the space collapses.
/// [level] is the player's real campaign level, passed in by the screen.
class PlayerWelcomeBanner extends StatelessWidget {
  final int level;

  const PlayerWelcomeBanner({super.key, required this.level});

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<IPlayGamesService>()) return const SizedBox.shrink();
    final service = Get.find<IPlayGamesService>();
    return Obx(() {
      final player = service.player.value;
      if (service.status.value != PlayGamesStatus.signedIn || player == null) {
        return const SizedBox.shrink();
      }
      return Padding(
        padding: const EdgeInsets.only(top: AppSpacing.md),
        child: _Entrance(
          child: _Pill(level: level, player: player),
        ),
      );
    });
  }
}

class _Pill extends StatelessWidget {
  final int level;
  final PlayGamesPlayer player;

  const _Pill({required this.level, required this.player});

  @override
  Widget build(BuildContext context) {
    final name = player.displayName;
    final card = Container(
      padding: const EdgeInsets.fromLTRB(6, 6, 16, 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.mintLight, width: 1.2),
        boxShadow: AppShadows.soft,
      ),
      child: Row(
        children: [
          _Avatar(player: player),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    text: '${AppStrings.heyThere} ',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                    children: [
                      TextSpan(
                        text: name,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 15),
                ),
                const SizedBox(height: 3),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.mintLight,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${AppStrings.level} $level',
                    maxLines: 1,
                    style: const TextStyle(
                      color: AppColors.mintDark,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return Semantics(
      label: '${AppStrings.heyThere} $name. ${AppStrings.level} $level',
      excludeSemantics: true,
      child: card,
    );
  }
}

class _Avatar extends StatelessWidget {
  final PlayGamesPlayer? player;

  const _Avatar({this.player});

  static const double _size = 46;

  @override
  Widget build(BuildContext context) {
    final avatar = player?.avatar;
    final fallback = _Fallback(player: player);
    return Container(
      width: _size,
      height: _size,
      padding: const EdgeInsets.all(2.5),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [AppColors.mint, AppColors.mintDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: ClipOval(
        child: avatar == null
            ? fallback
            : Image.memory(
                avatar,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                cacheWidth: 128,
                errorBuilder: (_, _, _) => fallback,
              ),
      ),
    );
  }
}

/// Initial of a signed-in player without a picture, or a person icon for a
/// guest.
class _Fallback extends StatelessWidget {
  final PlayGamesPlayer? player;

  const _Fallback({this.player});

  @override
  Widget build(BuildContext context) {
    final name = player?.displayName.trim() ?? '';
    return ColoredBox(
      color: AppColors.mintLight,
      child: Center(
        child: name.isEmpty
            ? const Icon(
                Icons.person_rounded,
                color: AppColors.mintDark,
                size: 24,
              )
            : Text(
                name.characters.first.toUpperCase(),
                style: const TextStyle(
                  color: AppColors.mintDark,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
      ),
    );
  }
}

/// One subtle fade-and-rise when the banner first appears.
class _Entrance extends StatelessWidget {
  final Widget child;

  const _Entrance({required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
      child: child,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, (1 - t) * 10),
          child: child,
        ),
      ),
    );
  }
}

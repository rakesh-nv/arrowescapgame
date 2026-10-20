import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../widgets/pressable_scale.dart';
import '../level_select_controller.dart';

/// One level medallion on the map.
///
/// The widget is [width]×[height] with the medallion centred at
/// ([width]/2, [centerY]); place it with that anchor. Only the current
/// level listens to [pulse], so idle nodes never rebuild per frame.
class LevelMapNode extends StatelessWidget {
  static const double width = 92;
  static const double height = 112;
  static const double centerY = 52;

  final int levelNumber;
  final MapNodeState state;
  final int stars;
  final bool isBoss;
  final bool isChallenge;
  final bool darkGround;

  /// Looping 0→1 animation for the current level's halo.
  final Animation<double>? pulse;

  /// Extra scale used by the progression animation.
  final double scale;

  /// 0→1 burst ring shown when a level was just completed or unlocked.
  final double burst;

  final VoidCallback onTap;

  const LevelMapNode({
    super.key,
    required this.levelNumber,
    required this.state,
    required this.stars,
    required this.isBoss,
    required this.isChallenge,
    required this.onTap,
    this.darkGround = false,
    this.pulse,
    this.scale = 1,
    this.burst = 0,
  });

  bool get _current => state == MapNodeState.current;
  bool get _locked => state == MapNodeState.locked;

  double get _faceSize =>
      (isBoss
          ? 66.0
          : isChallenge
          ? 60.0
          : 54.0) +
      (_current ? 6 : 0);

  String get _semantics {
    final kind = isBoss
        ? '${AppStrings.bossLevel}, '
        : isChallenge
        ? '${AppStrings.challengeLevel}, '
        : '';
    final status = switch (state) {
      MapNodeState.locked => AppStrings.worldLocked,
      MapNodeState.current => AppStrings.play,
      MapNodeState.available => AppStrings.notCompletedYet,
      MapNodeState.completed => '$stars of 3 stars',
    };
    return '${AppStrings.level} $levelNumber, $kind$status';
  }

  @override
  Widget build(BuildContext context) {
    final size = _faceSize;
    final (faceColors, edge, textColor) = switch (state) {
      MapNodeState.completed => (
        const [Color(0xFFFFE08A), Color(0xFFF5A524)],
        const Color(0xFFB7791F),
        const Color(0xFF6B3F00),
      ),
      MapNodeState.current => (
        const [Color(0xFF3B82F6), Color(0xFF6C63FF)],
        const Color(0xFF1E3A8A),
        Colors.white,
      ),
      MapNodeState.available => (
        const [Colors.white, Color(0xFFDDE9FF)],
        const Color(0xFF93C5FD),
        AppColors.accentBlue,
      ),
      MapNodeState.locked =>
        darkGround
            ? (
                const [Color(0xFF52627A), Color(0xFF334155)],
                const Color(0xFF1E293B),
                const Color(0xFFCBD5E1),
              )
            : (
                const [Color(0xFFEDF1F7), Color(0xFFC9D3E0)],
                const Color(0xFF94A3B8),
                const Color(0xFF64748B),
              ),
    };
    final rim = isBoss
        ? const Color(0xFFFBBF24)
        : isChallenge
        ? const Color(0xFFA855F7)
        : Colors.white.withValues(alpha: _locked ? 0.7 : 1);

    final medallion = SizedBox(
      width: width,
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          if (_current && pulse != null)
            Positioned(
              top: centerY - size,
              child: IgnorePointer(
                child: RepaintBoundary(
                  child: CustomPaint(
                    size: Size(size * 2, size * 2),
                    painter: _HaloPainter(pulse!, AppColors.accentBlue),
                  ),
                ),
              ),
            ),
          if (burst > 0 && burst < 1)
            Positioned(
              top: centerY - size,
              child: IgnorePointer(
                child: CustomPaint(
                  size: Size(size * 2, size * 2),
                  painter: _BurstPainter(burst),
                ),
              ),
            ),
          // Ground shadow.
          Positioned(
            top: centerY + size / 2 - 2,
            child: Container(
              width: size * 0.95,
              height: 12,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: darkGround ? 0.35 : 0.16),
                borderRadius: BorderRadius.circular(size),
              ),
            ),
          ),
          // Raised edge (3D coin side).
          Positioned(
            top: centerY - size / 2 + 5,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(color: edge, shape: BoxShape.circle),
            ),
          ),
          // Face.
          Positioned(
            top: centerY - size / 2,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: faceColors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(
                  color: rim,
                  width: isBoss || isChallenge ? 3.5 : 3,
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Gloss.
                  Positioned(
                    top: size * 0.08,
                    child: Container(
                      width: size * 0.56,
                      height: size * 0.22,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(
                          alpha: _locked ? 0.25 : 0.35,
                        ),
                        borderRadius: BorderRadius.circular(size),
                      ),
                    ),
                  ),
                  Text(
                    '$levelNumber',
                    textScaler: TextScaler.noScaling,
                    style: TextStyle(
                      fontSize: levelNumber >= 100 ? 18 : 21,
                      fontWeight: FontWeight.w900,
                      color: textColor,
                      shadows: _current
                          ? const [
                              Shadow(
                                color: Color(0x55000000),
                                blurRadius: 3,
                                offset: Offset(0, 1),
                              ),
                            ]
                          : null,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_locked)
            Positioned(
              top: centerY + size / 2 - 18,
              left: width / 2 + size / 2 - 18,
              child: _Badge(
                color: darkGround
                    ? const Color(0xFF1E293B)
                    : const Color(0xFF64748B),
                icon: Icons.lock_rounded,
              ),
            ),
          if (isBoss)
            Positioned(
              top: centerY - size / 2 - 20,
              child: Icon(
                Icons.workspace_premium_rounded,
                size: 26,
                color: _locked
                    ? const Color(0xFFB0BAC8)
                    : const Color(0xFFFBBF24),
                shadows: const [
                  Shadow(
                    color: Color(0x44000000),
                    blurRadius: 2,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
            ),
          if (isChallenge && !isBoss)
            Positioned(
              top: centerY - size / 2 - 6,
              left: width / 2 + size / 2 - 16,
              child: _Badge(
                color: _locked
                    ? const Color(0xFF94A3B8)
                    : const Color(0xFFA855F7),
                icon: Icons.bolt_rounded,
              ),
            ),
          if (state == MapNodeState.completed)
            Positioned(
              top: centerY + size / 2 + 4,
              child: _StarRow(stars: stars),
            ),
          if (_current)
            Positioned(top: centerY + size / 2 + 6, child: const _PlayTag()),
        ],
      ),
    );

    return PressableScale(
      onTap: onTap,
      pressedScale: 0.9,
      semanticLabel: _semantics,
      child: scale == 1
          ? medallion
          : Transform.scale(scale: scale, child: medallion),
    );
  }
}

class _Badge extends StatelessWidget {
  final Color color;
  final IconData icon;

  const _Badge({required this.color, required this.icon});

  @override
  Widget build(BuildContext context) => Container(
    width: 22,
    height: 22,
    decoration: BoxDecoration(
      color: color,
      shape: BoxShape.circle,
      border: Border.all(color: Colors.white, width: 2),
    ),
    child: Icon(icon, size: 12, color: Colors.white),
  );
}

class _StarRow extends StatelessWidget {
  final int stars;

  const _StarRow({required this.stars});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
    decoration: BoxDecoration(
      color: const Color(0xCC1A2340),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 3; i++)
          Icon(
            Icons.star_rounded,
            size: 14,
            color: i < stars
                ? AppColors.starGold
                : Colors.white.withValues(alpha: 0.25),
          ),
      ],
    ),
  );
}

class _PlayTag extends StatelessWidget {
  const _PlayTag();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF10B981), Color(0xFF059669)],
      ),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.white, width: 1.5),
    ),
    child: Text(
      AppStrings.play.toUpperCase(),
      textScaler: TextScaler.noScaling,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 10,
        fontWeight: FontWeight.w900,
        letterSpacing: 1,
      ),
    ),
  );
}

/// Expanding ring around the current level.
class _HaloPainter extends CustomPainter {
  final Animation<double> pulse;
  final Color color;

  _HaloPainter(this.pulse, this.color) : super(repaint: pulse);

  @override
  void paint(Canvas canvas, Size size) {
    // The shared ambient loop is long; run the halo many times per loop.
    final t = (pulse.value * 24) % 1;
    final c = size.center(Offset.zero);
    final base = size.width / 4;
    canvas.drawCircle(
      c,
      base * (1.05 + 0.08 * math.sin(t * math.pi * 2)),
      Paint()..color = color.withValues(alpha: 0.18),
    );
    canvas.drawCircle(
      c,
      base * (1.0 + 0.9 * t),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = color.withValues(alpha: 0.55 * (1 - t)),
    );
  }

  @override
  bool shouldRepaint(covariant _HaloPainter old) => old.color != color;
}

/// Sparkle ring for the progression animation.
class _BurstPainter extends CustomPainter {
  final double t;

  _BurstPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 4 * (1 + t);
    final fade = 1 - t;
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4 * fade
        ..color = AppColors.starGold.withValues(alpha: fade),
    );
    final dot = Paint()..color = Colors.white.withValues(alpha: fade);
    for (var i = 0; i < 8; i++) {
      final a = i * math.pi / 4 + t;
      canvas.drawCircle(
        c + Offset(math.cos(a), math.sin(a)) * (r + 6),
        3 * fade + 1,
        dot,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BurstPainter old) => old.t != t;
}

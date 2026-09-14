import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class LevelMapNode extends StatefulWidget {
  final int levelNumber;
  final int stars;
  final bool isUnlocked;
  final bool isCurrent;
  final bool isCompleted;
  final bool isBoss;
  final bool isChallenge;
  final double scaleOverride;
  final bool showGlow;
  final VoidCallback onTap;

  const LevelMapNode({
    super.key,
    required this.levelNumber,
    required this.stars,
    required this.isUnlocked,
    required this.isCurrent,
    required this.isCompleted,
    required this.isBoss,
    required this.isChallenge,
    this.scaleOverride = 1.0,
    this.showGlow = false,
    required this.onTap,
  });

  @override
  State<LevelMapNode> createState() => _LevelMapNodeState();
}

class _LevelMapNodeState extends State<LevelMapNode>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _pulseAnim = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );

    if (widget.isCurrent) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant LevelMapNode oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isCurrent && !_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    } else if (!widget.isCurrent && _pulseController.isAnimating) {
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Node dimensions
    final double baseSize = widget.isBoss
        ? 68.0
        : widget.isCurrent
            ? 64.0
            : widget.isChallenge
                ? 58.0
                : 54.0;

    return Transform.scale(
      scale: widget.scaleOverride,
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          final scale = widget.isCurrent ? _pulseAnim.value : 1.0;
          return Transform.scale(
            scale: scale,
            child: GestureDetector(
              onTap: widget.isUnlocked ? widget.onTap : null,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  // 1. Outer Pulse Glow Ring (for Current Node or completion glow)
                  if (widget.isCurrent || widget.showGlow)
                    Container(
                      width: baseSize + 20,
                      height: baseSize + 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: (widget.isBoss
                                ? AppColors.coinGold
                                : AppColors.accentBlue)
                            .withOpacity(0.22),
                        boxShadow: [
                          BoxShadow(
                            color: (widget.isBoss
                                    ? AppColors.coinGold
                                    : AppColors.accentBlue)
                                .withOpacity(0.4),
                            blurRadius: 16,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                    ),

                  // 2. Main Node Container
                  Container(
                    width: baseSize,
                    height: baseSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: widget.isCurrent
                          ? (widget.isBoss
                              ? const LinearGradient(
                                  colors: [Color(0xFFFBBF24), Color(0xFFD97706)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                )
                              : AppColors.primaryGradient)
                          : widget.isCompleted
                              ? (widget.isBoss
                                  ? const LinearGradient(
                                      colors: [Color(0xFFFFFBEB), Color(0xFFFEF3C7)],
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                    )
                                  : const LinearGradient(
                                      colors: [Colors.white, Color(0xFFF8FAFC)],
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                    ))
                              : null,
                      color: !widget.isUnlocked ? const Color(0xFFE2E8F0) : null,
                      border: Border.all(
                        color: widget.isCurrent
                            ? Colors.white
                            : widget.isBoss
                                ? AppColors.coinGold
                                : widget.isCompleted
                                    ? AppColors.success
                                    : widget.isChallenge
                                        ? AppColors.accentPurple
                                        : const Color(0xFFCBD5E1),
                        width: widget.isCurrent || widget.isBoss ? 3.0 : 2.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: widget.isCurrent
                              ? AppColors.accentBlue.withOpacity(0.35)
                              : widget.isCompleted
                                  ? Colors.black.withOpacity(0.08)
                                  : Colors.black.withOpacity(0.03),
                          blurRadius: widget.isCurrent ? 12 : 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Center(
                      child: widget.isUnlocked
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Boss Crown/Star icon if boss level
                                if (widget.isBoss)
                                  const Icon(
                                    Icons.emoji_events_rounded,
                                    size: 16,
                                    color: AppColors.coinGoldDark,
                                  ),

                                Text(
                                  '${widget.levelNumber}',
                                  style: TextStyle(
                                    fontSize: widget.isBoss ? 20 : 18,
                                    fontWeight: FontWeight.w800,
                                    color: widget.isCurrent
                                        ? Colors.white
                                        : AppColors.navyDark,
                                  ),
                                ),
                              ],
                            )
                          : const Icon(
                              Icons.lock_rounded,
                              size: 20,
                              color: Color(0xFF94A3B8),
                            ),
                    ),
                  ),

                  // 3. Floating "PLAY" Badge above Current Node
                  if (widget.isCurrent)
                    Positioned(
                      top: -24,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF10B981), Color(0xFF059669)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.success.withOpacity(0.4),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Text(
                          'PLAY',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ),

                  // 4. Star Rating Badge under Completed Node
                  if (widget.isCompleted && widget.stars > 0)
                    Positioned(
                      bottom: -12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: List.generate(3, (i) {
                            return Icon(
                              i < widget.stars
                                  ? Icons.star_rounded
                                  : Icons.star_outline_rounded,
                              color: i < widget.stars
                                  ? AppColors.starGold
                                  : AppColors.starEmpty,
                              size: 11,
                            );
                          }),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

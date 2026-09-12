import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/constants/app_colors.dart';
import '../../data/models/theme_model.dart';
import '../../services/economy_service.dart';
import 'themes_controller.dart';

class ThemesScreen extends StatelessWidget {
  const ThemesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(ThemesController());
    final economy = Get.find<EconomyService>();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FF),
      body: SafeArea(
        child: Column(
          children: [
            // App bar
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Get.back(),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.07),
                              blurRadius: 8)
                        ],
                      ),
                      child: const Icon(Icons.arrow_back_ios_new_rounded,
                          size: 18, color: AppColors.navyDark),
                    ),
                  ),
                  const Expanded(
                    child: Center(
                      child: Text(
                        'Themes',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppColors.navyDark,
                        ),
                      ),
                    ),
                  ),
                  Obx(() => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFBBF24), Color(0xFFF59E0B)],
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.monetization_on_rounded,
                                color: Colors.white, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              '${economy.coins.value}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      )),
                ],
              ),
            ),

            // Theme grid
            Expanded(
              child: Obx(() {
                final activeId = controller.activeThemeId.value;
                final coins = economy.coins.value;
                return GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.9,
                  ),
                  itemCount: controller.allThemes.length,
                  itemBuilder: (_, i) {
                    final theme = controller.allThemes[i];
                    final isActive = activeId == theme.id;
                    final isUnlocked = theme.isFree;
                    return _ThemeCard(
                      theme: theme,
                      isActive: isActive,
                      isUnlocked: isUnlocked,
                      canAfford: coins >= theme.coinsRequired,
                      onTap: () => _onThemeTap(
                          context, controller, economy, theme, isUnlocked),
                    );
                  },
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  void _onThemeTap(
    BuildContext context,
    ThemesController controller,
    EconomyService economy,
    ThemeModel theme,
    bool isUnlocked,
  ) {
    if (isUnlocked) {
      controller.selectTheme(theme);
    } else {
      // Show unlock dialog
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Unlock ${theme.name}?'),
          content: Text(
              'This theme costs ${theme.coinsRequired} coins. You have ${economy.coins.value} coins.'),
          actions: [
            TextButton(
                onPressed: () => Get.back(), child: const Text('Cancel')),
            TextButton(
              onPressed: () async {
                final ok = await controller.unlockTheme(theme);
                Get.back();
                if (!ok) {
                  ScaffoldMessenger.of(Get.context!).showSnackBar(
                    const SnackBar(content: Text('Not enough coins!')),
                  );
                }
              },
              child: Text('Unlock (${theme.coinsRequired} coins)'),
            ),
          ],
        ),
      );
    }
  }
}

class _ThemeCard extends StatelessWidget {
  final ThemeModel theme;
  final bool isActive;
  final bool isUnlocked;
  final bool canAfford;
  final VoidCallback onTap;

  const _ThemeCard({
    required this.theme,
    required this.isActive,
    required this.isUnlocked,
    required this.canAfford,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: theme.backgroundGradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? theme.accentColor : Colors.transparent,
            width: 3,
          ),
          boxShadow: [
            BoxShadow(
              color: theme.accentColor.withOpacity(isActive ? 0.4 : 0.1),
              blurRadius: isActive ? 16 : 8,
            ),
          ],
        ),
        child: Stack(
          children: [
            // Preview arrows
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ArrowPreview(color: theme.arrowColor),
                  const SizedBox(height: 8),
                  _ArrowPreview(color: theme.accentColor, shorter: true),
                  const SizedBox(height: 8),
                  _ArrowPreview(color: theme.arrowColor.withOpacity(0.5)),
                  const Spacer(),
                  Text(
                    theme.name,
                    style: TextStyle(
                      color: theme.textColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (!isUnlocked)
                    Row(
                      children: [
                        const Icon(Icons.monetization_on_rounded,
                            color: Colors.amber, size: 14),
                        const SizedBox(width: 3),
                        Text(
                          '${theme.coinsRequired}',
                          style: TextStyle(
                            color: theme.textColor.withOpacity(0.8),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),

            // Active checkmark
            if (isActive)
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: theme.accentColor,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_rounded,
                      color: Colors.white, size: 18),
                ),
              ),

            // Lock overlay
            if (!isUnlocked)
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.4),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.lock_rounded,
                      color: Colors.white, size: 16),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ArrowPreview extends StatelessWidget {
  final Color color;
  final bool shorter;

  const _ArrowPreview({required this.color, this.shorter = false});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(shorter ? 60 : 90, 14),
      painter: _ArrowPreviewPainter(color: color),
    );
  }
}

class _ArrowPreviewPainter extends CustomPainter {
  final Color color;
  const _ArrowPreviewPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(size.width - 12, size.height / 2),
      p,
    );

    final hp = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(size.width, size.height / 2)
      ..lineTo(size.width - 12, size.height / 2 - 6)
      ..lineTo(size.width - 12, size.height / 2 + 6)
      ..close();
    canvas.drawPath(path, hp);
  }

  @override
  bool shouldRepaint(_ArrowPreviewPainter old) => old.color != color;
}

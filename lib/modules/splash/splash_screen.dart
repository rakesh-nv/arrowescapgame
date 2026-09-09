import 'package:flutter/material.dart';
import '../../core/constants/app_strings.dart';
import '../../data/repositories/progress_repository.dart';
import 'package:get/get.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _arrowController;
  late AnimationController _fadeController;
  late Animation<double> _arrowTranslate;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _arrowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fade = CurvedAnimation(parent: _fadeController, curve: Curves.easeIn);
    _arrowTranslate = Tween<double>(begin: -30, end: 60).animate(
      CurvedAnimation(parent: _arrowController, curve: Curves.easeInOut),
    );

    // Sequence: fade in title → animate arrow → navigate
    _fadeController.forward().then((_) {
      Future.delayed(const Duration(milliseconds: 300), () {
        _arrowController.forward().then((_) {
          _navigateNext();
        });
      });
    });
  }

  void _navigateNext() {
    final progress = Get.find<ProgressRepository>().progress;
    if (progress.hasSeenTutorial || progress.highestUnlockedLevel > 1) {
      Get.offNamed('/home');
    } else {
      Get.offNamed('/home');
    }
  }

  @override
  void dispose() {
    _arrowController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1A2340), Color(0xFF2563EB)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fade,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Animated arrow graphic
                AnimatedBuilder(
                  animation: _arrowTranslate,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(_arrowTranslate.value, 0),
                      child: child,
                    );
                  },
                  child: const _SplashArrow(),
                ),
                const SizedBox(height: 48),
                // Title
                const Text(
                  'ARROW',
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 8,
                  ),
                ),
                const Text(
                  'ESCAPE',
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF60A5FA),
                    letterSpacing: 8,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  AppStrings.tagline,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.6),
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SplashArrow extends StatelessWidget {
  const _SplashArrow();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(120, 40),
      painter: _SplashArrowPainter(),
    );
  }
}

class _SplashArrowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final bodyPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final headPaint = Paint()
      ..color = const Color(0xFF60A5FA)
      ..style = PaintingStyle.fill;

    // Body
    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(size.width - 20, size.height / 2),
      bodyPaint,
    );

    // Head
    final path = Path()
      ..moveTo(size.width, size.height / 2)
      ..lineTo(size.width - 20, size.height / 2 - 14)
      ..lineTo(size.width - 20, size.height / 2 + 14)
      ..close();
    canvas.drawPath(path, headPaint);
  }

  @override
  bool shouldRepaint(_SplashArrowPainter _) => false;
}

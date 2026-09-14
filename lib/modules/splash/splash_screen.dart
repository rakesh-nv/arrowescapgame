import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../services/app_initialization_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _arrowController;
  late Animation<double> _fade;
  late Animation<double> _arrowTranslate;

  InitializationProgress _initProgress = const InitializationProgress(
    progress: 0.05,
    statusText: 'Starting game...',
    step: InitStep.starting,
  );

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _arrowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _fade = CurvedAnimation(parent: _fadeController, curve: Curves.easeIn);
    _arrowTranslate = Tween<double>(begin: -20, end: 40).animate(
      CurvedAnimation(parent: _arrowController, curve: Curves.easeInOut),
    );

    _fadeController.forward();
    _arrowController.repeat(reverse: true);

    _startInitialization();
  }

  void _startInitialization() async {
    setState(() {
      _initProgress = const InitializationProgress(
        progress: 0.05,
        statusText: 'Starting game...',
        step: InitStep.starting,
      );
    });

    final success = await AppInitializationService.initialize(
      onProgress: (progress) {
        if (!mounted) return;
        setState(() {
          _initProgress = progress;
        });

        if (progress.step == InitStep.complete) {
          _onInitializationComplete();
        }
      },
    );

    if (!success && mounted) {
      // Ensure error state is reflected if initialize returns false without callback
      setState(() {
        _initProgress = const InitializationProgress(
          progress: 0.0,
          statusText: 'Unable to initialize game',
          step: InitStep.error,
          errorMessage: 'Storage or initialization service error',
        );
      });
    }
  }

  void _onInitializationComplete() {
    // Proceed immediately to Main Menu via fade transition
    if (mounted) {
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
    final isError = _initProgress.step == InitStep.error;

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
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(flex: 3),

                  // Animated Arrow Logo
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

                  const SizedBox(height: 36),

                  // Game Title
                  const Text(
                    'ARROW',
                    style: TextStyle(
                      fontSize: 44,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 8,
                    ),
                  ),
                  const Text(
                    'ESCAPE',
                    style: TextStyle(
                      fontSize: 44,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF60A5FA),
                      letterSpacing: 8,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    AppStrings.tagline,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.7),
                      letterSpacing: 0.5,
                    ),
                  ),

                  const Spacer(flex: 2),

                  // Loading / Error Card Section
                  if (isError) ...[
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.error.withOpacity(0.5),
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.error_outline_rounded,
                            color: Colors.white,
                            size: 36,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Unable to initialize game',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          if (_initProgress.errorMessage != null) ...[
                            const SizedBox(height: 6),
                            Text(
                              _initProgress.errorMessage!,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withOpacity(0.7),
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _startInitialization,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.accentBlue,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                            ),
                            icon: const Icon(Icons.refresh_rounded, size: 18),
                            label: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    // Progress Bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: _initProgress.progress,
                        minHeight: 8,
                        backgroundColor: Colors.white.withOpacity(0.2),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFF60A5FA),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _initProgress.statusText,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                  ],

                  const Spacer(flex: 1),
                ],
              ),
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

    final path = Path()
      ..moveTo(10, size.height / 2)
      ..lineTo(size.width - 24, size.height / 2);

    canvas.drawPath(path, bodyPaint);

    final headPath = Path()
      ..moveTo(size.width, size.height / 2)
      ..lineTo(size.width - 24, size.height / 2 - 14)
      ..lineTo(size.width - 20, size.height / 2)
      ..lineTo(size.width - 24, size.height / 2 + 14)
      ..close();

    canvas.drawPath(headPath, headPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

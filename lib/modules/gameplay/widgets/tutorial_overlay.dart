import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../widgets/primary_button.dart';

class TutorialOverlay extends StatefulWidget {
  final VoidCallback onDismiss;

  const TutorialOverlay({super.key, required this.onDismiss});

  @override
  State<TutorialOverlay> createState() => _TutorialOverlayState();
}

class _TutorialOverlayState extends State<TutorialOverlay>
    with SingleTickerProviderStateMixin {
  int _step = 0;

  final List<String> _steps = [
    AppStrings.tutorialStep1,
    AppStrings.tutorialStep2,
    AppStrings.tutorialStep3,
    AppStrings.tutorialStep4,
  ];

  final List<IconData> _icons = [
    Icons.search_rounded,
    Icons.touch_app_rounded,
    Icons.open_in_full_rounded,
    Icons.emoji_events_rounded,
  ];

  late AnimationController _controller;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..forward();
    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_step < _steps.length - 1) {
      setState(() => _step++);
    } else {
      widget.onDismiss();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: Container(
        color: Colors.black.withOpacity(0.7),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Step indicator
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _steps.length,
                      (i) => AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: i == _step ? 20 : 6,
                        height: 6,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          color: i == _step
                              ? AppColors.accentBlue
                              : AppColors.cardBorder,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Icon
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppColors.accentBlue.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _icons[_step],
                      color: AppColors.accentBlue,
                      size: 36,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Step number
                  Text(
                    'Step ${_step + 1} of ${_steps.length}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Instruction
                  Text(
                    _steps[_step],
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navyDark,
                      height: 1.4,
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Buttons
                  Row(
                    children: [
                      if (_step == 0)
                        Expanded(
                          child: TextButton(
                            onPressed: widget.onDismiss,
                            child: const Text(
                              AppStrings.skip,
                              style:
                                  TextStyle(color: AppColors.textSecondary),
                            ),
                          ),
                        ),
                      if (_step > 0) const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: PrimaryButton(
                          label: _step == _steps.length - 1
                              ? AppStrings.gotIt
                              : AppStrings.next,
                          onTap: _nextStep,
                          icon: _step == _steps.length - 1
                              ? Icons.check_rounded
                              : Icons.arrow_forward_rounded,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

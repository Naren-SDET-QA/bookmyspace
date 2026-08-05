import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/settings_controller.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/prototype_visuals.dart';

/// Brand splash matching prototype `#splash`:
/// gradient backdrop, pop-in logo, tagline and three bouncing dots.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key, this.duration = const Duration(milliseconds: 1900)});

  /// How long the splash stays before fading into the app.
  final Duration duration;

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..forward();
  late final Animation<double> _pop = CurvedAnimation(
    parent: _controller,
    // Pop at start (prototype `.logo { animation: pop .6s ... }`).
    curve: const Interval(0.0, 0.45, curve: Curves.easeOutBack),
  );
  late final Animation<double> _fadeIn = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.25, 1.0, curve: Curves.easeOut),
  );
  late final Animation<double> _slide = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.35, 1.0, curve: Curves.easeOutCubic),
  );

  Timer? _timer;
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.duration, _finish);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    if (!mounted) return;
    setState(() => _leaving = true);
    await Future<void>.delayed(const Duration(milliseconds: 450));
    if (!mounted) return;
    final onboardingDone = ref.read(onboardingProvider);
    context.go(onboardingDone ? AppRoutes.shell : AppRoutes.onboarding);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: PrototypeVisuals.splashGradient,
        ),
        child: AnimatedOpacity(
          opacity: _leaving ? 0 : 1,
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeOut,
          child: AnimatedScale(
            scale: _leaving ? 1.06 : 1,
            duration: const Duration(milliseconds: 450),
            curve: Curves.easeOut,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) => FadeTransition(
                opacity: _fadeIn,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.04),
                    end: Offset.zero,
                  ).animate(_slide),
                  child: child,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Prototype `#splash .logo` — 88×88, radius 26, 14% white.
                  ScaleTransition(
                    scale: _pop,
                    child: Container(
                      width: PrototypeVisuals.splashLogoSize,
                      height: PrototypeVisuals.splashLogoSize,
                      decoration: BoxDecoration(
                        color: PrototypeVisuals.splashLogoFill,
                        borderRadius: BorderRadius.circular(
                          PrototypeVisuals.splashLogoRadius,
                        ),
                        border: Border.all(
                          color: PrototypeVisuals.splashLogoBorder,
                          width: 1.5,
                        ),
                      ),
                      child: const Center(
                        child: Text(
                          '📍',
                          style: TextStyle(
                            fontSize: 42,
                            fontFamilyFallback: AppTheme.emojiFontFallbacks,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    'BookMySpace',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 27,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Discover · Book · Celebrate',
                    style: TextStyle(
                      color: PrototypeVisuals.splashSubtitle,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Prototype `#splash .ld` bouncing dots.
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(3, (i) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3.5),
                        child: _BounceDot(index: i),
                      );
                    }),
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

class _BounceDot extends StatefulWidget {
  const _BounceDot({required this.index});

  final int index;

  @override
  State<_BounceDot> createState() => _BounceDotState();
}

class _BounceDotState extends State<_BounceDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  )..repeat(reverse: true);
  late final Animation<double> _opacity = Tween<double>(begin: 0.3, end: 1)
      .animate(
        CurvedAnimation(
          parent: _controller,
          curve: Interval(
            (widget.index * 0.15).clamp(0.0, 0.7),
            (0.7 + widget.index * 0.15).clamp(0.7, 1.0),
            curve: Curves.easeInOut,
          ),
        ),
      );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

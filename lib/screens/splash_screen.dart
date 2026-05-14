import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Splash screen matching the React `motion` design:
/// - Gradient `from-[#0F6A3C]` → `to-[#0A4A27]` (top-left → bottom-right)
/// - Content: scale 0.5→1 + opacity 0→1 over 0.5s
/// - Hand: rotate 0→10→-10→10→0 over 1s, starts after 0.5s, repeats with 2s delay
/// - Footer: fade in after 1s delay
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  static const Color _greenStart = Color(0xFF0F6A3C);
  static const Color _greenEnd = Color(0xFF0A4A27);

  late final AnimationController _enterController;
  late final Animation<double> _enterScale;
  late final Animation<double> _enterOpacity;

  late final AnimationController _wiggleController;
  late final AnimationController _footerController;
  late final Animation<double> _footerOpacity;

  @override
  void initState() {
    super.initState();

    _enterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _enterScale = Tween<double>(begin: 0.5, end: 1).animate(
      CurvedAnimation(parent: _enterController, curve: Curves.easeOutCubic),
    );
    _enterOpacity = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _enterController, curve: Curves.easeOut));

    // One cycle = 1s wiggle + 2s hold at rest (repeatDelay: 2)
    _wiggleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );

    _footerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _footerOpacity = CurvedAnimation(
      parent: _footerController,
      curve: Curves.easeOut,
    );

    _enterController.forward();

    Future<void>.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      _wiggleController.repeat();
    });

    Future<void>.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      _footerController.forward();
    });
  }

  /// Rotation in degrees: 0→10→-10→10→0 over first third of [t] in 0..1
  double _handRotationRadians(double t) {
    const third = 1 / 3;
    if (t >= third) return 0;
    final u = t / third;
    double deg;
    if (u <= 0.25) {
      deg = _lerp(0, 10, u / 0.25);
    } else if (u <= 0.5) {
      deg = _lerp(10, -10, (u - 0.25) / 0.25);
    } else if (u <= 0.75) {
      deg = _lerp(-10, 10, (u - 0.5) / 0.25);
    } else {
      deg = _lerp(10, 0, (u - 0.75) / 0.25);
    }
    return deg * math.pi / 180;
  }

  double _lerp(double a, double b, double t) => a + (b - a) * t;

  @override
  void dispose() {
    _enterController.dispose();
    _wiggleController.dispose();
    _footerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_greenStart, _greenEnd],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: AnimatedBuilder(
              animation: Listenable.merge([
                _enterController,
                _wiggleController,
              ]),
              builder: (context, child) {
                return Opacity(
                  opacity: _enterOpacity.value,
                  child: Transform.scale(
                    scale: _enterScale.value,
                    child: child,
                  ),
                );
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedBuilder(
                    animation: _wiggleController,
                    builder: (context, _) {
                      return Transform.rotate(
                        angle: _handRotationRadians(_wiggleController.value),
                        child: const Padding(
                          padding: EdgeInsets.only(bottom: 24),
                          child: Text('✋', style: TextStyle(fontSize: 96)),
                        ),
                      );
                    },
                  ),
                  const Text(
                    'miliketapp',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Learn Ethiopian Sign Language',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'የኢትዮጵያ የምልክት ቋንቋ ይማሩ',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 40,
            child: FadeTransition(
              opacity: _footerOpacity,
              child: const Text(
                'Powered by Unity University',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0x99FFFFFF),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

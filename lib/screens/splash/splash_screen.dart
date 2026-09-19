import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../home/home_screen.dart';
import '../onboarding/language_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const _background = Color(0xff09090E);
  static const _red = Color(0xffC62828);
  static const _highlight = Color(0xffFFD166);

  late final AnimationController _controller;

  Timer? _navigationTimer;

  @override
  void initState() {
    super.initState();

    // --------------------------------------------------------
    // SPLASH TIMELINE
    //
    // 0 - 10 seconds  : loading
    // 10 - 12 seconds : 100% / READY hold
    // 12 - 15 seconds : slow transition to next screen
    //
    // Total splash time = 15 seconds
    // --------------------------------------------------------

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..forward();

    // Start the route transition exactly when the
    // 2-second READY hold is finished.
    _navigationTimer = Timer(
      const Duration(seconds: 12),
      _openNextScreen,
    );
  }

  Future<void> _openNextScreen() async {
    if (!mounted) {
      return;
    }

    final prefs =
        await SharedPreferences.getInstance();

    final firstLaunchCompleted =
        prefs.getBool(
              'bluff.first_launch_completed',
            ) ??
            false;

    if (!mounted) {
      return;
    }

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (
          context,
          animation,
          secondaryAnimation,
        ) =>
            firstLaunchCompleted
                ? const HomeScreen()
                : const LanguageScreen(),

        // ----------------------------------------------------
        // 3 SECOND SLOW FADE-IN
        // ----------------------------------------------------

        transitionDuration:
            const Duration(seconds: 3),

        reverseTransitionDuration:
            const Duration(milliseconds: 700),

        transitionsBuilder: (
          context,
          animation,
          secondaryAnimation,
          child,
        ) {
          final curvedAnimation =
              CurvedAnimation(
            parent: animation,
            curve: Curves.easeInOut,
          );

          return FadeTransition(
            opacity: curvedAnimation,
            child: child,
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _navigationTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: AnimatedBuilder(
        animation: _controller,
        builder: (
          context,
          child,
        ) {
          final time =
              _controller.value * 15.0;

          final progress =
              _loadingProgress(time);

          // --------------------------------------------------
          // SPLASH FADE OUT
          //
          // 0 - 12 seconds:
          // completely visible
          //
          // 12 - 15 seconds:
          // gradually fades to transparent
          // --------------------------------------------------

          final splashOpacity =
              time < 12.0
                  ? 1.0
                  : (1.0 -
                            ((time - 12.0) /
                                3.0))
                        .clamp(
                          0.0,
                          1.0,
                        );

          return Opacity(
            opacity: splashOpacity,
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter:
                        _AnimatedBackgroundPainter(
                      time: time,
                      red: _red,
                    ),
                  ),
                ),
                Center(
                  child: Column(
                    mainAxisSize:
                        MainAxisSize.min,
                    children: [
                      _buildLogo(time),
                      const SizedBox(
                        height: 55,
                      ),
                      _buildLoading(
                        progress,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  double _loadingProgress(
    double time,
  ) {
    if (time <= 0) {
      return 0;
    }

    // --------------------------------------------------------
    // FAST START
    // --------------------------------------------------------

    if (time < 1.3) {
      final t = time / 1.3;

      return Curves.easeOut.transform(t) *
          0.28;
    }

    // --------------------------------------------------------
    // SLOWS DOWN
    // --------------------------------------------------------

    if (time < 3.2) {
      final t =
          (time - 1.3) / 1.9;

      return 0.28 +
          Curves.easeInOut.transform(t) *
              0.14;
    }

    // --------------------------------------------------------
    // ALMOST STUCK
    // --------------------------------------------------------

    if (time < 5.5) {
      final t =
          (time - 3.2) / 2.3;

      return 0.42 +
          Curves.easeInOut.transform(t) *
              0.05;
    }

    // --------------------------------------------------------
    // SPEEDS UP AGAIN
    // --------------------------------------------------------

    if (time < 7.0) {
      final t =
          (time - 5.5) / 1.5;

      return 0.47 +
          Curves.easeOut.transform(t) *
              0.20;
    }

    // --------------------------------------------------------
    // SLOWS DOWN AGAIN
    // --------------------------------------------------------

    if (time < 8.8) {
      final t =
          (time - 7.0) / 1.8;

      return 0.67 +
          Curves.easeInOut.transform(t) *
              0.23;
    }

    // --------------------------------------------------------
    // FINAL PUSH TO 100%
    // --------------------------------------------------------

    if (time < 10.0) {
      final t =
          (time - 8.8) / 1.2;

      return 0.90 +
          Curves.easeOut.transform(t) *
              0.10;
    }

    // --------------------------------------------------------
    // 100% HOLD
    // --------------------------------------------------------

    return 1.0;
  }

  Widget _buildLogo(
    double time,
  ) {
    return Row(
      mainAxisSize:
          MainAxisSize.min,
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        const Text(
          'BLUFF',
          style: TextStyle(
            color: Colors.white,
            fontSize: 58,
            fontWeight:
                FontWeight.w900,
            letterSpacing: -3.5,
            height: 0.9,
          ),
        ),
        const SizedBox(
          width: 4,
        ),
        Transform.translate(
          offset:
              const Offset(0, -11),
          child: _buildFlag(time),
        ),
      ],
    );
  }

  Widget _buildFlag(
    double time,
  ) {
    return SizedBox(
      width: 55,
      height: 40,
      child: CustomPaint(
        painter:
            _WavingFlagPainter(
          time: time,
        ),
      ),
    );
  }

  Widget _buildLoading(
    double progress,
  ) {
    final percentage =
        (progress * 100)
            .round()
            .clamp(0, 100);

    return SizedBox(
      width: 280,
      child: Column(
        children: [
          Row(
            mainAxisAlignment:
                MainAxisAlignment
                    .spaceBetween,
            children: [
              const Text(
                'LOADING',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight:
                      FontWeight.w700,
                  letterSpacing: 2.2,
                ),
              ),
              Text(
                '$percentage%',
                style: const TextStyle(
                  color: _highlight,
                  fontSize: 12,
                  fontWeight:
                      FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(
            height: 10,
          ),
          ClipRRect(
            borderRadius:
                BorderRadius.circular(
              20,
            ),
            child: SizedBox(
              height: 6,
              child: Stack(
                children: [
                  Container(
                    width:
                        double.infinity,
                    color: Colors.white
                        .withValues(
                      alpha: 0.10,
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor:
                        progress,
                    child: Container(
                      decoration:
                          const BoxDecoration(
                        color: _red,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(
            height: 12,
          ),
          Text(
            _loadingMessage(
              progress,
            ),
            style: TextStyle(
              color: Colors.white
                  .withValues(
                alpha: 0.42,
              ),
              fontSize: 9,
              letterSpacing: 1.2,
              fontWeight:
                  FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _loadingMessage(
    double progress,
  ) {
    if (progress < 0.20) {
      return 'INITIALIZING';
    }

    if (progress < 0.40) {
      return 'PREPARING GAME';
    }

    if (progress < 0.55) {
      return 'CHECKING DATA';
    }

    if (progress < 0.75) {
      return 'LOADING ASSETS';
    }

    if (progress < 0.95) {
      return 'ALMOST READY';
    }

    if (progress < 1.0) {
      return 'FINISHING UP';
    }

    return 'READY';
  }
}


// ============================================================
// ANIMATED BACKGROUND
// ============================================================

class _AnimatedBackgroundPainter
    extends CustomPainter {
  final double time;
  final Color red;

  const _AnimatedBackgroundPainter({
    required this.time,
    required this.red,
  });

  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {
    final paint = Paint()
      ..isAntiAlias = true;

    // --------------------------------------------------------
    // Large soft red glow.
    // --------------------------------------------------------

    final center = Offset(
      size.width / 2,
      size.height * 0.38,
    );

    final radius =
        size.width * 0.75;

    paint.shader = RadialGradient(
      colors: [
        red.withValues(
          alpha: 0.13,
        ),
        red.withValues(
          alpha: 0.055,
        ),
        Colors.transparent,
      ],
    ).createShader(
      Rect.fromCircle(
        center: center,
        radius: radius,
      ),
    );

    canvas.drawCircle(
      center,
      radius,
      paint,
    );

    paint.shader = null;

    // --------------------------------------------------------
    // Animated fire-like particles.
    // --------------------------------------------------------

    for (int i = 0; i < 38; i++) {
      final seed = i * 2.731;

      final baseX =
          (math.sin(seed * 1.7) *
                      0.5 +
                  0.5) *
              size.width;

      final baseY =
          (math.cos(seed * 1.31) *
                      0.5 +
                  0.5) *
              size.height;

      final rising =
          (time *
                  (12 +
                      (i % 5) * 4)) %
              (size.height + 100);

      final x =
          baseX +
          math.sin(
                time * 0.8 +
                    seed,
              ) *
              18;

      final y =
          baseY -
          rising;

      final wrappedY =
          y < -30
              ? y +
                  size.height +
                  60
              : y;

      final flicker =
          (math.sin(
                        time * 4.0 +
                            seed,
                      ) +
                  1) /
              2;

      final opacity =
          0.08 +
          flicker * 0.20;

      final particleSize =
          0.8 +
          ((i % 4) * 0.55);

      paint.color =
          (i % 3 == 0
                  ? red
                  : Colors.white)
              .withValues(
        alpha: opacity,
      );

      canvas.drawCircle(
        Offset(
          x,
          wrappedY,
        ),
        particleSize,
        paint,
      );
    }

    // --------------------------------------------------------
    // Larger glowing embers.
    // --------------------------------------------------------

    for (int i = 0; i < 9; i++) {
      final seed = i * 4.13;

      final x =
          (math.sin(seed) *
                      0.5 +
                  0.5) *
              size.width;

      final baseY =
          size.height -
          ((seed * 71) %
              size.height);

      final y =
          baseY -
          ((time *
                  (20 + i * 3)) %
              (size.height + 100));

      final flicker =
          (math.sin(
                        time * 3.0 +
                            seed,
                      ) +
                  1) /
              2;

      final glowPaint = Paint()
        ..color = red.withValues(
          alpha:
              0.10 +
              flicker * 0.12,
        )
        ..maskFilter =
            const MaskFilter.blur(
          BlurStyle.normal,
          5,
        );

      canvas.drawCircle(
        Offset(x, y),
        3.5,
        glowPaint,
      );

      paint.color =
          red.withValues(
        alpha:
            0.35 +
            flicker * 0.25,
      );

      canvas.drawCircle(
        Offset(x, y),
        1.4,
        paint,
      );
    }

    // --------------------------------------------------------
    // Elegant curved energy strokes.
    // --------------------------------------------------------

    _drawEnergyCurve(
      canvas,
      size,
      time,
      -0.15,
      0.12,
      0.18,
    );

    _drawEnergyCurve(
      canvas,
      size,
      time,
      0.92,
      0.20,
      0.13,
    );

    _drawEnergyCurve(
      canvas,
      size,
      time,
      0.30,
      0.78,
      0.08,
    );
  }

  void _drawEnergyCurve(
    Canvas canvas,
    Size size,
    double time,
    double startX,
    double startY,
    double opacity,
  ) {
    final path = Path();

    final x =
        size.width * startX;

    final y =
        size.height * startY;

    final movement =
        math.sin(
              time * 0.7 +
                  startX * 8,
            ) *
            18;

    path.moveTo(
      x,
      y + movement,
    );

    path.cubicTo(
      x +
          size.width * 0.18,
      y -
          size.height * 0.10,
      x +
          size.width * 0.25,
      y +
          size.height * 0.16,
      x +
          size.width * 0.42,
      y + movement,
    );

    final paint = Paint()
      ..color = red.withValues(
        alpha: opacity,
      )
      ..style =
          PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..isAntiAlias = true;

    canvas.drawPath(
      path,
      paint,
    );
  }

  @override
  bool shouldRepaint(
    _AnimatedBackgroundPainter
        oldDelegate,
  ) {
    return oldDelegate.time !=
        time;
  }
}


// ============================================================
// SMOOTH WAVING BANGLADESH FLAG
// ============================================================

class _WavingFlagPainter
    extends CustomPainter {
  final double time;

  const _WavingFlagPainter({
    required this.time,
  });

  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {
    const green =
        Color(0xff006A4E);

    const red =
        Color(0xffF42A41);

    const samples = 100;

    final phase =
        time * math.pi * 2;

    final flagRect =
        Offset.zero & size;

    // --------------------------------------------------------
    // Smooth cloth shape.
    // --------------------------------------------------------

    final flagPath = Path();

    for (int i = 0;
        i <= samples;
        i++) {
      final t =
          i / samples;

      final x =
          size.width * t;

      final wave =
          _wave(
            t,
            phase,
          );

      if (i == 0) {
        flagPath.moveTo(
          x,
          wave,
        );
      } else {
        flagPath.lineTo(
          x,
          wave,
        );
      }
    }

    for (int i = samples;
        i >= 0;
        i--) {
      final t =
          i / samples;

      final x =
          size.width * t;

      final wave =
          _wave(
            t,
            phase,
          );

      flagPath.lineTo(
        x,
        size.height + wave,
      );
    }

    flagPath.close();

    canvas.save();

    canvas.clipPath(
      flagPath,
      doAntiAlias: true,
    );

    // --------------------------------------------------------
    // Green background.
    // --------------------------------------------------------

    final greenPaint = Paint()
      ..color = green
      ..isAntiAlias = true;

    canvas.drawRect(
      flagRect,
      greenPaint,
    );

    // --------------------------------------------------------
    // Red circle.
    // --------------------------------------------------------

    const circleT = 0.48;

    final circleWave =
        _wave(
          circleT,
          phase,
        );

    final circleCenter =
        Offset(
      size.width * circleT,
      size.height * 0.50 +
          circleWave * 0.72,
    );

    final circlePaint = Paint()
      ..color = red
      ..isAntiAlias = true;

    canvas.drawCircle(
      circleCenter,
      size.height * 0.30,
      circlePaint,
    );

    // --------------------------------------------------------
    // BD.
    // --------------------------------------------------------

    final textPainter =
        TextPainter(
      text: const TextSpan(
        text: 'BD',
        style: TextStyle(
          color: Colors.white,
          fontSize: 6.5,
          fontWeight:
              FontWeight.w900,
          letterSpacing: 0.25,
        ),
      ),
      textDirection:
          TextDirection.ltr,
    );

    textPainter.layout();

    final textRotation =
        math.sin(
              phase,
            ) *
            0.035;

    canvas.save();

    canvas.translate(
      circleCenter.dx,
      circleCenter.dy,
    );

    canvas.rotate(
      textRotation,
    );

    textPainter.paint(
      canvas,
      Offset(
        -textPainter.width / 2,
        -textPainter.height / 2,
      ),
    );

    canvas.restore();

    // --------------------------------------------------------
    // Subtle cloth shading.
    // --------------------------------------------------------

    final shadingPaint = Paint()
      ..shader = LinearGradient(
        begin:
            Alignment.centerLeft,
        end:
            Alignment.centerRight,
        colors: [
          Colors.black.withValues(
            alpha: 0.08,
          ),
          Colors.transparent,
          Colors.black.withValues(
            alpha: 0.05,
          ),
          Colors.transparent,
        ],
        stops: const [
          0.0,
          0.35,
          0.68,
          1.0,
        ],
      ).createShader(
        flagRect,
      );

    canvas.drawRect(
      flagRect,
      shadingPaint,
    );

    // --------------------------------------------------------
    // Smooth highlight.
    // --------------------------------------------------------

    final highlightPath = Path();

    for (int i = 0;
        i <= samples;
        i++) {
      final t =
          i / samples;

      final x =
          size.width * t;

      final wave =
          _wave(
            t,
            phase,
          );

      if (i == 0) {
        highlightPath.moveTo(
          x,
          wave + 0.5,
        );
      } else {
        highlightPath.lineTo(
          x,
          wave + 0.5,
        );
      }
    }

    final highlightPaint =
        Paint()
          ..color =
              Colors.white.withValues(
            alpha: 0.10,
          )
          ..style =
              PaintingStyle.stroke
          ..strokeWidth = 0.7
          ..isAntiAlias = true;

    canvas.drawPath(
      highlightPath,
      highlightPaint,
    );

    canvas.restore();
  }

  double _wave(
    double t,
    double phase,
  ) {
    final envelope =
        math.sin(t * math.pi);

    final primary =
        math.sin(
          t * math.pi * 2.2 +
              phase,
        );

    final secondary =
        math.sin(
          t * math.pi * 4.0 +
              phase * 1.35,
        );

    return envelope *
        (primary * 2.0 +
            secondary * 0.45);
  }

  @override
  bool shouldRepaint(
    _WavingFlagPainter
        oldDelegate,
  ) {
    return oldDelegate.time !=
        time;
  }
}
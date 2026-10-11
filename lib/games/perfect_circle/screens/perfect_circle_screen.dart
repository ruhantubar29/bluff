import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PerfectCircleScreen extends StatefulWidget {
  const PerfectCircleScreen({super.key});

  @override
  State<PerfectCircleScreen> createState() => _PerfectCircleScreenState();
}

enum _GameState {
  idle,
  drawing,
  fail,
  result,
}

class _PointData {
  final Offset point;
  double error = 0;

  _PointData(this.point);
}

class _CircleFit {
  final double x;
  final double y;
  final double r;

  const _CircleFit({
    required this.x,
    required this.y,
    required this.r,
  });
}

class _Computation {
  final double score;
  final bool full;

  const _Computation({
    required this.score,
    required this.full,
  });
}

class _ConfettiParticle {
  double x;
  double y;
  double vx;
  double vy;
  double rotation;
  double rotationVelocity;
  double width;
  double height;
  bool rectangle;
  Color color;

  _ConfettiParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.rotation,
    required this.rotationVelocity,
    required this.width,
    required this.height,
    required this.rectangle,
    required this.color,
  });
}

class _PerfectCircleScreenState extends State<PerfectCircleScreen>
    with SingleTickerProviderStateMixin {
  final List<_PointData> _points = [];
  final List<_ConfettiParticle> _confetti = [];

  late final AnimationController _animationController;

  _GameState _state = _GameState.idle;

  double _score = 0;
  double _best = 0;

  Size _canvasSize = Size.zero;

  bool _drawing = false;

  int? _activePointer;

  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(days: 1),
    )..addListener(() {
        _updateConfetti();

        if (mounted) {
          setState(() {});
        }
      });

    _animationController.repeat();

    _loadBestScore();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadBestScore() async {
    final prefs = await SharedPreferences.getInstance();

    final saved = prefs.getDouble('pc-best');

    if (!mounted) return;

    setState(() {
      _best = saved ?? 0;
    });
  }

  Future<void> _saveBestScore() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('pc-best', _best);
  }

  Future<void> _resetBest() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove('pc-best');

    if (!mounted) return;

    setState(() {
      _best = 0;
      _points.clear();
      _confetti.clear();
      _score = 0;
      _state = _GameState.idle;
      _drawing = false;
      _activePointer = null;
    });
  }

  void _startDrawing(PointerDownEvent event) {
    _activePointer = event.pointer;

    _confetti.clear();

    _drawing = true;
    _state = _GameState.drawing;

    _points
      ..clear()
      ..add(_PointData(event.localPosition));

    setState(() {});
  }

  void _continueDrawing(PointerMoveEvent event) {
    if (!_drawing) return;

    if (_activePointer != event.pointer) return;

    _points.add(_PointData(event.localPosition));

    final computation = _compute();

    if (computation != null) {
      _score = computation.score;
    }

    setState(() {});
  }

  Future<void> _endDrawing(PointerEvent event) async {
    if (!_drawing) return;

    if (_activePointer != event.pointer) return;

    _drawing = false;
    _activePointer = null;

    final computation = _compute();

    if (computation == null || !computation.full) {
      _state = _GameState.fail;

      _points.clear();

      await HapticFeedback.vibrate();

      if (mounted) {
        setState(() {});
      }

      return;
    }

    _state = _GameState.result;
    _score = computation.score;

    final isBest = _score > _best;

    if (isBest) {
      _best = _score;

      await _saveBestScore();

      _burst();

      await HapticFeedback.heavyImpact();
    }

    if (mounted) {
      setState(() {});
    }
  }

  /*
   * ------------------------------------------------------------
   * KASA LEAST-SQUARES CIRCLE FIT
   * ------------------------------------------------------------
   *
   * This is the same mathematical approach used by the HTML:
   *
   * x² + y² = ax + by + c
   *
   * Then:
   *
   * center = (a / 2, b / 2)
   */
  _CircleFit? _fitCircle(List<_PointData> points) {
    double sx = 0;
    double sy = 0;
    double sxx = 0;
    double syy = 0;
    double sxy = 0;
    double sz = 0;
    double sxz = 0;
    double syz = 0;

    final n = points.length;

    for (final data in points) {
      final x = data.point.dx;
      final y = data.point.dy;

      final z = x * x + y * y;

      sx += x;
      sy += y;

      sxx += x * x;
      syy += y * y;
      sxy += x * y;

      sz += z;
      sxz += x * z;
      syz += y * z;
    }

    final matrix = <List<double>>[
      [sxx, sxy, sx, sxz],
      [sxy, syy, sy, syz],
      [sx, sy, n.toDouble(), sz],
    ];

    for (int i = 0; i < 3; i++) {
      int pivot = i;

      for (int row = i + 1; row < 3; row++) {
        if (matrix[row][i].abs() > matrix[pivot][i].abs()) {
          pivot = row;
        }
      }

      final temp = matrix[i];
      matrix[i] = matrix[pivot];
      matrix[pivot] = temp;

      if (matrix[i][i].abs() < 1e-9) {
        return null;
      }

      for (int row = 0; row < 3; row++) {
        if (row == i) continue;

        final factor = matrix[row][i] / matrix[i][i];

        for (int col = i; col < 4; col++) {
          matrix[row][col] -= factor * matrix[i][col];
        }
      }
    }

    final a = matrix[0][3] / matrix[0][0];
    final b = matrix[1][3] / matrix[1][1];
    final c = matrix[2][3] / matrix[2][2];

    final x0 = a / 2;
    final y0 = b / 2;

    final radiusSquared = c + x0 * x0 + y0 * y0;

    if (radiusSquared < 0) {
      return null;
    }

    final radius = math.sqrt(radiusSquared);

    return _CircleFit(
      x: x0,
      y: y0,
      r: radius,
    );
  }

  /*
   * ------------------------------------------------------------
   * SCORE CALCULATION
   * ------------------------------------------------------------
   *
   * This mirrors the JavaScript compute() function.
   */
  _Computation? _compute() {
    if (_points.length < 8) {
      return null;
    }

    final fit = _fitCircle(_points);

    if (fit == null || fit.r < 20) {
      return null;
    }

    double sweep = 0;

    double previousAngle = math.atan2(
      _points.first.point.dy - fit.y,
      _points.first.point.dx - fit.x,
    );

    double squaredError = 0;

    for (final data in _points) {
      final angle = math.atan2(
        data.point.dy - fit.y,
        data.point.dx - fit.x,
      );

      double delta = angle - previousAngle;

      if (delta > math.pi) {
        delta -= 2 * math.pi;
      }

      if (delta < -math.pi) {
        delta += 2 * math.pi;
      }

      sweep += delta;
      previousAngle = angle;

      final distance = math.sqrt(
        math.pow(data.point.dx - fit.x, 2) +
            math.pow(data.point.dy - fit.y, 2),
      );

      final error = (distance - fit.r) / fit.r;

      data.error = error.abs();

      squaredError += error * error;
    }

    final rms = math.sqrt(
      squaredError / _points.length,
    );

    final calculatedScore = (100 * (1 - rms * 3))
        .clamp(0, 99.9)
        .toDouble();

    final full =
        sweep.abs() >= 2 * math.pi * 0.75 &&
        _points.length >= 20;

    return _Computation(
      score: calculatedScore,
      full: full,
    );
  }

  /*
   * ------------------------------------------------------------
   * SCORE COLOR
   * ------------------------------------------------------------
   *
   * HTML:
   *
   * scoreHue = ((score - 40) / 50) * 120
   *
   * 0 = red
   * 120 = green
   */
  Color _scoreColor(double score) {
    final normalized =
        ((score - 40) / 50).clamp(0.0, 1.0);

    final hue = normalized * 120;

    return HSVColor.fromAHSV(
      1,
      hue,
      1,
      1,
    ).toColor();
  }

  /*
   * ------------------------------------------------------------
   * CONFETTI
   * ------------------------------------------------------------
   */
  void _burst() {
    const colors = <Color>[
      Color(0xFFFF3B30),
      Color(0xFFFFCC00),
      Color(0xFF34C759),
      Color(0xFF32ADE6),
      Color(0xFFAF52DE),
    ];

    _confetti.clear();

    for (int i = 0; i < 70; i++) {
      _confetti.add(
        _ConfettiParticle(
          x: _random.nextDouble() * _canvasSize.width,
          y: -_random.nextDouble() * _canvasSize.height * 0.5,
          vx: (_random.nextDouble() - 0.5) * 2,
          vy: 2 + _random.nextDouble() * 3,
          rotation: _random.nextDouble() * 6,
          rotationVelocity:
              (_random.nextDouble() - 0.5) * 0.3,
          width: 5 + _random.nextDouble() * 10,
          height: 4 + _random.nextDouble() * 10,
          rectangle: _random.nextBool(),
          color: colors[i % colors.length],
        ),
      );
    }
  }

  void _updateConfetti() {
    if (_confetti.isEmpty) return;

    for (final particle in _confetti) {
      particle.x += particle.vx;
      particle.y += particle.vy;
      particle.rotation += particle.rotationVelocity;
    }

    _confetti.removeWhere(
      (particle) => particle.y > _canvasSize.height + 20,
    );
  }

  /*
   * ------------------------------------------------------------
   * BUILD
   * ------------------------------------------------------------
   */
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        top: true,
        bottom: true,
        child: LayoutBuilder(
          builder: (context, constraints) {
            _canvasSize = Size(
              constraints.maxWidth,
              constraints.maxHeight,
            );

            return Stack(
              children: [
                Positioned.fill(
                  child: Listener(
                    behavior: HitTestBehavior.opaque,
                    onPointerDown: _startDrawing,
                    onPointerMove: _continueDrawing,
                    onPointerUp: _endDrawing,
                    onPointerCancel: _endDrawing,
                    child: RepaintBoundary(
                      child: CustomPaint(
                        painter: _PerfectCirclePainter(
                          points: _points,
                          confetti: _confetti,
                          state: _state,
                        ),
                        isComplex: true,
                        willChange: true,
                      ),
                    ),
                  ),
                ),

                /*
                 * HEADER
                 */
                Positioned(
                  top: 0,
                  left: 20,
                  right: 20,
                  child: SizedBox(
                    height: 74,
                    child: Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                      crossAxisAlignment:
                          CrossAxisAlignment.center,
                      children: [
                        const Text(
                          'Perfect Circle',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 30,
                            fontWeight: FontWeight.w400,
                            letterSpacing: -0.2,
                          ),
                        ),

                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: _resetBest,
                          child: const Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 8,
                            ),
                            child: Text(
                              '×',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 38,
                                height: 1,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                /*
                 * CENTER INFORMATION
                 */
                Positioned(
                  left: 0,
                  right: 0,
                  top: _centerY,
                  child: IgnorePointer(
                    child: Transform.translate(
                      offset: const Offset(0, -0.5),
                      child: _buildCenterContent(),
                    ),
                  ),
                ),

                /*
                 * BOTTOM NAVIGATION
                 */
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 34,
                  child: IgnorePointer(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment:
                              MainAxisAlignment.center,
                          children: [
                            const SizedBox(
                              width: 30,
                              child: Text(
                                '‹',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Color(0xFF888888),
                                  fontSize: 34,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ),

                            const SizedBox(width: 46),

                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                              ),
                            ),

                            const SizedBox(width: 46),

                            const SizedBox(
                              width: 30,
                              child: Text(
                                '›',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Color(0xFFAAAAAA),
                                  fontSize: 34,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 10),

                        const Text(
                          'Circle',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            letterSpacing: 1,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  double get _centerY {
    return _canvasSize.height * 0.485;
  }

  Widget _buildCenterContent() {
    switch (_state) {
      case _GameState.idle:
        return _buildIdleContent();

      case _GameState.drawing:
        return _buildScoreContent(
          _score,
          showBest: false,
        );

      case _GameState.result:
        return _buildScoreContent(
          _score,
          showBest: true,
        );

      case _GameState.fail:
        return const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              ':(',
              style: TextStyle(
                color: Color(0xFFFF0033),
                fontSize: 76,
                height: 1,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 22),
            Text(
              'Draw full circle',
              style: TextStyle(
                color: Color(0xFF9A9A9F),
                fontSize: 30,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        );
    }
  }

  Widget _buildIdleContent() {
    if (_best > 0) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),

          const SizedBox(height: 14),

          Text(
            'Best: ${_best.toStringAsFixed(1)}%',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 38,
              height: 1,
              fontWeight: FontWeight.w900,
              letterSpacing: -1,
            ),
          ),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
        ),

        const SizedBox(height: 14),

        const Text(
          'Draw a circle',
          style: TextStyle(
            color: Color(0xFF9A9A9F),
            fontSize: 30,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  Widget _buildScoreContent(
    double score, {
    required bool showBest,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          score.toStringAsFixed(1),
          style: TextStyle(
            color: _scoreColor(score),
            fontSize: 76,
            height: 1,
            fontWeight: FontWeight.w900,
            letterSpacing: -1,
          ),
        ),

        if (showBest) ...[
          const SizedBox(height: 12),

          Text(
            'Best: ${_best.toStringAsFixed(1)}%',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ],
    );
  }
}

/*
 * ============================================================
 * PAINTER
 * ============================================================
 */

class _PerfectCirclePainter extends CustomPainter {
  final List<_PointData> points;
  final List<_ConfettiParticle> confetti;
  final _GameState state;

  _PerfectCirclePainter({
    required this.points,
    required this.confetti,
    required this.state,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawColor(
  Colors.black,
  BlendMode.src,
);

    final cx = size.width / 2;
    final cy = size.height * 0.485;

    final radius = math.min(
      size.width * 0.42,
      size.height * 0.28,
    );

    /*
     * ----------------------------------------------------------
     * GUIDE CIRCLE
     * ----------------------------------------------------------
     *
     * The original HTML displays the guide while idle/fail.
     */
    if (state == _GameState.idle ||
        state == _GameState.fail) {
      _paintGuide(
        canvas,
        cx,
        cy,
        radius,
      );
    }

    /*
     * ----------------------------------------------------------
     * USER STROKE
     * ----------------------------------------------------------
     */
    _paintStroke(canvas);

    /*
     * ----------------------------------------------------------
     * CONFETTI
     * ----------------------------------------------------------
     */
    _paintConfetti(canvas);
  }

  void _paintGuide(
    Canvas canvas,
    double cx,
    double cy,
    double radius,
  ) {
    const count = 126;
    const total = math.pi * 2;

    final time =
        DateTime.now().millisecondsSinceEpoch / 1000;

    final rotation = time * 0.9;

    for (int i = 0; i < count; i++) {
      final startAngle = i * total / count;

      double phase =
          ((startAngle - rotation) % total + total) % total;

      phase = phase / total;

      double alpha;

      if (phase < 0.18) {
        alpha = 0;
      } else {
        alpha =
            0.08 +
            0.5 *
                ((phase - 0.18) / 0.82);
      }

      final paint = Paint()
        ..color = Colors.white.withOpacity(alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.butt;

      canvas.drawArc(
        Rect.fromCircle(
          center: Offset(cx, cy),
          radius: radius,
        ),
        startAngle,
        total / count * 0.52,
        false,
        paint,
      );
    }
  }

  void _paintStroke(Canvas canvas) {
    if (points.length < 2) return;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 15
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    for (int i = 1; i < points.length; i++) {
      final previous = points[i - 1];
      final current = points[i];

      paint.color = _errorColor(current.error);

      canvas.drawLine(
        previous.point,
        current.point,
        paint,
      );
    }
  }

  Color _errorColor(double error) {
    final normalized =
        (error / 0.16).clamp(0.0, 1.0);

    final hue =
        120 - normalized * 120;

    return HSVColor.fromAHSV(
      1,
      hue,
      1,
      1,
    ).toColor();
  }

  void _paintConfetti(
    Canvas canvas,
  ) {
    for (final particle in confetti) {
      canvas.save();

      canvas.translate(
        particle.x,
        particle.y,
      );

      canvas.rotate(
        particle.rotation,
      );

      final paint = Paint()
        ..color = particle.color
        ..style = PaintingStyle.fill;

      if (particle.rectangle) {
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset.zero,
            width: particle.width,
            height: particle.height,
          ),
          paint,
        );
      } else {
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset.zero,
            width: particle.width,
            height: particle.height,
          ),
          paint,
        );
      }

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(
    covariant _PerfectCirclePainter oldDelegate,
  ) {
    return true;
  }
}
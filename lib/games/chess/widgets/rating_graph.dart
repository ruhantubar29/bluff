import 'package:flutter/material.dart';

import '../core/rating/elo.dart';
import 'chess_theme.dart';

/// Minimal line chart of a rating history series — no external chart
/// dependency. Shared by the profile and the chess stats screens.
class RatingGraph extends StatelessWidget {
  const RatingGraph({super.key, required this.points});

  final List<RatingPoint> points;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(double.infinity, 132),
      painter: _GraphPainter(points),
    );
  }
}

class _GraphPainter extends CustomPainter {
  _GraphPainter(this.points);

  final List<RatingPoint> points;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    var min = points.first.rating;
    var max = points.first.rating;
    for (final p in points) {
      if (p.rating < min) min = p.rating;
      if (p.rating > max) max = p.rating;
    }
    // Keep the line readable when every point is identical.
    if (max - min < 20) {
      max += 10;
      min -= 10;
    }
    final pad = (max - min) * 0.12;
    min = (min - pad).round();
    max = (max + pad).round();

    final gridPaint = Paint()
      ..color = ChessPalette.border
      ..strokeWidth = 1;
    for (var i = 1; i < 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    Offset pointAt(int i) {
      final x = size.width * i / (points.length - 1);
      final t = (points[i].rating - min) / (max - min);
      return Offset(x, size.height * (1 - t.clamp(0.0, 1.0)));
    }

    final path = Path()..moveTo(pointAt(0).dx, pointAt(0).dy);
    for (var i = 1; i < points.length; i++) {
      final o = pointAt(i);
      path.lineTo(o.dx, o.dy);
    }

    final fill = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            ChessPalette.accent.withValues(alpha: 0.30),
            ChessPalette.accent.withValues(alpha: 0.0),
          ],
        ).createShader(Offset.zero & size),
    );

    canvas.drawPath(
      path,
      Paint()
        ..color = ChessPalette.accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    final last = pointAt(points.length - 1);
    canvas.drawCircle(last, 3.4, Paint()..color = ChessPalette.text);
    canvas.drawCircle(last, 6.4, Paint()..color = ChessPalette.accent);
  }

  @override
  bool shouldRepaint(_GraphPainter oldDelegate) =>
      oldDelegate.points != points;
}

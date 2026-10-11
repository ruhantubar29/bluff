import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const kPaper = Color(0xFFFFF3DC);
const kInk = Color(0xFF1B1013);
const kMarker = Color(0xFFFFD23F);
const kMint = Color(0xFF9BE28A);
const kSky = Color(0xFF7FD6FF);
const kPink = Color(0xFFFF8FB1);
const kLav = Color(0xFFC9A7FF);
const kOrange = Color(0xFFFFA45C);
const kRed = Color(0xFFD92F45);
const kArt = [kSky, kPink, kMint, kLav, kOrange];

Color dim(Color c, double a) => c.withValues(alpha: a);

TextStyle atma(double s,
        {Color c = kInk, FontWeight w = FontWeight.w700, double? h}) =>
    GoogleFonts.atma(fontSize: s, fontWeight: w, color: c, height: h);

Map<String, dynamic> asMap(dynamic v) =>
    v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

List<String> asList(dynamic v) =>
    v is List ? v.whereType<String>().toList() : <String>[];

/// Players in turn order (anyone missing from playerOrder is appended).
List<String> orderedIds(Map<String, dynamic> room) {
  final players = asMap(room['players']);
  final order = asList(room['playerOrder']);
  return [
    ...order.where(players.containsKey),
    ...players.keys.where((k) => !order.contains(k)),
  ];
}

// ── Pages ───────────────────────────────────────────────────────────────

class SketchPage extends StatelessWidget {
  const SketchPage({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: kPaper,
        body: SafeArea(
          child: Stack(
            fit: StackFit.expand,
            children: [
              const CustomPaint(painter: _BgPainter()),
              child,
            ],
          ),
        ),
      );
}

class SketchLoading extends StatelessWidget {
  const SketchLoading({super.key});

  @override
  Widget build(BuildContext context) =>
      const SketchPage(child: Center(child: CircularProgressIndicator()));
}

class SketchMessage extends StatelessWidget {
  const SketchMessage(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => SketchPage(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(text, textAlign: TextAlign.center, style: atma(22)),
          ),
        ),
      );
}

// ── Widgets ─────────────────────────────────────────────────────────────

class SketchBox extends StatelessWidget {
  const SketchBox({
    super.key,
    required this.fill,
    required this.child,
    this.radius = 20,
    this.stroke = 3,
    this.seed = 1,
    this.shadow = const Offset(4, 5),
    this.onTap,
  });

  final Color fill;
  final Widget child;
  final double radius, stroke;
  final int seed;
  final Offset shadow;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final box = CustomPaint(
      painter: _BoxPainter(fill, radius, stroke, seed, shadow),
      child: child,
    );
    return onTap == null
        ? box
        : GestureDetector(
            behavior: HitTestBehavior.opaque, onTap: onTap, child: box);
  }
}

class SketchButton extends StatelessWidget {
  const SketchButton({
    super.key,
    required this.text,
    required this.fill,
    required this.onTap,
    this.enabled = true,
  });

  final String text;
  final Color fill;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) => SketchBox(
        fill: enabled ? fill : dim(Colors.black, .10),
        radius: 18,
        seed: 91,
        shadow: enabled ? const Offset(4, 5) : Offset.zero,
        onTap: enabled ? onTap : null,
        child: SizedBox(
          width: double.infinity,
          height: 58,
          child: Center(
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: atma(23, c: enabled ? kInk : dim(kInk, .35))
                  .copyWith(letterSpacing: .5),
            ),
          ),
        ),
      );
}

class SketchText extends StatelessWidget {
  const SketchText(this.text, this.size, this.rotation, {super.key});
  final String text;
  final double size, rotation;

  @override
  Widget build(BuildContext context) => Transform.rotate(
        angle: rotation,
        child: Text(text,
            textAlign: TextAlign.center, style: atma(size, h: .9)),
      );
}

class DoodleCircle extends StatelessWidget {
  const DoodleCircle(
      {super.key, required this.size, required this.fill, required this.child});
  final double size;
  final Color fill;
  final Widget child;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
            painter: _CirclePainter(fill), child: Center(child: child)),
      );
}

class DoodleCheck extends StatelessWidget {
  const DoodleCheck({super.key, required this.checked, this.disabled = false});
  final bool checked, disabled;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 34,
        height: 34,
        child: CustomPaint(painter: _CheckPainter(checked, disabled)),
      );
}

class ProgressBadge extends StatelessWidget {
  const ProgressBadge(this.current, this.total, {super.key});
  final int current, total;

  @override
  Widget build(BuildContext context) => Transform.rotate(
        angle: .025,
        child: CustomPaint(
          painter: const _BadgePainter(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
            child: Text('$current/$total', style: atma(19)),
          ),
        ),
      );
}

// ── Painters ────────────────────────────────────────────────────────────

class _BoxPainter extends CustomPainter {
  const _BoxPainter(this.fill, this.radius, this.stroke, this.seed, this.shadow);
  final Color fill;
  final double radius, stroke;
  final int seed;
  final Offset shadow;

  @override
  void paint(Canvas c, Size s) {
    final r = math.Random(seed);
    double j(double m) => r.nextDouble() * m;

    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(shadow.dx.abs(), shadow.dy.abs(),
          s.width - shadow.dx.abs() - 1, s.height - shadow.dy.abs() - 1),
      Radius.circular(radius),
    );
    if (shadow != Offset.zero) {
      c.drawRRect(rect.shift(shadow), Paint()..color = dim(kInk, .20));
    }
    c.drawRRect(rect, Paint()..color = fill);

    const l = 1.0, t = 1.0;
    final rt = s.width - 1, b = s.height - 1;
    final path = Path()
      ..moveTo(l + radius, t + j(1.5))
      ..lineTo(rt - radius, t + j(1.5))
      ..quadraticBezierTo(rt, t, rt + j(.8), t + radius)
      ..lineTo(rt + j(.8), b - radius)
      ..quadraticBezierTo(rt, b, rt - radius, b + j(.8))
      ..lineTo(l + radius, b + j(.8))
      ..quadraticBezierTo(l, b, l - j(.8), b - radius)
      ..lineTo(l + j(.8), t + radius)
      ..quadraticBezierTo(l, t, l + radius, t);

    c.drawPath(
      path,
      Paint()
        ..color = kInk
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    c.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(3, 3, s.width - 6, s.height - 6),
          Radius.circular(radius - 3)),
      Paint()
        ..color = dim(kInk, .28)
        ..style = PaintingStyle.stroke
        ..strokeWidth = .9
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_BoxPainter o) =>
      o.fill != fill || o.seed != seed || o.shadow != shadow;
}

class _CirclePainter extends CustomPainter {
  const _CirclePainter(this.fill);
  final Color fill;

  @override
  void paint(Canvas c, Size s) {
    final ctr = s.center(Offset.zero);
    final r = math.min(s.width, s.height) / 2 - 2;
    c.drawCircle(ctr, r, Paint()..color = fill);

    final path = Path();
    for (var i = 0; i <= 40; i++) {
      final a = math.pi * 2 * i / 40;
      final rr = r + math.sin(i * 1.7) * 1.2;
      final p = Offset(ctr.dx + math.cos(a) * rr, ctr.dy + math.sin(a) * rr);
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    c.drawPath(
      path,
      Paint()
        ..color = kInk
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.8
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_CirclePainter o) => o.fill != fill;
}

class _CheckPainter extends CustomPainter {
  const _CheckPainter(this.checked, this.disabled);
  final bool checked, disabled;

  @override
  void paint(Canvas c, Size s) {
    final ctr = s.center(Offset.zero);
    final r = math.min(s.width, s.height) / 2 - 2;

    c.drawCircle(
      ctr,
      r,
      Paint()
        ..color = disabled
            ? dim(kInk, .08)
            : checked
                ? kInk
                : Colors.transparent,
    );
    c.drawCircle(
      ctr,
      r,
      Paint()
        ..color = disabled ? dim(kInk, .25) : kInk
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.3,
    );
    if (checked && !disabled) {
      c.drawPath(
        Path()
          ..moveTo(s.width * .27, s.height * .52)
          ..lineTo(s.width * .44, s.height * .69)
          ..lineTo(s.width * .75, s.height * .33),
        Paint()
          ..color = kPaper
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.2
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }
  }

  @override
  bool shouldRepaint(_CheckPainter o) =>
      o.checked != checked || o.disabled != disabled;
}

class _BadgePainter extends CustomPainter {
  const _BadgePainter();

  @override
  void paint(Canvas c, Size s) {
    final path = Path()
      ..moveTo(2, 4)
      ..quadraticBezierTo(s.width / 2, 0, s.width - 2, 4)
      ..lineTo(s.width - 3, s.height - 4)
      ..quadraticBezierTo(s.width / 2, s.height, 2, s.height - 4)
      ..close();
    c.drawPath(path, Paint()..color = kSky);
    c.drawPath(
      path,
      Paint()
        ..color = kInk
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8,
    );
  }

  @override
  bool shouldRepaint(_BadgePainter o) => false;
}

class _BgPainter extends CustomPainter {
  const _BgPainter();

  @override
  void paint(Canvas c, Size s) {
    final p = Paint()
      ..color = dim(kInk, .10)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    c.drawLine(Offset(s.width * .06, s.height * .17),
        Offset(s.width * .22, s.height * .13), p);
    c.drawLine(Offset(s.width * .78, s.height * .11),
        Offset(s.width * .93, s.height * .16), p);
    c.drawArc(
        Rect.fromCircle(
            center: Offset(s.width * .90, s.height * .78), radius: 30),
        .3, 2.1, false, p);
    c.drawArc(
        Rect.fromCircle(
            center: Offset(s.width * .09, s.height * .72), radius: 23),
        -.4, 2.2, false, p);

    final dot = Paint()..color = dim(kInk, .14);
    for (final o in [
      Offset(s.width * .12, s.height * .27),
      Offset(s.width * .89, s.height * .28),
      Offset(s.width * .16, s.height * .86),
      Offset(s.width * .82, s.height * .90),
    ]) {
      c.drawCircle(o, 2.5, dot);
    }
  }

  @override
  bool shouldRepaint(_BgPainter o) => false;
}
import 'package:flutter/material.dart';

/// The drifting glow the whole game sits on.
///
/// Two soft radial blobs — one per palette — slowly cross the screen so no
/// two moments look identical. Radial gradients rather than a blurred layer:
/// a full-screen blur repaints on every frame and stutters on cheaper phones,
/// while a gradient reads the same and costs almost nothing.
class GlowBackground extends StatefulWidget {
  const GlowBackground({
    super.key,
    required this.warm,
    required this.cool,
    this.base = const Color(0xFF0B0D14),
  });

  final Color warm;
  final Color cool;
  final Color base;

  @override
  State<GlowBackground> createState() => _GlowBackgroundState();
}

class _GlowBackgroundState extends State<GlowBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _drift = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 18),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _drift.dispose();
    super.dispose();
  }

  Widget _blob(Color color, double size) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOut,
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withValues(alpha: 0.42),
            color.withValues(alpha: 0.0),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: widget.base,
      child: AnimatedBuilder(
        animation: _drift,
        builder: (context, _) {
          final t = _drift.value;
          return Stack(
            fit: StackFit.expand,
            children: [
              Positioned(
                left: -220 + t * 130,
                top: -280 + t * 95,
                child: _blob(widget.warm, 620),
              ),
              Positioned(
                right: -220 + t * 110,
                bottom: -280 + t * 120,
                child: _blob(widget.cool, 620),
              ),
            ],
          );
        },
      ),
    );
  }
}

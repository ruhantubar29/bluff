import 'package:flutter/material.dart';

class GameCard extends StatelessWidget {
  final String title;
  final String description;
  final String? imagePath;
  final VoidCallback? onTap;

  const GameCard({
    super.key,
    required this.title,
    required this.description,
    this.imagePath,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const radius = 20.0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          color: Theme.of(context).colorScheme.surface,
          boxShadow: [
            BoxShadow(
              blurRadius: 12,
              offset: const Offset(0, 5),
              color: Colors.black.withValues(alpha: 0.12),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (imagePath != null)
              Image.asset(
                imagePath!,
                fit: BoxFit.cover,
              )
            else
              const Center(
                child: Icon(
                  Icons.games,
                  size: 50,
                ),
              ),

            IgnorePointer(
              child: CustomPaint(
                painter: _CardBorderPainter(
                  radius: radius,
                  color: Colors.white.withValues(alpha: 0.85),
                  strokeWidth: 3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CardBorderPainter extends CustomPainter {
  final double radius;
  final Color color;
  final double strokeWidth;

  const _CardBorderPainter({
    required this.radius,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {
    final rect = Offset.zero & size;

    final inset = strokeWidth / 2;

    final borderRect = Rect.fromLTWH(
      inset,
      inset,
      size.width - strokeWidth,
      size.height - strokeWidth,
    );

    final rrect = RRect.fromRectAndRadius(
      borderRect,
      Radius.circular(radius - inset),
    );

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..isAntiAlias = true;

    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(
    _CardBorderPainter oldDelegate,
  ) {
    return oldDelegate.radius != radius ||
        oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
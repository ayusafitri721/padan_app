import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class CornerLeafDecoration extends StatelessWidget {
  const CornerLeafDecoration({super.key, required this.alignment});

  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      height: 160,
      child: CustomPaint(
        painter: _CornerLeafPainter(alignment: alignment),
      ),
    );
  }
}

class _CornerLeafPainter extends CustomPainter {
  _CornerLeafPainter({required this.alignment});

  final Alignment alignment;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final w = size.width;
    final h = size.height;

    canvas.save();
    canvas.translate(w / 2, h / 2);
    canvas.scale(alignment.x == -1 ? 1 : -1, alignment.y == -1 ? 1 : -1);

    // Leaf 1 (large)
    final leaf1 = Path();
    leaf1.moveTo(0, 0);
    leaf1.quadraticBezierTo(-10, -30, -35, -40);
    leaf1.quadraticBezierTo(-15, -15, 0, 0);
    canvas.drawPath(leaf1, paint);

    // Leaf vein 1
    canvas.drawLine(Offset(0, 0), Offset(-25, -32), paint);

    // Leaf 2 (smaller)
    final leaf2 = Path();
    leaf2.moveTo(0, 0);
    leaf2.quadraticBezierTo(-25, -15, -45, -5);
    leaf2.quadraticBezierTo(-20, 10, 0, 0);
    canvas.drawPath(leaf2, paint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CornerLeafPainter oldDelegate) =>
      oldDelegate.alignment != alignment;
}
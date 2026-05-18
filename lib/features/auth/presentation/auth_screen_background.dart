import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class AuthScreenBackground extends StatelessWidget {
  const AuthScreenBackground({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(child: CustomPaint(painter: _AuthBackground())),
        Positioned.fill(child: child),
      ],
    );
  }
}

class _AuthBackground extends CustomPainter {
  const _AuthBackground();

  @override
  void paint(Canvas canvas, Size size) {
    final ribbonPaint = Paint()
      ..color = AppColors.gold.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 42
      ..strokeCap = StrokeCap.round;

    final finePaint = Paint()
      ..color = AppColors.gold.withValues(alpha: 0.06)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final accentPaint = Paint()
      ..color = AppColors.gold.withValues(alpha: 0.18)
      ..style = PaintingStyle.fill;

    final mainCurve = Path()
      ..moveTo(size.width * 0.08, size.height * 0.18)
      ..cubicTo(
        size.width * 0.34,
        size.height * 0.02,
        size.width * 0.62,
        size.height * 0.42,
        size.width * 0.92,
        size.height * 0.22,
      );
    canvas.drawPath(mainCurve, ribbonPaint);

    final lowerCurve = Path()
      ..moveTo(size.width * 0.12, size.height * 0.86)
      ..cubicTo(
        size.width * 0.42,
        size.height * 0.64,
        size.width * 0.64,
        size.height * 0.96,
        size.width * 0.98,
        size.height * 0.72,
      );
    canvas.drawPath(lowerCurve, finePaint);

    final corner = Path()
      ..moveTo(size.width, 0)
      ..lineTo(size.width, size.height * 0.2)
      ..lineTo(size.width * 0.9, size.height * 0.08)
      ..close();
    canvas.drawPath(corner, accentPaint);

    final bottom = Path()
      ..moveTo(0, size.height)
      ..lineTo(size.width * 0.18, size.height)
      ..lineTo(size.width * 0.06, size.height * 0.92)
      ..close();
    canvas.drawPath(bottom, accentPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

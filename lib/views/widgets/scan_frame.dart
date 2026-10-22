import 'package:flutter/material.dart';

import '../../app.dart';

/// Dims the camera around a square viewfinder and draws its corner marks.
/// Codes are detected anywhere in the picture; the frame is only a guide.
class ScanFrame extends StatelessWidget {
  const ScanFrame({super.key});

  @override
  Widget build(BuildContext context) => CustomPaint(painter: _FramePainter(), size: Size.infinite);
}

class _FramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final side = (size.shortestSide * 0.68).clamp(180.0, 340.0);
    final center = Offset(size.width / 2, size.height * 0.45);
    final box = Rect.fromCenter(center: center, width: side, height: side);
    final rrect = RRect.fromRectAndRadius(box, const Radius.circular(24));

    canvas.drawPath(
      Path.combine(PathOperation.difference, Path()..addRect(Offset.zero & size), Path()..addRRect(rrect)),
      Paint()..color = Colors.black.withValues(alpha: 0.45),
    );

    final corner = side * 0.16;
    const r = 24.0;
    final p = Paint()
      ..color = brand
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    final l = box.left, t = box.top, rt = box.right, b = box.bottom;
    final path = Path()
      // top-left
      ..moveTo(l, t + corner)
      ..lineTo(l, t + r)
      ..arcToPoint(Offset(l + r, t), radius: const Radius.circular(r))
      ..lineTo(l + corner, t)
      // top-right
      ..moveTo(rt - corner, t)
      ..lineTo(rt - r, t)
      ..arcToPoint(Offset(rt, t + r), radius: const Radius.circular(r))
      ..lineTo(rt, t + corner)
      // bottom-right
      ..moveTo(rt, b - corner)
      ..lineTo(rt, b - r)
      ..arcToPoint(Offset(rt - r, b), radius: const Radius.circular(r))
      ..lineTo(rt - corner, b)
      // bottom-left
      ..moveTo(l + corner, b)
      ..lineTo(l + r, b)
      ..arcToPoint(Offset(l, b - r), radius: const Radius.circular(r))
      ..lineTo(l, b - corner);
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

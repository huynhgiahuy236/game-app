import 'package:flutter/material.dart';

import 'receipt_ui.dart';

class ReceiptChartPoint {
  const ReceiptChartPoint(this.label, this.value);
  final String label;
  final double value;
}

class ReceiptBarChart extends StatelessWidget {
  const ReceiptBarChart({super.key, required this.points});
  final List<ReceiptChartPoint> points;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty || points.every((point) => point.value == 0)) {
      return const SizedBox(
        height: 180,
        child: Center(
          child: Text(
            'Chưa có dữ liệu để vẽ biểu đồ',
            style: TextStyle(fontSize: 16),
          ),
        ),
      );
    }
    final chartWidth = (points.length * 52.0).clamp(
      MediaQuery.sizeOf(context).width - 64,
      double.infinity,
    );
    return Semantics(
      label:
          'Biểu đồ khối lượng: ${points.map((point) => '${point.label} ${point.value.toStringAsFixed(1)} tấn').join(', ')}',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: chartWidth,
          height: 210,
          child: CustomPaint(
            painter: _BarChartPainter(
              points: points,
              dark: Theme.of(context).brightness == Brightness.dark,
            ),
          ),
        ),
      ),
    );
  }
}

class _BarChartPainter extends CustomPainter {
  const _BarChartPainter({required this.points, required this.dark});
  final List<ReceiptChartPoint> points;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    const top = 26.0;
    const bottom = 34.0;
    const gap = 12.0;
    final baseline = size.height - bottom;
    final usableHeight = baseline - top;
    final maxValue = points
        .map((point) => point.value)
        .reduce((a, b) => a > b ? a : b);
    final slot = size.width / points.length;
    final barWidth = (slot - gap).clamp(18.0, 34.0);
    final gridPaint = Paint()
      ..color = dark ? ReceiptColors.darkLine : ReceiptColors.line;
    final barPaint = Paint()..color = ReceiptColors.blue;
    final textColor = dark ? Colors.white : ReceiptColors.ink;

    for (var line = 0; line <= 3; line++) {
      final y = top + usableHeight * line / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    for (var index = 0; index < points.length; index++) {
      final point = points[index];
      final height = maxValue == 0
          ? 0.0
          : usableHeight * point.value / maxValue;
      final left = slot * index + (slot - barWidth) / 2;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(left, baseline - height, barWidth, height),
        const Radius.circular(6),
      );
      canvas.drawRRect(rect, barPaint);
      _text(
        canvas,
        point.label,
        Offset(slot * index + slot / 2, baseline + 9),
        textColor,
        12,
        center: true,
      );
      if (point.value > 0) {
        _text(
          canvas,
          _compact(point.value),
          Offset(slot * index + slot / 2, baseline - height - 18),
          textColor,
          11,
          center: true,
          bold: true,
        );
      }
    }
  }

  String _compact(double value) => value >= 100
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1).replaceFirst(RegExp(r'\.0$'), '');

  void _text(
    Canvas canvas,
    String value,
    Offset offset,
    Color color,
    double size, {
    bool center = false,
    bool bold = false,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(
          color: color,
          fontSize: size,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      Offset(center ? offset.dx - painter.width / 2 : offset.dx, offset.dy),
    );
  }

  @override
  bool shouldRepaint(covariant _BarChartPainter oldDelegate) =>
      oldDelegate.points != points || oldDelegate.dark != dark;
}

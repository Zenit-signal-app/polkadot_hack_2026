import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// A single data series for [GenericLineChart].
class ChartSeries {
  final String label;
  final List<double> data;
  final Color color;

  /// Whether to draw a gradient fill underneath this series.
  final bool fill;

  const ChartSeries({
    required this.label,
    required this.data,
    required this.color,
    this.fill = false,
  });
}

/// Generic smooth line chart — no RSI-specific zones.
/// Supports multiple overlapping series with dynamic Y scaling.
class GenericLineChart extends StatelessWidget {
  final List<ChartSeries> series;
  final double height;

  const GenericLineChart({
    super.key,
    required this.series,
    this.height = 180,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFF1A2332),
        borderRadius: BorderRadius.circular(12),
      ),
      child: CustomPaint(
        painter: _GenericLinePainter(series: series),
        child: Container(),
      ),
    );
  }
}

class _GenericLinePainter extends CustomPainter {
  final List<ChartSeries> series;

  _GenericLinePainter({required this.series});

  @override
  void paint(Canvas canvas, Size size) {
    if (series.isEmpty) return;
    final allData = series.expand((s) => s.data);
    if (allData.isEmpty) return;

    const leftPad = 8.0;
    const rightPad = 48.0; // room for Y-axis labels
    const topPad = 16.0;
    const bottomPad = 16.0;

    final chartW = size.width - leftPad - rightPad;
    final chartH = size.height - topPad - bottomPad;

    // Global min/max across all series
    double minVal = allData.reduce((a, b) => a < b ? a : b);
    double maxVal = allData.reduce((a, b) => a > b ? a : b);

    // Avoid zero-range
    if (maxVal == minVal) {
      minVal = minVal - 1;
      maxVal = maxVal + 1;
    }
    final range = maxVal - minVal;

    double toX(int index, int total) =>
        leftPad + chartW * index / (total - 1 == 0 ? 1 : total - 1);
    double toY(double val) =>
        topPad + chartH * (1 - (val - minVal) / range);

    // Draw each series
    for (final s in series) {
      if (s.data.length < 2) continue;
      final pts = List.generate(
        s.data.length,
        (i) => Offset(toX(i, s.data.length), toY(s.data[i])),
      );

      // Gradient fill (only the series that sets fill: true)
      if (s.fill) {
        final gradPath = _buildSmoothPath(pts);
        gradPath.lineTo(pts.last.dx, topPad + chartH);
        gradPath.lineTo(pts.first.dx, topPad + chartH);
        gradPath.close();

        final gradPaint = Paint()
          ..shader = ui.Gradient.linear(
            Offset(leftPad, topPad),
            Offset(leftPad, topPad + chartH),
            [s.color.withValues(alpha: 0.35), s.color.withValues(alpha: 0.0)],
          )
          ..style = PaintingStyle.fill;
        canvas.drawPath(gradPath, gradPaint);
      }

      // Line
      final linePaint = Paint()
        ..color = s.color
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      canvas.drawPath(_buildSmoothPath(pts), linePaint);
    }

    // Y-axis labels: max, current (last point of primary series), min
    _drawYLabels(canvas, size, topPad, chartH, rightPad, minVal, maxVal, series.first);
  }

  Path _buildSmoothPath(List<Offset> pts) {
    final path = Path()..moveTo(pts[0].dx, pts[0].dy);
    for (var i = 0; i < pts.length - 1; i++) {
      final cpX = pts[i].dx + (pts[i + 1].dx - pts[i].dx) / 2;
      path.quadraticBezierTo(cpX, pts[i].dy, pts[i + 1].dx, pts[i + 1].dy);
    }
    return path;
  }

  void _drawYLabels(
    Canvas canvas,
    Size size,
    double topPad,
    double chartH,
    double rightPad,
    double minVal,
    double maxVal,
    ChartSeries primary,
  ) {
    final labelX = size.width - rightPad + 6;

    void drawLabel(String text, double y, Color color) {
      final tp = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(labelX, y - tp.height / 2));
    }

    // Max label
    drawLabel(_fmt(maxVal), topPad, Colors.white.withValues(alpha: 0.6));

    // Min label
    drawLabel(_fmt(minVal), topPad + chartH, Colors.white.withValues(alpha: 0.6));

    // Current value (last non-null = last in primary series)
    if (primary.data.isNotEmpty) {
      final lastVal = primary.data.last;
      final range = maxVal - minVal;
      final y = topPad + chartH * (1 - (lastVal - minVal) / range);
      drawLabel(_fmt(lastVal), y, primary.color);
    }
  }

  String _fmt(double v) {
    if (v.abs() >= 1000) return v.toStringAsFixed(0);
    if (v.abs() >= 100) return v.toStringAsFixed(1);
    return v.toStringAsFixed(2);
  }

  @override
  bool shouldRepaint(covariant _GenericLinePainter old) => old.series != series;
}

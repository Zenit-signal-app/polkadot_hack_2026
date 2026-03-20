import 'package:flutter/material.dart';

/// RSI Line Chart Widget - Shows RSI trend line with overbought/oversold zones
class RsiLineChart extends StatelessWidget {
  final List<double> rsiData;
  final double height;
  final Color lineColor;

  const RsiLineChart({
    super.key,
    required this.rsiData,
    this.height = 150,
    this.lineColor = const Color(0xFF3B82F6),
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
        painter: RsiLinePainter(
          rsiData: rsiData,
          lineColor: lineColor,
        ),
        child: Container(),
      ),
    );
  }
}

/// Custom Painter for RSI Line Chart
class RsiLinePainter extends CustomPainter {
  final List<double> rsiData;
  final Color lineColor;

  RsiLinePainter({
    required this.rsiData,
    required this.lineColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (rsiData.isEmpty) return;

    const padding = 20.0;
    final chartHeight = size.height - (padding * 2);
    final chartWidth = size.width - (padding * 2);

    // Draw background zones
    _drawBackgroundZones(canvas, size, padding, chartHeight, chartWidth);

    // Draw grid lines
    _drawGridLines(canvas, size, padding, chartHeight, chartWidth);

    // Draw RSI line
    _drawRsiLine(canvas, padding, chartHeight, chartWidth);

    // Draw Y-axis labels
    _drawYAxisLabels(canvas, size, padding, chartHeight);
  }

  void _drawBackgroundZones(
    Canvas canvas,
    Size size,
    double padding,
    double chartHeight,
    double chartWidth,
  ) {
    // Overbought zone (70-100) - Red transparent
    final overboughtHeight = chartHeight * 0.3;
    final overboughtRect = Rect.fromLTWH(
      padding,
      padding,
      chartWidth,
      overboughtHeight,
    );
    final overboughtPaint = Paint()
      ..color = const Color(0xFF7F1D1D).withOpacity(0.2)
      ..style = PaintingStyle.fill;
    canvas.drawRect(overboughtRect, overboughtPaint);

    // Oversold zone (0-30) - Green transparent
    final oversoldHeight = chartHeight * 0.3;
    final oversoldRect = Rect.fromLTWH(
      padding,
      size.height - padding - oversoldHeight,
      chartWidth,
      oversoldHeight,
    );
    final oversoldPaint = Paint()
      ..color = const Color(0xFF166534).withOpacity(0.2)
      ..style = PaintingStyle.fill;
    canvas.drawRect(oversoldRect, oversoldPaint);
  }

  void _drawGridLines(
    Canvas canvas,
    Size size,
    double padding,
    double chartHeight,
    double chartWidth,
  ) {
    final linePaint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..strokeWidth = 1.0;

    // Horizontal lines at 100, 70, 50, 30, 0
    final levels = [0.0, 0.3, 0.5, 0.7, 1.0];
    for (final level in levels) {
      final y = padding + (chartHeight * level);
      canvas.drawLine(
        Offset(padding, y),
        Offset(size.width - padding, y),
        linePaint,
      );
    }

    // 70 and 30 lines thicker
    final thickLinePaint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..strokeWidth = 1.5;

    final y70 = padding + (chartHeight * 0.3);
    canvas.drawLine(
      Offset(padding, y70),
      Offset(size.width - padding, y70),
      thickLinePaint,
    );

    final y30 = padding + (chartHeight * 0.7);
    canvas.drawLine(
      Offset(padding, y30),
      Offset(size.width - padding, y30),
      thickLinePaint,
    );
  }

  void _drawRsiLine(
    Canvas canvas,
    double padding,
    double chartHeight,
    double chartWidth,
  ) {
    if (rsiData.length < 2) return;

    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    final points = <Offset>[];

    for (var i = 0; i < rsiData.length; i++) {
      final x = padding + (chartWidth * i / (rsiData.length - 1));
      final normalizedValue = (100 - rsiData[i]) / 100;
      final y = padding + (chartHeight * normalizedValue);
      points.add(Offset(x, y));
    }

    if (points.isNotEmpty) {
      path.moveTo(points[0].dx, points[0].dy);
      
      // Draw smooth curve using quadratic bezier
      for (var i = 0; i < points.length - 1; i++) {
        final p0 = points[i];
        final p1 = points[i + 1];
        
        // Calculate control point for smooth curve
        final controlPointX = p0.dx + (p1.dx - p0.dx) / 2;
        final controlPointY = p0.dy;
        
        path.quadraticBezierTo(
          controlPointX,
          controlPointY,
          p1.dx,
          p1.dy,
        );
      }
      
      canvas.drawPath(path, linePaint);

      // Draw gradient fill under line
      final gradientPath = Path.from(path);
      gradientPath.lineTo(points.last.dx, padding + chartHeight);
      gradientPath.lineTo(points.first.dx, padding + chartHeight);
      gradientPath.close();

      final gradient = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          lineColor.withOpacity(0.3),
          lineColor.withOpacity(0.0),
        ],
      );

      final gradientPaint = Paint()
        ..shader = gradient.createShader(
          Rect.fromLTWH(padding, padding, chartWidth, chartHeight),
        )
        ..style = PaintingStyle.fill;

      canvas.drawPath(gradientPath, gradientPaint);
    }
  }

  void _drawYAxisLabels(
    Canvas canvas,
    Size size,
    double padding,
    double chartHeight,
  ) {
    final textStyle = TextStyle(
      color: Colors.white.withOpacity(0.6),
      fontSize: 10,
      fontWeight: FontWeight.w500,
    );

    final labels = ['100', '70', '50', '30', '0'];
    final positions = [0.0, 0.3, 0.5, 0.7, 1.0];

    for (var i = 0; i < labels.length; i++) {
      final textSpan = TextSpan(text: labels[i], style: textStyle);
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();

      final y = padding + (chartHeight * positions[i]) - (textPainter.height / 2);
      textPainter.paint(canvas, Offset(5, y));
    }
  }

  @override
  bool shouldRepaint(covariant RsiLinePainter oldDelegate) {
    return oldDelegate.rsiData != rsiData || oldDelegate.lineColor != lineColor;
  }
}

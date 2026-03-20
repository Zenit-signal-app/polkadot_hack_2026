import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CandleChartWidget extends StatelessWidget {
  final List<double> chartData;

  const CandleChartWidget({
    super.key,
    required this.chartData,
  });

  @override
  Widget build(BuildContext context) {
    if (chartData.isEmpty) {
      return const SizedBox(
        height: 250,
        child: Center(
          child: Text(
            'No chart data available',
            style: TextStyle(color: Colors.white70),
          ),
        ),
      );
    }

    // Convert line data to candles (mock data)
    final candles = <CandleData>[];
    for (int i = 0; i < chartData.length; i++) {
      final price = chartData[i];
      final open = i > 0 ? chartData[i - 1] : price;
      final close = price;
      final high = price * 1.002;
      final low = price * 0.998;
      candles.add(CandleData(
        x: i.toDouble(),
        open: open,
        high: high,
        low: low,
        close: close,
      ));
    }

    final minY = chartData.reduce((a, b) => a < b ? a : b) * 0.995;
    final maxY = chartData.reduce((a, b) => a > b ? a : b) * 1.005;

    return Container(
      height: 250,
      padding: const EdgeInsets.only(right: 20, top: 20, bottom: 20),
      child: CustomPaint(
        painter: CandlestickChartPainter(
          candles: candles,
          minY: minY,
          maxY: maxY,
        ),
        child: Container(),
      ),
    );
  }
}

// Candle Data Model
class CandleData {
  final double x;
  final double open;
  final double high;
  final double low;
  final double close;

  CandleData({
    required this.x,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
  });

  bool get isBullish => close >= open;
}

// Candlestick Chart Painter
class CandlestickChartPainter extends CustomPainter {
  final List<CandleData> candles;
  final double minY;
  final double maxY;

  CandlestickChartPainter({
    required this.candles,
    required this.minY,
    required this.maxY,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (candles.isEmpty) return;

    final candleWidth = size.width / (candles.length * 1.5);
    final spacing = candleWidth * 0.5;

    // Draw grid lines
    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..strokeWidth = 1;

    for (int i = 0; i <= 5; i++) {
      final y = size.height * i / 5;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        gridPaint,
      );
    }

    // Draw price labels
    final textStyle = TextStyle(
      color: Colors.white.withOpacity(0.5),
      fontSize: 10,
    );

    for (int i = 0; i <= 5; i++) {
      final price = maxY - (maxY - minY) * i / 5;
      final textSpan = TextSpan(
        text: NumberFormat('#,##0.00').format(price),
        style: textStyle,
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: ui.TextDirection.ltr,
      );
      textPainter.layout();
      final y = size.height * i / 5 - textPainter.height / 2;
      textPainter.paint(canvas, Offset(-textPainter.width - 8, y));
    }

    // Draw candles
    for (int i = 0; i < candles.length; i++) {
      final candle = candles[i];
      final x = i * (candleWidth + spacing) + candleWidth / 2;

      final openY = _getYPosition(candle.open, size.height);
      final closeY = _getYPosition(candle.close, size.height);
      final highY = _getYPosition(candle.high, size.height);
      final lowY = _getYPosition(candle.low, size.height);

      final color = candle.isBullish
          ? const Color(0xFF00C853)
          : const Color(0xFFFF1744);

      // Draw wick (high-low line)
      final wickPaint = Paint()
        ..color = color
        ..strokeWidth = 1;
      canvas.drawLine(
        Offset(x, highY),
        Offset(x, lowY),
        wickPaint,
      );

      // Draw body (open-close rectangle)
      final bodyPaint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;

      final bodyTop = candle.isBullish ? closeY : openY;
      final bodyBottom = candle.isBullish ? openY : closeY;
      final bodyHeight = (bodyBottom - bodyTop).abs().clamp(1.0, double.infinity);

      canvas.drawRect(
        Rect.fromLTWH(
          x - candleWidth / 2,
          bodyTop,
          candleWidth,
          bodyHeight,
        ),
        bodyPaint,
      );
    }
  }

  double _getYPosition(double value, double height) {
    final normalizedValue = (value - minY) / (maxY - minY);
    return height - (normalizedValue * height);
  }

  @override
  bool shouldRepaint(CandlestickChartPainter oldDelegate) {
    return oldDelegate.candles != candles ||
        oldDelegate.minY != minY ||
        oldDelegate.maxY != maxY;
  }
}

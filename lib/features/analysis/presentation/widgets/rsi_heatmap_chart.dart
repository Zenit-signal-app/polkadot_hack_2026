import 'package:flutter/material.dart';

/// Model cho token point trên RSI heatmap
class RsiTokenPoint {
  final String symbol;
  final String imageUrl;
  final double rsiValue; // 0-100
  final double xPosition; // 0-1 (relative position)
  final Color color;

  RsiTokenPoint({
    required this.symbol,
    required this.imageUrl,
    required this.rsiValue,
    required this.xPosition,
    required this.color,
  });
}

/// RSI Heatmap Chart Widget
class RsiHeatmapChart extends StatelessWidget {
  final List<RsiTokenPoint> tokens;
  final double height;

  const RsiHeatmapChart({
    super.key,
    required this.tokens,
    this.height = 400,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFF0A1628),
        borderRadius: BorderRadius.circular(12),
      ),
      child: CustomPaint(
        painter: RsiHeatmapPainter(),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Stack(
              children: [
                // Y-axis labels
                _buildYAxisLabels(),
                
                // Token points
                ...tokens.map((token) {
                  final x = constraints.maxWidth * 0.1 + 
                            (constraints.maxWidth * 0.85) * token.xPosition;
                  final y = _getRsiYPosition(token.rsiValue, constraints.maxHeight);
                  
                  return Positioned(
                    left: x - 20,
                    top: y - 20,
                    child: _buildTokenPoint(token),
                  );
                }),
              ],
            );
          },
        ),
      ),
    );
  }

  double _getRsiYPosition(double rsiValue, double maxHeight) {
    // Padding top and bottom
    const padding = 30.0;
    final chartHeight = maxHeight - (padding * 2);
    
    // Invert Y (0 RSI at bottom, 100 at top)
    final normalizedValue = (100 - rsiValue) / 100;
    return padding + (chartHeight * normalizedValue);
  }

  Widget _buildYAxisLabels() {
    return Positioned(
      left: 10,
      top: 0,
      bottom: 0,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildLabel('100'),
          _buildLabel('70'),
          _buildLabel('30'),
          _buildLabel('0'),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white.withOpacity(0.6),
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildTokenPoint(RsiTokenPoint token) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: token.color,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: token.color.withOpacity(0.3),
            blurRadius: 8,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipOval(
        child: Image.network(
          token.imageUrl,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              color: token.color.withOpacity(0.3),
              child: Center(
                child: Text(
                  token.symbol[0],
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Custom Painter for RSI Heatmap background
class RsiHeatmapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const padding = 30.0;
    final chartHeight = size.height - (padding * 2);
    final chartWidth = size.width * 0.85;
    final leftPadding = size.width * 0.1;

    // Draw gradient background zones
    _drawGradientZones(canvas, size, padding, chartHeight, leftPadding, chartWidth);
    
    // Draw horizontal grid lines
    _drawGridLines(canvas, size, padding, chartHeight, leftPadding, chartWidth);
  }

  void _drawGradientZones(
    Canvas canvas,
    Size size,
    double padding,
    double chartHeight,
    double leftPadding,
    double chartWidth,
  ) {
    final rect = Rect.fromLTWH(leftPadding, padding, chartWidth, chartHeight);
    
    // Create gradient from top to bottom: Red (overbought) -> Black -> Green (oversold)
    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        const Color(0xFF7F1D1D), // Dark red (overbought zone)
        const Color(0xFF450A0A), // Darker red
        const Color(0xFF0A0A0A), // Black (neutral zone)
        const Color(0xFF0A0A0A), // Black
        const Color(0xFF14532D), // Dark green
        const Color(0xFF166534), // Green (oversold zone)
      ],
      stops: const [0.0, 0.15, 0.3, 0.7, 0.85, 1.0],
    );

    final paint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.fill;

    canvas.drawRect(rect, paint);
  }

  void _drawGridLines(
    Canvas canvas,
    Size size,
    double padding,
    double chartHeight,
    double leftPadding,
    double chartWidth,
  ) {
    final linePaint = Paint()
      ..color = Colors.white.withOpacity(0.2)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    // Draw lines at RSI levels: 100, 70, 30, 0
    final levels = [0.0, 0.3, 0.7, 1.0]; // normalized positions
    
    for (final level in levels) {
      final y = padding + (chartHeight * level);
      canvas.drawLine(
        Offset(leftPadding, y),
        Offset(leftPadding + chartWidth, y),
        linePaint,
      );
    }

    // Draw vertical grid lines (optional)
    final verticalLinePaint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    for (var i = 0; i <= 4; i++) {
      final x = leftPadding + (chartWidth * i / 4);
      canvas.drawLine(
        Offset(x, padding),
        Offset(x, padding + chartHeight),
        verticalLinePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

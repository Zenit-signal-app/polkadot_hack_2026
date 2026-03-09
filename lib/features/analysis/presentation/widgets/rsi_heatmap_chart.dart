import 'package:flutter/material.dart';

/// Model for a token point on the RSI heatmap
class RsiTokenPoint {
  final String symbol;
  final String image;
  final double rsiValue; // 0-100
  final double xPosition; // kept for backward compat, ignored by chart
  final Color color;

  RsiTokenPoint({
    required this.symbol,
    required this.image,
    required this.rsiValue,
    this.xPosition = 0,
    required this.color,
  });
}

/// RSI Heatmap Chart Widget
///
/// Y-axis: RSI value (0–100) — fixed on the left.
/// X-axis: token symbols sorted alphabetically, filling the available width.
/// Range slider below the chart controls which window of tokens is visible.
class RsiHeatmapChart extends StatefulWidget {
  final List<RsiTokenPoint> tokens;
  final double height;

  const RsiHeatmapChart({
    super.key,
    required this.tokens,
    this.height = 400,
  });

  @override
  State<RsiHeatmapChart> createState() => _RsiHeatmapChartState();
}

class _RsiHeatmapChartState extends State<RsiHeatmapChart> {
  static const double _leftAxisWidth = 38.0;
  static const double _topPadding = 20.0;
  static const double _bottomPadding = 12.0;
  static const double _tokenSize = 42.0;

  RangeValues _sliderValues = const RangeValues(0.0, 0.25);

  // Cache sorted tokens — only re-sort when the list reference changes
  List<RsiTokenPoint>? _sortedCache;
  List<RsiTokenPoint>? _prevTokens;

  List<RsiTokenPoint> _getSorted() {
    if (!identical(_prevTokens, widget.tokens)) {
      _sortedCache = [...widget.tokens]
        ..sort((a, b) => a.symbol.compareTo(b.symbol));
      _prevTokens = widget.tokens;
    }
    return _sortedCache!;
  }

  List<RsiTokenPoint> _visibleTokens(List<RsiTokenPoint> sorted) {
    final n = sorted.length;
    if (n == 0) return [];
    final startIdx = (_sliderValues.start * n).floor().clamp(0, n - 1);
    final endIdx = (_sliderValues.end * n).ceil().clamp(startIdx + 1, n);
    return sorted.sublist(startIdx, endIdx);
  }

  @override
  Widget build(BuildContext context) {
    final sorted = _getSorted();
    final visible = _visibleTokens(sorted);
    final chartAreaHeight = widget.height - _topPadding - _bottomPadding;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0A1628),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.max,
        children: [
          // ── Chart area ──────────────────────────────────────────────────
          SizedBox(
            height: widget.height,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Fixed Y-axis labels
                SizedBox(
                  width: _leftAxisWidth,
                  height: widget.height,
                  child: _buildYAxis(chartAreaHeight),
                ),

                // Chart body — expands to fill remaining width, no scroll
                Expanded(
                  child: RepaintBoundary(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final chartWidth = constraints.maxWidth;
                        return ClipRect(
                          child: SizedBox(
                            width: chartWidth,
                            height: widget.height,
                            child: Stack(
                              clipBehavior: Clip.hardEdge,
                              children: [
                                // Zones + grid lines — single CustomPaint pass
                                Positioned(
                                  left: 0,
                                  right: 0,
                                  top: _topPadding,
                                  height: chartAreaHeight,
                                  child: CustomPaint(
                                    painter: const _RsiBackgroundPainter(),
                                    size: Size(chartWidth, chartAreaHeight),
                                  ),
                                ),

                                // Token coin icons
                                if (visible.isNotEmpty)
                                  ...visible.asMap().entries.map((e) {
                                    final itemW = chartWidth / visible.length;
                                    final cx = (e.key + 0.5) * itemW;
                                    final cy = _topPadding +
                                        (100 - e.value.rsiValue) /
                                            100 *
                                            chartAreaHeight;
                                    return Positioned(
                                      key: ValueKey(e.value.symbol),
                                      left: cx - _tokenSize / 2,
                                      top: cy - _tokenSize / 2,
                                      child: _CoinCircle(
                                        token: e.value,
                                        size: _tokenSize,
                                      ),
                                    );
                                  }),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Range slider ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: _TechRangeSlider(
              values: _sliderValues,
              onChanged: (v) {
                final n = sorted.length;
                if (n < 2) return;
                final minGap = 1.0 / n;
                if (v.end - v.start < minGap) return;
                setState(() => _sliderValues = v);
              },
              startLabel: visible.isNotEmpty ? visible.first.symbol : '',
              endLabel: visible.isNotEmpty ? visible.last.symbol : '',
              startImage: visible.isNotEmpty ? visible.first.image : '',
              endImage: visible.isNotEmpty ? visible.last.image : '',
              startColor: visible.isNotEmpty ? visible.first.color : const Color(0xFF5BA3FF),
              endColor: visible.isNotEmpty ? visible.last.color : const Color(0xFF5BA3FF),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildYAxis(double chartAreaHeight) {
    const levels = <(double, String)>[
      (0.0, '100'),
      (0.3, '70'),
      (0.7, '30'),
      (1.0, '0'),
    ];
    return Stack(
      children: levels.map((l) {
        final y = _topPadding + l.$1 * chartAreaHeight;
        return Positioned(
          top: y - 9,
          left: 0,
          right: 4,
          child: Text(
            l.$2,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: Colors.white.withOpacity(0.55),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── Background painter — zones + grid lines in a single pass ─────────────────

class _RsiBackgroundPainter extends CustomPainter {
  const _RsiBackgroundPainter();

  @override
  void paint(Canvas canvas, Size size) {
    // Overbought (RSI 70-100) — top 30 %
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height * 0.30),
      Paint()..color = const Color(0xFF2D0808),
    );
    // Neutral (RSI 30-70) — middle 40 %
    canvas.drawRect(
      Rect.fromLTWH(0, size.height * 0.30, size.width, size.height * 0.40),
      Paint()..color = const Color(0xFF090909),
    );
    // Oversold (RSI 0-30) — bottom 30 %
    canvas.drawRect(
      Rect.fromLTWH(0, size.height * 0.70, size.width, size.height * 0.30),
      Paint()..color = const Color(0xFF07130A),
    );

    // Horizontal grid lines
    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.18)
      ..strokeWidth = 1;
    for (final level in [0.0, 0.3, 0.7, 1.0]) {
      final y = level * size.height;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _RsiBackgroundPainter old) => false;
}

// ── Tech-style range slider ─────────────────────────────────────────────────

class _TechRangeSlider extends StatefulWidget {
  final RangeValues values;
  final ValueChanged<RangeValues> onChanged;
  final String startLabel;
  final String endLabel;
  final String startImage;
  final String endImage;
  final Color startColor;
  final Color endColor;

  const _TechRangeSlider({
    required this.values,
    required this.onChanged,
    required this.startLabel,
    required this.endLabel,
    required this.startImage,
    required this.endImage,
    required this.startColor,
    required this.endColor,
  });

  @override
  State<_TechRangeSlider> createState() => _TechRangeSliderState();
}

class _TechRangeSliderState extends State<_TechRangeSlider> {
  static const double _trackH = 4.0;
  static const double _thumbR = 8.0;
  static const double _hitSlop = 24.0;
  static const double _widgetH = 56.0;
  static const double _labelH = 16.0;

  int _dragging = -1;
  double _panAnchorNorm = 0.0; 
  double _panStartVal = 0.0;   
  double _panEndVal = 0.0;  

  double _thumbX(double trackW, double v) => v * trackW;

  void _handleDrag(DragUpdateDetails d, double trackW) {
    final dx = d.localPosition.dx.clamp(0.0, trackW);
    final norm = dx / trackW;
    final cur = widget.values;
    if (_dragging == 0) {
      if (norm < cur.end) widget.onChanged(RangeValues(norm, cur.end));
    } else if (_dragging == 1) {
      if (norm > cur.start) widget.onChanged(RangeValues(cur.start, norm));
    } else if (_dragging == 2) {
      final delta = norm - _panAnchorNorm;
      final rangeSize = _panEndVal - _panStartVal;
      var newStart = (_panStartVal + delta).clamp(0.0, 1.0 - rangeSize);
      var newEnd = newStart + rangeSize;
      widget.onChanged(RangeValues(newStart, newEnd));
    }
  }

  void _handleDown(DragDownDetails d, double trackW) {
    final dx = d.localPosition.dx;
    final sx = _thumbX(trackW, widget.values.start);
    final ex = _thumbX(trackW, widget.values.end);
    final dStart = (dx - sx).abs();
    final dEnd = (dx - ex).abs();
    if (dStart <= _hitSlop) {
      _dragging = 0;
    } else if (dEnd <= _hitSlop) {
      _dragging = 1;
    } else if (dx > sx && dx < ex) {
      _dragging = 2;
      _panAnchorNorm = dx / trackW;
      _panStartVal = widget.values.start;
      _panEndVal = widget.values.end;
    } else {
      _dragging = -1;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _widgetH,
      child: LayoutBuilder(
        builder: (_, constraints) {
          final trackW = constraints.maxWidth;
          final sx = widget.values.start * trackW;
          final ex = widget.values.end * trackW;
          final trackY = _widgetH * 0.55;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanDown: (d) => _handleDown(d, trackW),
            onPanUpdate: (d) => _handleDrag(d, trackW),
            onPanEnd: (_) => _dragging = -1,
            onPanCancel: () => _dragging = -1,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Track + ticks + glow + labels
                CustomPaint(
                  size: Size(trackW, _widgetH),
                  painter: _TechSliderPainter(
                    start: widget.values.start,
                    end: widget.values.end,
                    trackH: _trackH,
                    thumbR: _thumbR,
                    labelH: _labelH,
                    startLabel: widget.startLabel,
                    endLabel: widget.endLabel,
                  ),
                ),
                // Start coin thumb
                if (widget.startImage.isNotEmpty)
                  Positioned(
                    left: sx - _thumbR,
                    top: trackY - _thumbR,
                    child: _ThumbCoin(
                      imageUrl: widget.startImage,
                      symbol: widget.startLabel,
                      color: widget.startColor,
                      size: _thumbR * 2,
                    ),
                  ),
                // End coin thumb
                if (widget.endImage.isNotEmpty)
                  Positioned(
                    left: ex - _thumbR,
                    top: trackY - _thumbR,
                    child: _ThumbCoin(
                      imageUrl: widget.endImage,
                      symbol: widget.endLabel,
                      color: widget.endColor,
                      size: _thumbR * 2,
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _TechSliderPainter extends CustomPainter {
  final double start;
  final double end;
  final double trackH;
  final double thumbR;
  final double labelH;
  final String startLabel;
  final String endLabel;

  const _TechSliderPainter({
    required this.start,
    required this.end,
    required this.trackH,
    required this.thumbR,
    required this.labelH,
    required this.startLabel,
    required this.endLabel,
  });

  static const _blue = Color(0xFF5BA3FF);
  static const _cyan = Color(0xFF00E5FF);

  @override
  void paint(Canvas canvas, Size size) {
    final trackY = size.height * 0.55;
    final sx = start * size.width;
    final ex = end * size.width;
    final inactiveRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, trackY - trackH / 2, size.width, trackH),
      const Radius.circular(2),
    );
    canvas.drawRRect(
      inactiveRRect,
      Paint()
        ..shader = LinearGradient(
          colors: [Colors.white.withOpacity(0.06), Colors.white.withOpacity(0.12)],
        ).createShader(Rect.fromLTWH(0, 0, size.width, trackH)),
    );

    final activeRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(sx, trackY - trackH / 2, ex - sx, trackH),
      const Radius.circular(2),
    );
    canvas.drawRRect(
      activeRRect,
      Paint()
        ..shader = const LinearGradient(
          colors: [_blue, _cyan],
        ).createShader(Rect.fromLTWH(0, 0, 1, 1).translate(0, 0)),
    );
    canvas.drawRRect(
      activeRRect,
      Paint()
        ..shader = LinearGradient(
          colors: const [_blue, _cyan],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ).createShader(Rect.fromLTWH(sx, trackY - trackH / 2, ex - sx, trackH)),
    );

    _drawThumbGlow(canvas, Offset(sx, trackY));
    _drawThumbGlow(canvas, Offset(ex, trackY));

    if (startLabel.isNotEmpty) {
      _drawLabel(canvas, startLabel, Offset(sx, trackY - thumbR - 4), size);
    }
    if (endLabel.isNotEmpty) {
      _drawLabel(canvas, endLabel, Offset(ex, trackY - thumbR - 4), size);
    }
  }

  void _drawThumbGlow(Canvas canvas, Offset center) {
    canvas.drawCircle(
      center,
      thumbR + 6,
      Paint()
        ..color = _blue.withOpacity(0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
  }

  void _drawLabel(Canvas canvas, String text, Offset anchor, Size size) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: _cyan,
          fontSize: 9,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final dx = (anchor.dx - tp.width / 2).clamp(0.0, size.width - tp.width);
    final dy = anchor.dy - tp.height;
    tp.paint(canvas, Offset(dx, dy));
  }

  @override
  bool shouldRepaint(covariant _TechSliderPainter old) =>
      old.start != start ||
      old.end != end ||
      old.startLabel != startLabel ||
      old.endLabel != endLabel;
}


class _ThumbCoin extends StatelessWidget {
  final String imageUrl;
  final String symbol;
  final Color color;
  final double size;

  const _ThumbCoin({
    required this.imageUrl,
    required this.symbol,
    required this.color,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFF00E5FF), width: 2),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.55),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: ClipOval(
        child: Image.network(
          imageUrl,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            color: color.withOpacity(0.3),
            child: Center(
              child: Text(
                symbol.isNotEmpty ? symbol[0] : '?',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CoinCircle extends StatelessWidget {
  final RsiTokenPoint token;
  final double size;

  const _CoinCircle({required this.token, required this.size});

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: token.color, width: 2.5),
          boxShadow: [
            BoxShadow(
              color: token.color.withOpacity(0.4),
              blurRadius: 10,
              spreadRadius: 1,
            ),
          ],
        ),
        child: ClipOval(
          child: Image.network(
            token.image,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              color: token.color.withOpacity(0.25),
              child: Center(
                child: Text(
                  token.symbol.isNotEmpty ? token.symbol[0] : '?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

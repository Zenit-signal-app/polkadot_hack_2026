import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

const _kBaseChartUrl = 'https://zenit-chart.seerbot.io/';

enum TradingViewIndicator {
  /// Average Directional Index.
  adx('ADX'),

  /// Parabolic SAR.
  psar('PSAR'),

  /// RSI – 14-period.
  rsi14('RSI14'),

  /// RSI – 7-period.
  rsi7('RSI7'),

  /// MACD.
  macd('MACD'),

  /// Bollinger Bands.
  bollingerBands('BB'),

  /// EMA – 20-period.
  ema20('EMA20'),

  /// EMA – 50-period.
  ema50('EMA50'),

  /// SMA – 20-period.
  sma20('SMA20'),

  /// Stochastic Oscillator.
  stochastic('STOCH'),

  /// Volume.
  volume('VOL');

  const TradingViewIndicator(this.id);

  final String id;
}

class TradingViewChart extends StatefulWidget {
  /// TradingView symbol identifier, e.g. `"BINANCE:BTCUSDT"`.
  final String symbol;

  /// Indicators to overlay on the chart.
  final List<TradingViewIndicator> indicators;

  /// Timeframe in minutes (optional). E.g. 15 for 15m, 60 for 1h, 240 for 4h.
  final int? timeframe;

  /// Height of the chart widget. Defaults to 400.
  final double height;

  /// Optional callback fired once the page has fully loaded.
  final VoidCallback? onReady;

  const TradingViewChart({
    super.key,
    required this.symbol,
    this.indicators = const [],
    this.timeframe,
    this.height = 400,
    this.onReady,
  });

  @override
  State<TradingViewChart> createState() => _TradingViewChartState();
}

class _TradingViewChartState extends State<TradingViewChart>
    with AutomaticKeepAliveClientMixin {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  bool get wantKeepAlive => true;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _controller = _createController();
    _loadChart();
  }

  @override
  void didUpdateWidget(covariant TradingViewChart old) {
    super.didUpdateWidget(old);
    if (old.symbol != widget.symbol ||
        !_indicatorsEqual(old.indicators, widget.indicators) ||
        old.timeframe != widget.timeframe) {
      setState(() => _isLoading = true);
      _loadChart();
    }
  }

  // ── Controller setup ──────────────────────────────────────────────────────

  WebViewController _createController() {
    return WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      // Match the app dark background immediately to eliminate white flash.
      ..setBackgroundColor(const Color(0xFF0A1628))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() => _isLoading = true);
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _isLoading = false);
            widget.onReady?.call();
          },
          onWebResourceError: (_) {
            if (mounted) setState(() => _isLoading = false);
          },
        ),
      );
  }

  // ── URL builder ───────────────────────────────────────────────────────────

  Uri _buildChartUri() {
    final params = <String, String>{'symbol': widget.symbol};
    if (widget.indicators.isNotEmpty) {
      params['indicators'] = widget.indicators.map((i) => i.id).join(',');
    }
    if (widget.timeframe != null) {
      params['timeframe'] = widget.timeframe.toString();
    }
    return Uri.parse(_kBaseChartUrl).replace(queryParameters: params);
  }

  void _loadChart() => _controller.loadRequest(_buildChartUri());

  // ── Helpers ───────────────────────────────────────────────────────────────

  static bool _indicatorsEqual(
    List<TradingViewIndicator> a,
    List<TradingViewIndicator> b,
  ) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    super.build(context); // required by AutomaticKeepAliveClientMixin

    return SizedBox(
      height: widget.height,
      child: Stack(
        children: [
          WebViewWidget(
            controller: _controller,
            gestureRecognizers: {
              Factory<VerticalDragGestureRecognizer>(
                () => VerticalDragGestureRecognizer(),
              ),
              Factory<HorizontalDragGestureRecognizer>(
                () => HorizontalDragGestureRecognizer(),
              ),
              Factory<ScaleGestureRecognizer>(() => ScaleGestureRecognizer()),
            },
          ),

          // Shimmer overlay fades out once the chart is loaded.
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _isLoading
                ? _LoadingPlaceholder(key: const ValueKey('loader'))
                : const SizedBox.shrink(key: ValueKey('done')),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Loading placeholder
// ─────────────────────────────────────────────────────────────────────────────

class _LoadingPlaceholder extends StatefulWidget {
  const _LoadingPlaceholder({super.key});

  @override
  State<_LoadingPlaceholder> createState() => _LoadingPlaceholderState();
}

class _LoadingPlaceholderState extends State<_LoadingPlaceholder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmerCtrl;
  late final Animation<double> _shimmerAnim;

  @override
  void initState() {
    super.initState();
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _shimmerAnim = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _shimmerCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _shimmerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shimmerAnim,
      builder: (context, _) {
        final base = const Color(0xFF0D1E35);
        final highlight = const Color(0xFF162744);
        final t = _shimmerAnim.value;
        final color = Color.lerp(base, highlight, t)!;
        return Container(
          color: const Color(0xFF0A1628),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Fake price bar — full-width inside Column, so a regular Container works.
              Container(height: 36, color: color),
              const SizedBox(height: 8),
              // Fake toolbar row – use fixed widths inside Row to avoid
              // unbounded-width errors with FractionallySizedBox.
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    _ShimmerBox(color: color, height: 20, width: 48),
                    const SizedBox(width: 8),
                    _ShimmerBox(color: color, height: 20, width: 32),
                    const SizedBox(width: 8),
                    _ShimmerBox(color: color, height: 20, width: 32),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Fake candles area
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Container(
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }
}

class _ShimmerBox extends StatelessWidget {
  const _ShimmerBox({
    required this.color,
    required this.height,
    required this.width,
  });

  final Color color;
  final double height;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/store/user_store.dart';
import '../../data/models/rsi_response_model.dart';
import '../../data/services/signal_tool_service.dart';
import 'rsi_line_chart.dart';
import 'rsi_tabs_with_signals.dart';

/// Shows RSI14 / RSI7 line charts and overbought/oversold signal tables.
///
/// Calls `signal-tools/<indicatorCode>?symbol=...&timeframe=...` internally.
/// Re-fetches whenever [symbol] or [timeframe] changes.
class OverboughtOversoldSection extends StatefulWidget {
  final String symbol;
  final String timeframe;
  final String indicatorCode;
  final String tokenImageUrl;
  final String tokenShortSymbol;

  const OverboughtOversoldSection({
    super.key,
    required this.symbol,
    required this.timeframe,
    required this.indicatorCode,
    required this.tokenImageUrl,
    required this.tokenShortSymbol,
  });

  @override
  State<OverboughtOversoldSection> createState() =>
      _OverboughtOversoldSectionState();
}

class _OverboughtOversoldSectionState extends State<OverboughtOversoldSection> {
  late SignalToolService _service;
  RsiResponse? _response;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final apiClient = ApiClient()
      ..setAuthToken(context.read<UserStore>().state.accessToken);
    _service = SignalToolService(apiClient: apiClient);
    _loadData();
  }

  @override
  void didUpdateWidget(OverboughtOversoldSection old) {
    super.didUpdateWidget(old);
    if (old.symbol != widget.symbol || old.timeframe != widget.timeframe) {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final response = await _service.getRsiData(
        symbol: widget.symbol,
        timeframe: widget.timeframe,
      );
      if (!mounted) return;
      setState(() {
        _response = response;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load RSI data';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator(color: AppColors.blue)),
      );
    }
    if (_error != null) {
      return _ErrorRetry(message: _error!, onRetry: _loadData);
    }

    final rsi = _response;
    if (rsi == null) return const SizedBox.shrink();

    final rsi14Data = rsi.rsi14ChartData;
    final rsi7Data = rsi.rsi7ChartData;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // RSI 14 line chart
        if (rsi14Data.isNotEmpty) ...[
          _ChartTitle(label: 'RSI 14', color: const Color(0xFF3B82F6)),
          const SizedBox(height: 8),
          RsiLineChart(
            rsiData: rsi14Data,
            height: 180,
            lineColor: const Color(0xFF3B82F6),
          ),
          const SizedBox(height: 16),
        ],

        // RSI 7 line chart
        if (rsi7Data.isNotEmpty) ...[
          _ChartTitle(label: 'RSI 7', color: const Color(0xFFF59E0B)),
          const SizedBox(height: 8),
          RsiLineChart(
            rsiData: rsi7Data,
            height: 180,
            lineColor: const Color(0xFFF59E0B),
          ),
          const SizedBox(height: 16),
        ],

        // Overbought / Oversold signal tables
        if (rsi14Data.isNotEmpty)
          RsiTabsWithSignals(
            symbol: widget.symbol,
            timeframe: widget.timeframe,
            tokenImageUrl: widget.tokenImageUrl,
            code: widget.indicatorCode,
          ),
      ],
    );
  }
}

// ── Helper widgets ───────────────────────────────────────────────────────────

class _ChartTitle extends StatelessWidget {
  final String label;
  final Color color;

  const _ChartTitle({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }
}

class _ErrorRetry extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorRetry({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              style: const TextStyle(color: AppColors.white, fontSize: 13),
            ),
            const SizedBox(height: 10),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

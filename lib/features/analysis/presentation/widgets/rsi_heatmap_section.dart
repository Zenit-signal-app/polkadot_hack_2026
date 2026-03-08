import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/store/user_store.dart';
import '../../data/models/rsi_response_model.dart';
import '../../data/services/signal_tool_service.dart';
import 'rsi_heatmap_chart.dart';

/// Self-contained RSI heatmap bubble chart.
///
/// Calls `signal-tools/rsi_heatmap/latest?timeframe=...` internally.
/// Re-fetches whenever [timeframe] or [heatmapRsiType] changes.
class RsiHeatmapSection extends StatefulWidget {
  final String timeframe;

  /// Which RSI variant to display: `'rsi14'` or `'rsi7'`.
  final String heatmapRsiType;

  const RsiHeatmapSection({
    super.key,
    required this.timeframe,
    required this.heatmapRsiType,
  });

  @override
  State<RsiHeatmapSection> createState() => _RsiHeatmapSectionState();
}

class _RsiHeatmapSectionState extends State<RsiHeatmapSection> {
  late SignalToolService _service;
  List<RsiLatestItem> _items = const [];
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
  void didUpdateWidget(RsiHeatmapSection old) {
    super.didUpdateWidget(old);
    if (old.timeframe != widget.timeframe ||
        old.heatmapRsiType != widget.heatmapRsiType) {
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
      final items = await _service.getRsiLatestAll(timeframe: widget.timeframe);
      if (!mounted) return;
      setState(() {
        _items = items;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load heatmap';
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

    final heatmapTokens =
        _items
            .map((item) {
              final val = widget.heatmapRsiType == 'rsi14'
                  ? item.rsi14
                  : item.rsi7;
              if (val == null) return null;
              // Filter out items with empty symbol or image
              if (item.shortSymbol.isEmpty || item.image.isEmpty) return null;
              return RsiTokenPoint(
                symbol: item.shortSymbol,
                image: item.image,
                rsiValue: val,
                xPosition: ((val - 1) / 98).clamp(0.05, 0.95),
                color: _rsiColor(val),
              );
            })
            .whereType<RsiTokenPoint>()
            .toList()
          ..sort((a, b) => a.rsiValue.compareTo(b.rsiValue));

    if (heatmapTokens.isEmpty) return const SizedBox.shrink();

    return RsiHeatmapChart(tokens: heatmapTokens, height: 500);
  }

  Color _rsiColor(double rsi) {
    if (rsi >= 70) return const Color(0xFFEF4444);
    if (rsi <= 30) return const Color(0xFF22C55E);
    return const Color(0xFF3B82F6);
  }
}

// ── Shared error/retry widget ────────────────────────────────────────────────

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

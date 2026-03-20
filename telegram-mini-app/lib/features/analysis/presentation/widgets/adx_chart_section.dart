import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/store/user_store.dart';
import '../../data/models/adx_response_model.dart';
import '../../data/services/signal_tool_service.dart';
import 'generic_line_chart.dart';

/// Shows the ADX line chart (only the `adx` field from the API response).
///
/// Calls `signal-tools/adx?symbol=...&timeframe=...` internally.
/// Re-fetches whenever [symbol] or [timeframe] changes.
class AdxChartSection extends StatefulWidget {
  final String symbol;
  final String timeframe;

  const AdxChartSection({
    super.key,
    required this.symbol,
    required this.timeframe,
  });

  @override
  State<AdxChartSection> createState() => _AdxChartSectionState();
}

class _AdxChartSectionState extends State<AdxChartSection> {
  late SignalToolService _service;
  AdxResponse? _response;
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
  void didUpdateWidget(AdxChartSection old) {
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
      final response = await _service.getAdxData(
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
        _error = 'Failed to load ADX data';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(
        height: 200,
        child: Center(
          child: CircularProgressIndicator(color: AppColors.blue),
        ),
      );
    }
    if (_error != null) {
      return _ErrorRetry(message: _error!, onRetry: _loadData);
    }

    final adxData = _response?.adxChartData ?? const [];
    if (adxData.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ChartTitle(label: 'ADX (14)', color: const Color(0xFFF59E0B)),
        const SizedBox(height: 8),
        GenericLineChart(
          height: 200,
          series: [
            ChartSeries(
              label: 'ADX',
              data: adxData,
              color: const Color(0xFFF59E0B),
              fill: true,
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Legend
        Row(
          children: const [
            _LegendDot(color: Color(0xFFF59E0B), label: 'ADX'),
          ],
        ),
        const SizedBox(height: 24),
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

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w500,
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
            Text(message,
                style: const TextStyle(color: AppColors.white, fontSize: 13)),
            const SizedBox(height: 10),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

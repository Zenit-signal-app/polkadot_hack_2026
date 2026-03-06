import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/api_client.dart';
import '../../data/models/rsi_response_model.dart';
import '../../data/services/signal_tool_service.dart';

/// Main widget containing tabs and signal list
/// Fetches RSI data internally based on symbol and timeframe
class RsiTabsWithSignals extends StatefulWidget {
  final String symbol;
  final String timeframe;
  final String? tokenImageUrl;

  const RsiTabsWithSignals({
    super.key,
    required this.symbol,
    required this.timeframe,
    this.tokenImageUrl,
  });

  @override
  State<RsiTabsWithSignals> createState() => _RsiTabsWithSignalsState();
}

class _RsiTabsWithSignalsState extends State<RsiTabsWithSignals> {
  String _selectedTab = 'oversold';
  late SignalToolService _service;
  RsiResponse? _rsiResponse;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    final apiClient = ApiClient();
    _service = SignalToolService(apiClient: apiClient);
    _loadRsiData();
  }

  @override
  void didUpdateWidget(covariant RsiTabsWithSignals oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.symbol != widget.symbol ||
        oldWidget.timeframe != widget.timeframe) {
      _loadRsiData();
    }
  }

  Future<void> _loadRsiData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final response = await _service.getRsiData(
        symbol: widget.symbol,
        timeframe: widget.timeframe,
      );
      if (!mounted) return;
      setState(() {
        _rsiResponse = response;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> _buildSignals(bool oversold) {
    final rsi = _rsiResponse;
    if (rsi == null) return [];

    final symbolDisplay = widget.symbol.endsWith('USDT')
        ? widget.symbol.substring(0, widget.symbol.length - 4)
        : widget.symbol;

    return rsi.data
        .where(
          (r) => r.rsi14 != null && (oversold ? r.rsi14! < 30 : r.rsi14! > 70),
        )
        .map((r) {
          final dt = r.dateTime;
          return {
            'pair': '$symbolDisplay/USDT',
            'rsi': r.rsi14!.toStringAsFixed(1),
            'date':
                '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}',
            'time':
                '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}',
          };
        })
        .toList();
  }

  void _handleTabChange(String tab) {
    setState(() {
      _selectedTab = tab;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: const Color.fromRGBO(22, 30, 51, 1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: AppColors.blue),
        ),
      );
    }

    final oversoldSignals = _buildSignals(true);
    final overboughtSignals = _buildSignals(false);

    return Container(
      decoration: BoxDecoration(
        color: const Color.fromRGBO(22, 30, 51, 1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // Tabs - pass state and callback down
          _TabSelector(
            selectedTab: _selectedTab,
            onTabChanged: _handleTabChange,
          ),
          // Signal list - receives selected tab to filter/display content
          _SignalList(
            signals: _selectedTab == 'oversold'
                ? oversoldSignals
                : overboughtSignals,
            tokenImageUrl: widget.tokenImageUrl ?? '',
            isOversold: _selectedTab == 'oversold',
          ),
        ],
      ),
    );
  }
}

/// Tab selector - now stateless, receives state from parent
class _TabSelector extends StatelessWidget {
  final String selectedTab;
  final ValueChanged<String> onTabChanged;

  const _TabSelector({required this.selectedTab, required this.onTabChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      child: Row(
        children: [
          Expanded(
            child: _TabButton(
              label: 'Over sold',
              isSelected: selectedTab == 'oversold',
              onTap: () {
                if (selectedTab != 'oversold') {
                  onTabChanged('oversold');
                }
              },
              isLeft: true,
            ),
          ),
          Expanded(
            child: _TabButton(
              label: 'Over Bought',
              isSelected: selectedTab == 'overbought',
              onTap: () {
                if (selectedTab != 'overbought') {
                  onTabChanged('overbought');
                }
              },
              isLeft: false,
            ),
          ),
        ],
      ),
    );
  }
}

/// Individual tab button - optimized with const where possible
class _TabButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isLeft;

  const _TabButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.isLeft,
  });

  @override
  Widget build(BuildContext context) {
    final BorderRadius borderRadius;

    if (isSelected) {
      borderRadius = const BorderRadius.only(
        topLeft: Radius.circular(10),
        topRight: Radius.circular(10),
        bottomLeft: Radius.circular(0),
        bottomRight: Radius.circular(0),
      );
    } else {
      borderRadius = isLeft
          ? const BorderRadius.only(
              topLeft: Radius.circular(10),
              bottomRight: Radius.circular(20),  // tiếp giáp với tab phải
            )
          : const BorderRadius.only(
              topRight: Radius.circular(10),
              bottomLeft: Radius.circular(20),  // tiếp giáp với tab trái
            );
    }

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.transparent
              : const Color.fromRGBO(9, 20, 40, 1),
          borderRadius: borderRadius,
        ),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

/// Signal list - optimized with const constructor
class _SignalList extends StatelessWidget {
  final List<Map<String, dynamic>> signals;
  final String tokenImageUrl;
  final bool isOversold;

  const _SignalList({
    required this.signals,
    required this.tokenImageUrl,
    required this.isOversold,
  });

  @override
  Widget build(BuildContext context) {
    if (signals.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: Text(
            'No signals',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 13,
            ),
          ),
        ),
      );
    }
    return Column(
      children: List.generate(
        signals.length,
        (index) => _SignalItem(
          signal: signals[index],
          tokenImageUrl: tokenImageUrl,
          isLast: index == signals.length - 1,
          isOversold: isOversold,
        ),
      ),
    );
  }
}

/// Individual signal item - extracted for better performance
class _SignalItem extends StatelessWidget {
  final Map<String, dynamic> signal;
  final String tokenImageUrl;
  final bool isLast;
  final bool isOversold;

  const _SignalItem({
    required this.signal,
    required this.tokenImageUrl,
    required this.isLast,
    required this.isOversold,
  });

  @override
  Widget build(BuildContext context) {
    final rsiColor = isOversold
        ? const Color(0xFF22C55E) // green — oversold
        : const Color(0xFFEF4444); // red — overbought
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundImage: NetworkImage(tokenImageUrl),
                backgroundColor: AppColors.darkBlue,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      signal['pair'],
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'RSI: ${signal['rsi']}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: rsiColor,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    signal['date'],
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: AppColors.white.withOpacity(0.6),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    signal['time'],
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: AppColors.white.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (!isLast)
          Divider(
            height: 1,
            thickness: 1,
            color: AppColors.gray.withOpacity(0.2),
            indent: 16,
            endIndent: 16,
          ),
      ],
    );
  }
}

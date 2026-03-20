import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/api_client.dart';
import '../../data/models/adx_response_model.dart';
import '../../data/models/psar_response_model.dart';
import '../../data/models/rsi_response_model.dart';
import '../../data/services/signal_tool_service.dart';

/// Main widget containing tabs and signal list
/// Supports RSI, ADX, and PSAR indicators based on code
class RsiTabsWithSignals extends StatefulWidget {
  final String symbol;
  final String timeframe;
  final String? tokenImageUrl;
  final String code; // 'rsi', 'adx', 'psar'

  const RsiTabsWithSignals({
    super.key,
    required this.symbol,
    required this.timeframe,
    required this.code,
    this.tokenImageUrl,
  });

  @override
  State<RsiTabsWithSignals> createState() => _RsiTabsWithSignalsState();
}

class _RsiTabsWithSignalsState extends State<RsiTabsWithSignals> {
  String _selectedTab = 'tab1';
  late SignalToolService _service;
  
  // Responses for different indicators
  RsiResponse? _rsiResponse;
  AdxResponse? _adxResponse;
  PsarResponse? _psarResponse;
  
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    final apiClient = ApiClient();
    _service = SignalToolService(apiClient: apiClient);
    _loadData();
  }

  @override
  void didUpdateWidget(covariant RsiTabsWithSignals oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.symbol != widget.symbol ||
        oldWidget.timeframe != widget.timeframe ||
        oldWidget.code != widget.code) {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    
    try {
      switch (widget.code.toLowerCase()) {
        case 'rsi':
          final response = await _service.getRsiData(
            symbol: widget.symbol,
            timeframe: widget.timeframe,
          );
          if (!mounted) return;
          setState(() {
            _rsiResponse = response;
            _isLoading = false;
          });
          break;
          
        case 'adx':
          final response = await _service.getAdxData(
            symbol: widget.symbol,
            timeframe: widget.timeframe,
          );
          if (!mounted) return;
          setState(() {
            _adxResponse = response;
            _isLoading = false;
          });
          break;
          
        case 'psar':
          final response = await _service.getPsarData(
            symbol: widget.symbol,
            timeframe: widget.timeframe,
          );
          if (!mounted) return;
          setState(() {
            _psarResponse = response;
            _isLoading = false;
          });
          break;
          
        default:
          if (!mounted) return;
          setState(() => _isLoading = false);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  (String, String) _getTabLabels() {
    final code = widget.code.toLowerCase();
    if (code == 'adx' || code == 'psar') {
      return ('Uptrend', 'Downtrend');
    }
    return ('Over sold', 'Over Bought');
  }

  List<Map<String, dynamic>> _buildSignals() {
    final symbolDisplay = widget.symbol.endsWith('USDT')
        ? widget.symbol.substring(0, widget.symbol.length - 4)
        : widget.symbol;

    switch (widget.code.toLowerCase()) {
      case 'rsi':
        return _buildRsiSignals(symbolDisplay);
      case 'adx':
        return _buildAdxSignals(symbolDisplay);
      case 'psar':
        return _buildPsarSignals(symbolDisplay);
      default:
        return [];
    }
  }

  List<Map<String, dynamic>> _buildRsiSignals(String symbolDisplay) {
    final rsi = _rsiResponse;
    if (rsi == null) return [];

    final isOversold = _selectedTab == 'tab1';
    return rsi.data
        .where((r) => r.rsi14 != null && (isOversold ? r.rsi14! < 30 : r.rsi14! > 70))
        .map((r) {
          final dt = r.dateTime;
          return {
            'pair': '$symbolDisplay/USDT',
            'value': r.rsi14!.toStringAsFixed(1),
            'label': 'RSI',
            'date': '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}',
            'time': '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}',
          };
        })
        .toList();
  }

  List<Map<String, dynamic>> _buildAdxSignals(String symbolDisplay) {
    final adx = _adxResponse;
    if (adx == null || adx.data.isEmpty) return [];

    final trendFilter = _selectedTab == 'tab1' ? 'uptrend' : 'downtrend';
    return adx.data
        .where((r) => r.trend != null && 
                     r.trend!.isNotEmpty && 
                     r.trend!.toLowerCase() == trendFilter)
        .map((r) {
          final dt = r.dateTime;
          return {
            'pair': '$symbolDisplay/USDT',
            'value': r.adx?.toStringAsFixed(1) ?? '--',
            'label': 'ADX',
            'date': '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}',
            'time': '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}',
          };
        })
        .toList();
  }

  List<Map<String, dynamic>> _buildPsarSignals(String symbolDisplay) {
    final psar = _psarResponse;
    if (psar == null || psar.data.isEmpty) return [];

    final trendFilter = _selectedTab == 'tab1' ? 'uptrend' : 'downtrend';
    return psar.data
        .where((r) => r.trend != null && 
                     r.trend!.isNotEmpty && 
                     r.trend!.toLowerCase() == trendFilter)
        .map((r) {
          final dt = r.dateTime;
          return {
            'pair': '$symbolDisplay/USDT',
            'value': r.psar?.toStringAsFixed(2) ?? '--',
            'label': 'PSAR',
            'date': '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}',
            'time': '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}',
          };
        })
        .toList();
  }

  void _handleTabChange(String tab) {
    if (_selectedTab != tab) {
      setState(() {
        _selectedTab = tab;
      });
    }
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

    final signals = _buildSignals();
    final (leftLabel, rightLabel) = _getTabLabels();

    return Container(
      decoration: BoxDecoration(
        color: const Color.fromRGBO(22, 30, 51, 1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _TabSelector(
            selectedTab: _selectedTab,
            leftLabel: leftLabel,
            rightLabel: rightLabel,
            onTabChanged: _handleTabChange,
          ),
          _SignalList(
            signals: signals,
            tokenImageUrl: widget.tokenImageUrl ?? '',
            isFirstTab: _selectedTab == 'tab1',
          ),
        ],
      ),
    );
  }
}

/// Tab selector - now stateless, receives state from parent
class _TabSelector extends StatelessWidget {
  final String selectedTab;
  final String leftLabel;
  final String rightLabel;
  final ValueChanged<String> onTabChanged;

  const _TabSelector({
    required this.selectedTab,
    required this.leftLabel,
    required this.rightLabel,
    required this.onTabChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      child: Row(
        children: [
          Expanded(
            child: _TabButton(
              label: leftLabel,
              isSelected: selectedTab == 'tab1',
              onTap: () {
                if (selectedTab != 'tab1') {
                  onTabChanged('tab1');
                }
              },
              isLeft: true,
            ),
          ),
          Expanded(
            child: _TabButton(
              label: rightLabel,
              isSelected: selectedTab == 'tab2',
              onTap: () {
                if (selectedTab != 'tab2') {
                  onTabChanged('tab2');
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
  final bool isFirstTab;

  const _SignalList({
    required this.signals,
    required this.tokenImageUrl,
    required this.isFirstTab,
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
          isFirstTab: isFirstTab,
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
  final bool isFirstTab;

  const _SignalItem({
    required this.signal,
    required this.tokenImageUrl,
    required this.isLast,
    required this.isFirstTab,
  });

  @override
  Widget build(BuildContext context) {
    // First tab is green (oversold/uptrend), second tab is red (overbought/downtrend)
    final valueColor = isFirstTab
        ? const Color(0xFF22C55E) // green
        : const Color(0xFFEF4444); // red
        
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
                      '${signal['label']}: ${signal['value']}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: valueColor,
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

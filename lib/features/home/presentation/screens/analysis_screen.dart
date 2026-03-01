import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/constants/app_colors.dart';
import '../../data/models/indicator_model.dart';
import '../widgets/header_bar.dart';
import '../widgets/indicator_item_widget.dart';

class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({super.key});

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  // Single Indicator data
  final List<IndicatorModel> _singleIndicators = const [
    IndicatorModel(
      id: 'rsi_heatmap',
      title: 'RSI Heatmap',
      description: 'It is a long established fact that a reader ...',
      type: IndicatorType.rsiHeatmap,
      icon: HugeIcons.strokeRoundedAlignBoxMiddleCenter,
      iconColor: Color(0xFF3B82F6),
    ),
    IndicatorModel(
      id: 'psar_single',
      title: 'PSAR Indicator',
      description: 'It is a long established fact that a reader ...',
      type: IndicatorType.psarIndicator,
      icon: HugeIcons.strokeRoundedChartLineData03,
      iconColor: Color(0xFF3B82F6),
    ),
    IndicatorModel(
      id: 'adx',
      title: 'ADX Indicator',
      description: 'It is a long established fact that a reader ...',
      type: IndicatorType.adxIndicator,
      icon: HugeIcons.strokeRoundedChartHistogram,
      iconColor: Color(0xFF3B82F6),
    ),
  ];

  // Confluence data
  final List<IndicatorModel> _confluenceIndicators = const [
    IndicatorModel(
      id: 'radar',
      title: 'Radar',
      description: 'It is a long established fact that a reader ...',
      type: IndicatorType.radar,
      icon: HugeIcons.strokeRoundedTarget01,
      iconColor: Color(0xFF3B82F6),
    ),
    IndicatorModel(
      id: 'psar_confluence',
      title: 'PSAR Indicator',
      description: 'It is a long established fact that a reader ...',
      type: IndicatorType.psarIndicator,
      icon: HugeIcons.strokeRoundedChartLineData03,
      iconColor: Color(0xFF3B82F6),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFF0A1628),
                const Color(0xFF0A1628).withOpacity(0.8),
              ],
            ),
          ),
          child: HeaderBar(
            title: 'Analysis',
            onMenuTap: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        
        // Content
        Expanded(
          child: Container(
            color: const Color(0xFF0A1628),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Single Indicator Section
                  _buildSectionTitle('Single Indicator'),
                  const SizedBox(height: 16),
                  ..._singleIndicators.map((indicator) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: IndicatorItemWidget(
                      indicator: indicator,
                      onTap: () => _handleIndicatorTap(indicator),
                    ),
                  )),
                  
                  const SizedBox(height: 32),
                  
                  // Confluence Section
                  _buildSectionTitle('Confluence'),
                  const SizedBox(height: 16),
                  ..._confluenceIndicators.map((indicator) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: IndicatorItemWidget(
                      indicator: indicator,
                      onTap: () => _handleIndicatorTap(indicator),
                    ),
                  )),
                  
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: AppColors.white,
        letterSpacing: 0.3,
      ),
    );
  }

  void _handleIndicatorTap(IndicatorModel indicator) {
    // TODO: Navigate to indicator detail screen
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Tapped on ${indicator.title}'),
        duration: const Duration(seconds: 1),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

class ChartTypeButtonsWidget extends StatelessWidget {
  final bool isLineChartSelected;
  final Function(bool) onChartTypeChanged;

  const ChartTypeButtonsWidget({
    super.key,
    required this.isLineChartSelected,
    required this.onChartTypeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: () => onChartTypeChanged(true),
          icon: const Icon(HugeIcons.strokeRoundedChartLineData03),
          color: isLineChartSelected
              ? const Color(0xFF3B82F6)
              : Colors.white,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 24, minHeight: 16),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: () => onChartTypeChanged(false),
          icon: const Icon(HugeIcons.strokeRoundedChartScatter),
          color: !isLineChartSelected
              ? const Color(0xFF3B82F6)
              : Colors.white,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 24, minHeight: 16),
        ),
        const SizedBox(width: 8),
      ],
    );
  }
}

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class MiniChartWidget extends StatelessWidget {
  final List<double> data;
  final Color color;
  final double height;
  final double width;

  const MiniChartWidget({
    super.key,
    required this.data,
    required this.color,
    this.height = 40,
    this.width = 60,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return SizedBox(
        height: height,
        width: width,
      );
    }

    final spots = data.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value);
    }).toList();

    return SizedBox(
      height: height,
      width: width,
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          minX: 0,
          maxX: (data.length - 1).toDouble(),
          minY: data.reduce((a, b) => a < b ? a : b) * 0.99,
          maxY: data.reduce((a, b) => a > b ? a : b) * 1.01,
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: color,
              barWidth: 2,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: color.withOpacity(0.1),
              ),
            ),
          ],
        ),
        duration: const Duration(milliseconds: 0),
      ),
    );
  }
}

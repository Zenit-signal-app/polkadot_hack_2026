import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:seerbot_signal/core/utils/price_formatter.dart';
import '../../data/models/token_model.dart';
import 'chart_type_buttons_widget.dart';

class PriceSectionWidget extends StatelessWidget {
  final TokenModel token;
  final Function(bool) onChartTypeChanged;
  final bool isLineChartSelected;

  const PriceSectionWidget({
    super.key,
    required this.token,
    required this.onChartTypeChanged,
    required this.isLineChartSelected,
  });

  @override
  Widget build(BuildContext context) {
    final priceColor = token.isPriceUp
        ? const Color(0xFF00C853)
        : const Color(0xFFFF1744);
    final formattedPrice = numberFormatter(token.currentPrice);
    final formattedChange =numberFormatter(token.priceChange);
    final formattedPercentage = NumberFormat('0.00').format(
      token.priceChangePercentage.abs(),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formattedPrice,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: -1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          '${token.isPriceUp ? '+' : ''}$formattedChange',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: priceColor,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '(${token.isPriceUp ? '+' : '-'}$formattedPercentage%)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: priceColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              ChartTypeButtonsWidget(
                isLineChartSelected: isLineChartSelected,
                onChartTypeChanged: onChartTypeChanged,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

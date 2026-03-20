import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/utils/price_formatter.dart';

class PriceDisplayWidget extends StatelessWidget {
  final double price;
  final int? decimals;
  final double priceChangePercentage;
  final bool isPriceUp;

  const PriceDisplayWidget({
    super.key,
    required this.price,
    this.decimals,
    required this.priceChangePercentage,
    required this.isPriceUp,
  });

  @override
  Widget build(BuildContext context) {
    final priceColor = isPriceUp ? const Color(0xFF00C853) : const Color(0xFFFF1744);
    final formattedPrice = numberFormatter(price, decimals: decimals);
    final formattedPercentage = NumberFormat('0.00').format(priceChangePercentage.abs());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          formattedPrice,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.end,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${isPriceUp ? '+' : '-'}$formattedPercentage%',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.end,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: priceColor,
          ),
        ),
      ],
    );
  }
}

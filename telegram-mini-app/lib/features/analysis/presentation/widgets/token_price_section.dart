import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/price_formatter.dart';
import '../../../../features/home/data/models/token_model.dart';
import '../../../../shared/widgets/token_selector_button.dart';

class TokenPriceSection extends StatelessWidget {
  final TokenModel selectedToken;
  final bool isFavorite;
  final VoidCallback onTokenSelectorTap;
  final VoidCallback onFavoriteTap;

  const TokenPriceSection({
    super.key,
    required this.selectedToken,
    required this.isFavorite,
    required this.onTokenSelectorTap,
    required this.onFavoriteTap,
  });

  @override
  Widget build(BuildContext context) {
    final priceColor = selectedToken.isPriceUp
        ? const Color(0xFF00C853)
        : const Color(0xFFFF1744);
    final formattedPrice = numberFormatter(selectedToken.currentPrice, decimals: selectedToken.decimals);
    final formattedChange = numberFormatter(selectedToken.priceChange.abs(), decimals: selectedToken.decimals);
    final formattedPercentage = NumberFormat('0.00').format(selectedToken.priceChangePercentage.abs());

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Token selector and favorite icon
          Row(
            children: [
              TokenSelectorButton(
                symbol: selectedToken.symbol,
                imageUrl: selectedToken.imageUrl,
                onTap: onTokenSelectorTap,
              ),
              const Spacer(),
              IconButton(
                onPressed: onFavoriteTap,
                icon: Icon(
                  HugeIcons.strokeRoundedStar,
                  color: isFavorite
                      ? const Color(0xFFFBBF24)
                      : AppColors.white.withOpacity(0.5),
                ),
                iconSize: 24,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Price and Volume row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Price section (left side)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Price and USDT
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '\$$formattedPrice',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: AppColors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Padding(
                          padding: EdgeInsets.only(bottom: 4),
                          child: Text(
                            'USDT',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: AppColors.gray,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Price change
                    Row(
                      children: [
                        Text(
                          '${selectedToken.isPriceUp ? '+' : '-'}\$$formattedChange',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: priceColor,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: priceColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${selectedToken.isPriceUp ? '+' : '-'}$formattedPercentage%',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: priceColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Volume section (right side)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Volume 24H (BTC)',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                      color: AppColors.white.withOpacity(0.6),
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    '23,536.69',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Volume 24H (USDT)',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                      color: AppColors.white.withOpacity(0.6),
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    '1.63B',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

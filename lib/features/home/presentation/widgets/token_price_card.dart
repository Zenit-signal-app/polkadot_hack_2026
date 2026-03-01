import 'package:flutter/material.dart';
import 'package:visibility_detector/visibility_detector.dart';
import '../../data/models/token_model.dart';
import 'mini_chart_widget.dart';
import 'price_display_widget.dart';
import 'token_info_widget.dart';

class TokenPriceCard extends StatelessWidget {
  final TokenModel token;
  final VoidCallback? onTap;
  final VoidCallback? onVisible;

  const TokenPriceCard({
    super.key,
    required this.token,
    this.onTap,
    this.onVisible,
  });

  @override
  Widget build(BuildContext context) {
    final chartColor = token.isPriceUp
        ? const Color(0xFF00C853)
        : const Color(0xFFFF1744);

    return VisibilityDetector(
      key: ValueKey('token-card-${token.symbol}'),
      onVisibilityChanged: (info) {
        if (info.visibleFraction > 0.3) {
          onVisible?.call();
        }
      },
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF1E3A5F).withOpacity(0.6),
                const Color(0xFF0F1C2E).withOpacity(0.8),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withOpacity(0.1),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: TokenInfoWidget(
                  symbol: token.symbol,
                  pair: token.pair,
                  imageUrl: token.imageUrl,
                ),
              ),

              const SizedBox(width: 16),

              MiniChartWidget(
                data: token.chartData,
                color: chartColor,
                height: 50,
                width: 80,
              ),

              const SizedBox(width: 16),

              PriceDisplayWidget(
                price: token.currentPrice,
                decimals: token.decimals,
                priceChangePercentage: token.priceChangePercentage,
                isPriceUp: token.isPriceUp,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

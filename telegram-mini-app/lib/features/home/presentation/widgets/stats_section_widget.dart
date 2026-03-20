import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/models/token_model.dart';

class StatsSectionWidget extends StatelessWidget {
  final TokenModel token;
  final double? high;
  final double? low;
  final double? volume;
  final double? quoteVolume;

  const StatsSectionWidget({
    super.key,
    required this.token,
    this.high,
    this.low,
    this.volume,
    this.quoteVolume,
  });
  
  String _formatPrice(double? price) {
    if (price == null) return '--';
    if (price >= 1) {
      return NumberFormat('\$#,##0.00').format(price);
    } else if (price >= 0.0001) {
      return NumberFormat('\$#,##0.0000').format(price);
    } else {
      return NumberFormat('\$#,##0.00000000').format(price);
    }
  }
  
  String _formatVolume(double? vol) {
    if (vol == null) return '--';
    if (vol >= 1000000000) {
      return '${NumberFormat('#,##0.00').format(vol / 1000000000)}B';
    } else if (vol >= 1000000) {
      return '${NumberFormat('#,##0.00').format(vol / 1000000)}M';
    } else if (vol >= 1000) {
      return '${NumberFormat('#,##0.00').format(vol / 1000)}K';
    } else {
      return NumberFormat('#,##0.00').format(vol);
    }
  }
  
  /// Parse symbol to extract baseAsset and quoteAsset
  Map<String, String> _parseSymbol(String symbol) {
    // Common quote assets
    const quoteAssets = ['USDT', 'BUSD', 'USDC', 'BTC', 'ETH', 'BNB', 'USD'];
    
    for (final quote in quoteAssets) {
      if (symbol.endsWith(quote)) {
        final base = symbol.substring(0, symbol.length - quote.length);
        if (base.isNotEmpty) {
          return {'base': base, 'quote': quote};
        }
      }
    }
    
    // Fallback if no match
    return {'base': symbol, 'quote': ''};
  }

  @override
  Widget build(BuildContext context) {
    final symbolParts = _parseSymbol(token.symbol);
    final baseAsset = symbolParts['base'] ?? '';
    final quoteAsset = symbolParts['quote'] ?? '';
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          // Row 1: Current Price | High
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  'Current Price',
                  _formatPrice(token.currentPrice),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatItem(
                  'High',
                  _formatPrice(high),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Row 2: Low | Volume (BaseAsset)
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  'Low',
                  _formatPrice(low),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatItem(
                  baseAsset.isNotEmpty ? 'Volume ($baseAsset)' : 'Volume (BaseAsset)',
                  _formatVolume(volume),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Row 3: Volume (QuoteAsset)
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  quoteAsset.isNotEmpty ? 'Volume ($quoteAsset)' : 'Volume (QuoteAsset)',
                  _formatVolume(quoteVolume),
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(child: SizedBox()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: Colors.white.withOpacity(0.5),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/models/token_model.dart';

class StatsSectionWidget extends StatelessWidget {
  final TokenModel token;
  final double? high;
  final double? low;
  final double? volume;

  const StatsSectionWidget({
    super.key,
    required this.token,
    this.high,
    this.low,
    this.volume,
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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          // Current Price Row
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
                  'Volume',
                  _formatVolume(volume),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // High/Low Row
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  'High',
                  _formatPrice(high),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatItem(
                  'Low',
                  _formatPrice(low),
                ),
              ),
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

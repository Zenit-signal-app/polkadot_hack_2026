import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/models/token_model.dart';

class StatsSectionWidget extends StatelessWidget {
  final TokenModel token;

  const StatsSectionWidget({
    super.key,
    required this.token,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          // Reference Price Row
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  'Reference Price',
                  NumberFormat('\$#,##0.0000').format(token.currentPrice * 0.999),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatItem(
                  'Reference Price',
                  NumberFormat('\$#,##0.0000').format(token.currentPrice * 1.001),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // 24h High/Low Row
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  '24h High',
                  NumberFormat('\$#,##0.0000').format(token.currentPrice * 1.05),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatItem(
                  '24h Low',
                  NumberFormat('\$#,##0.0000').format(token.currentPrice * 0.95),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Volume Row
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  '24h Volume (SOL)',
                  '400.000',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatItem(
                  '24h Volume (USD)',
                  '400.000',
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

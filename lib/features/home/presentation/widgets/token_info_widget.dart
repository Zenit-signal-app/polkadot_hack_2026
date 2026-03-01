import 'package:flutter/material.dart';

class TokenInfoWidget extends StatelessWidget {
  final String symbol;
  final String pair;
  final String? imageUrl;
  final double iconSize;

  const TokenInfoWidget({
    super.key,
    required this.symbol,
    required this.pair,
    this.imageUrl,
    this.iconSize = 40,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.max,
      children: [
        // Token Icon
        Container(
          width: iconSize,
          height: iconSize,
          decoration: BoxDecoration(
            color: const Color(0xFFFF9800),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF9800).withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: imageUrl != null && imageUrl!.isNotEmpty
                ? ClipOval(
                    child: Image.network(
                      imageUrl!,
                      width: iconSize * 0.7,
                      height: iconSize * 0.7,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return _buildDefaultIcon();
                      },
                    ),
                  )
                : _buildDefaultIcon(),
          ),
        ),
        const SizedBox(width: 12),
        // Token Info
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                pair,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 2),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDefaultIcon() {
    return Text(
      symbol.isNotEmpty ? symbol[0].toUpperCase() : '₿',
      style: TextStyle(
        fontSize: iconSize * 0.5,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    );
  }
}

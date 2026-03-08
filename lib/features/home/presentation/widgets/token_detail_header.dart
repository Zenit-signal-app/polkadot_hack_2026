import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../../core/constants/app_colors.dart';

class TokenDetailHeader extends StatelessWidget {
  final String symbol;
  final String? imageUrl;
  final bool isFavorite;
  final VoidCallback onFavoriteTap;
  final VoidCallback onBackTap;

  const TokenDetailHeader({
    super.key,
    required this.symbol,
    this.imageUrl,
    required this.isFavorite,
    required this.onFavoriteTap,
    required this.onBackTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 20, 18),
      child: Row(
        children: [
          // Back Button
          IconButton(
            onPressed: onBackTap,
            icon: const Icon(HugeIcons.strokeRoundedArrowLeft01),
            color: AppColors.white,
            padding: EdgeInsets.zero,
          ),
          const SizedBox(width: 12),
          
          // Token Icon
          SizedBox(
            width: 32,
            height: 32,
            child: imageUrl != null && imageUrl!.isNotEmpty
                ? ClipOval(
                    child: Image.network(
                      imageUrl!,
                      width: 32,
                      height: 32,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return _buildDefaultIcon();
                      },
                    ),
                  )
                : _buildDefaultIcon(),
          ),
          const SizedBox(width: 12),
          
          // Token Symbol
          Text(
            symbol,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppColors.white,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
          ),
          
          const Spacer(),
          
          // Favorite Star Button
          IconButton(
            onPressed: onFavoriteTap,
            icon: Icon(
              isFavorite
                  ? HugeIcons.strokeRoundedStar
                  : HugeIcons.strokeRoundedStar,
            ),
            color: isFavorite ? Colors.yellow : AppColors.white,
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultIcon() {
    return Container(
      width: 32,
      height: 32,
      decoration: const BoxDecoration(
        color: Color(0xFFFF9800),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          symbol.isNotEmpty ? symbol[0].toUpperCase() : '₿',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

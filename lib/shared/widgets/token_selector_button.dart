import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/constants/app_colors.dart';

class TokenSelectorButton extends StatelessWidget {
  final String symbol;
  final String? imageUrl;
  final VoidCallback onTap;

  const TokenSelectorButton({
    super.key,
    required this.symbol,
    this.imageUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.darkBlue.withOpacity(0.5),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: AppColors.white.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (imageUrl != null) ...[
              CircleAvatar(
                radius: 12,
                backgroundImage: NetworkImage(imageUrl!),
                backgroundColor: AppColors.darkBlue,
              ),
              const SizedBox(width: 8),
            ],
            Text(
              symbol,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.white,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              HugeIcons.strokeRoundedArrowDown01,
              color: AppColors.white,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../features/home/data/models/token_model.dart';

class TokenListItem extends StatelessWidget {
  final TokenModel token;
  final bool isSelected;
  final VoidCallback onTap;

  const TokenListItem({
    super.key,
    required this.token,
    this.isSelected = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: isSelected 
              ? AppColors.blue.withOpacity(0.1) 
              : Colors.transparent,
          border: Border(
            bottom: BorderSide(
              color: AppColors.white.withOpacity(0.05),
              width: 1,
            ),
          ),
        ),
        child: Row(
          children: [
            // Token icon
            CircleAvatar(
              radius: 20,
              backgroundImage: NetworkImage(token.imageUrl),
              backgroundColor: AppColors.darkBlue,
            ),
            const SizedBox(width: 12),
            // Token info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    token.symbol,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    token.name,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: AppColors.white.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
            // Selection indicator
            if (isSelected)
              const Icon(
                Icons.check_circle,
                color: AppColors.blue,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}

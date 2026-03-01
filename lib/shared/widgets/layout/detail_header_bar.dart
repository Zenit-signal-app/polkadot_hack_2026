import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/constants/app_colors.dart';

class DetailHeaderBar extends StatelessWidget {
  const DetailHeaderBar({
    super.key,
    required this.title,
    this.onBackTap,
    this.trailing,
  });

  final String title;
  final VoidCallback? onBackTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Row(
        children: [
          IconButton(
            onPressed: onBackTap ?? () => Navigator.of(context).pop(),
            icon: const Icon(HugeIcons.strokeRoundedArrowLeft01),
            color: AppColors.white,
            padding: EdgeInsets.zero,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppColors.white,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
          ),
          if (trailing != null) trailing!,
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                onPressed: () {},
                icon: const Icon(HugeIcons.strokeRoundedNotification03),
                color: AppColors.white,
                padding: EdgeInsets.zero,
              ),
              Positioned(
                right: 4,
                top: 4,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE02424),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

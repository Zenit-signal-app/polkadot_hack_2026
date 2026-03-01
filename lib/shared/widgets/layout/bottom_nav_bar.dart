import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/constants/app_colors.dart';

class BottomNavBar extends StatelessWidget {
  const BottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.darkBlue,
          boxShadow: [
            BoxShadow(
              color: Color(0x22000000),
              blurRadius: 16,
              offset: Offset(0, -6),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: currentIndex,
          onTap: onTap,
          type: BottomNavigationBarType.fixed,
          backgroundColor: AppColors.darkBlue,
          selectedItemColor: AppColors.white,
          unselectedItemColor: AppColors.gray,
          selectedFontSize: 12,
          unselectedFontSize: 12,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(HugeIcons.strokeRoundedHome01, color: AppColors.gray),
              activeIcon: Icon(HugeIcons.strokeRoundedHome01, color: AppColors.white),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(HugeIcons.strokeRoundedChart01, color: AppColors.gray),
              activeIcon: Icon(HugeIcons.strokeRoundedChart01, color: AppColors.white),
              label: 'Analysis',
            ),
            BottomNavigationBarItem(
              icon: Icon(HugeIcons.strokeRoundedNews01, color: AppColors.gray),
              activeIcon: Icon(HugeIcons.strokeRoundedNews01, color: AppColors.white),
              label: 'News',
            ),
            BottomNavigationBarItem(
              icon: Icon(HugeIcons.strokeRoundedComment02, color: AppColors.gray),
              activeIcon: Icon(HugeIcons.strokeRoundedComment02, color: AppColors.white),
              label: 'Ai Chat',
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/constants/app_colors.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: AppBar(
        backgroundColor: AppColors.black,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(HugeIcons.strokeRoundedArrowLeft01),
          color: AppColors.white,
        ),
        title: Text(
          'Notifications',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: AppColors.white,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
      ),
      body: const Center(
        child: Text(
          'No notifications yet',
          style: TextStyle(color: AppColors.white),
        ),
      ),
    );
  }
}

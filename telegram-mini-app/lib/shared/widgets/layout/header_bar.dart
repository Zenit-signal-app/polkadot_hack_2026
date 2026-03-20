import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/store/user_store.dart';
import '../../../routes/app_routes.dart';

class HeaderBar extends StatefulWidget {
  const HeaderBar({
    super.key,
    required this.title,
    required this.onMenuTap,
  });

  final String title;
  final VoidCallback onMenuTap;

  @override
  State<HeaderBar> createState() => _HeaderBarState();
}

class _HeaderBarState extends State<HeaderBar> {
  void _openSearch() {
    Navigator.of(context).pushNamed(AppRoutes.search);
  }

  @override
  Widget build(BuildContext context) {
    final userState = context.watch<UserStore>().state;
    final isLoggedIn = userState.isLoggedIn;
    final photoURL = userState.photoURL;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Row(
        children: [
          // Show avatar if logged in, otherwise show menu icon
          isLoggedIn
              ? GestureDetector(
                  onTap: widget.onMenuTap,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.blue.withOpacity(0.3),
                        width: 2,
                      ),
                    ),
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor: AppColors.darkBlue,
                      backgroundImage: photoURL != null && photoURL.isNotEmpty
                          ? NetworkImage(photoURL)
                          : null,
                      child: photoURL == null || photoURL.isEmpty
                          ? Text(
                              userState.displayName?.isNotEmpty == true
                                  ? userState.displayName![0].toUpperCase()
                                  : userState.email?.isNotEmpty == true
                                      ? userState.email![0].toUpperCase()
                                      : 'U',
                              style: const TextStyle(
                                color: AppColors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            )
                          : null,
                    ),
                  ),
                )
              : IconButton(
                  onPressed: widget.onMenuTap,
                  icon: const Icon(HugeIcons.strokeRoundedMenu02),
                  color: AppColors.white,
                  padding: EdgeInsets.zero,
                ),
          const SizedBox(width: 6),
          Text(
            widget.title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: AppColors.white,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: _openSearch,
            icon: const Icon(HugeIcons.strokeRoundedSearch01),
            color: AppColors.white,
            padding: EdgeInsets.zero,
          ),
          const SizedBox(width: 10),
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                onPressed: () => Navigator.of(context).pushNamed(AppRoutes.notifications),
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

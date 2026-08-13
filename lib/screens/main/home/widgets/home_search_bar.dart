import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:s_map/commons/styles/styles.dart';
import 'package:s_map/commons/utils/app_colors.dart';
import 'package:s_map/commons/widgets/user_avatar.dart';
import 'package:s_map/screens/search/search_screen.dart';

class HomeSearchBar extends StatelessWidget {
  const HomeSearchBar({super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push(SearchScreen.path),
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(30),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(
              Icons.search_rounded,
              color: AppColors.googleDarkText,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                "Tìm kiếm ở đây",
                style: AppColors.onSurfaceVariant.textTheme.textStyle.copyWith(
                  fontSize: 15,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(
                Icons.mic_none_rounded,
                color: AppColors.googleDarkText,
                size: 22,
              ),
              onPressed: () {},
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 12),
            const ProfileAvatar(size: 32, borderWidth: 1.5),
          ],
        ),
      ),
    );
  }
}

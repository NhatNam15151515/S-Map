import 'package:s_map/commons/cubits/auth_cubit/user_controller.dart';
import 'package:s_map/commons/mixin/app_bar_mixin.dart';
import 'package:s_map/commons/mixin/app_mixin.dart';
import 'package:s_map/commons/mixin/auth_mixin.dart';
import 'package:s_map/commons/styles/styles.dart';
import 'package:s_map/commons/utils/app_colors.dart';
import 'package:s_map/commons/widgets/app_bar.dart';
import 'package:s_map/commons/widgets/user_avatar.dart';
import 'package:flutter/material.dart';

class MainAppBar extends StatelessWidget with AppMixin, AppBarMixin, AuthMixin {
  const MainAppBar({super.key});

  @override
  Widget build(BuildContext context) {
    return AppBarContainer(
      height: appBarHeight,
      child: _searchBar(),
    );
  }

  @override
  double get appBarDesignHeight => 72;

  Widget _searchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: authCubit.profileController.buildDependWidget(
        child: (value) => Container(
          decoration: styles.searchContainer,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              const Icon(
                Icons.search_rounded,
                size: 24,
                color: AppColors.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  "Tìm kiếm trên S-Map",
                  style:
                      AppColors.onSurfaceVariant.textTheme.textStyle.copyWith(
                    fontSize: 15,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const SizedBox(
                width: 32,
                height: 32,
                child: ProfileAvatar(
                  size: 32,
                  borderWidth: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

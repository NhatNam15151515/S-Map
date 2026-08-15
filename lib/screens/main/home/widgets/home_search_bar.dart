import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:s_map/commons/styles/styles.dart';
import 'package:s_map/commons/utils/app_colors.dart';
import 'package:s_map/commons/widgets/user_avatar.dart';
import 'package:s_map/screens/search/search_screen.dart';

class HomeSearchBar extends StatelessWidget {
  final bool showBackButton;
  final VoidCallback? onBackPressed;

  const HomeSearchBar({
    super.key,
    this.showBackButton = false,
    this.onBackPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Thanh tìm kiếm địa điểm',
      button: true,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: AppColors.outlineVariant.withAlpha(80),
            width: 0.5,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color.fromRGBO(0, 0, 0, 0.08),
              blurRadius: 16,
              offset: Offset(0, 4),
            ),
            BoxShadow(
              color: Color.fromRGBO(0, 0, 0, 0.03),
              blurRadius: 4,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(28),
          child: InkWell(
            borderRadius: BorderRadius.circular(28),
            onTap: () => context.push(SearchScreen.path),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  if (showBackButton)
                    IconButton(
                      icon: const Icon(
                        Icons.arrow_back_rounded,
                        color: AppColors.googleDarkText,
                        size: 22,
                      ),
                      onPressed: onBackPressed ?? () => context.pop(),
                      tooltip: 'Quay lại',
                    )
                  else
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Icon(
                        Icons.search_rounded,
                        color: AppColors.googleDarkText,
                        size: 22,
                      ),
                    ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      "Tìm kiếm ở đây",
                      style: AppColors.onSurfaceVariant.textTheme.textStyle.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.mic_none_rounded,
                      color: AppColors.googleDarkText,
                      size: 22,
                    ),
                    onPressed: () {},
                    tooltip: 'Tìm kiếm bằng giọng nói',
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 4),
                  const Padding(
                    padding: EdgeInsets.only(right: 6),
                    child: ProfileAvatar(size: 32, borderWidth: 1.5),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

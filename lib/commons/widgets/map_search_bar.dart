import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:s_map/commons/styles/styles.dart';
import 'package:s_map/commons/utils/utils.dart';
import 'package:s_map/commons/widgets/widgets.dart';
import 'package:s_map/generated/locale_keys.g.dart';
import 'package:s_map/models/models.dart';

class MapSearchBar extends StatelessWidget {
  final bool showBackButton;
  final VoidCallback? onBackPressed;
  final ValueChanged<PoiModel>? onPoiSelected;
  final VoidCallback? onTap;
  final String? activeSearchText;
  final VoidCallback? onClearSearch;

  const MapSearchBar({
    super.key,
    this.showBackButton = false,
    this.onBackPressed,
    this.onPoiSelected,
    this.onTap,
    this.activeSearchText,
    this.onClearSearch,
  });

  bool get _hasActiveSearch =>
      activeSearchText != null && activeSearchText!.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: tr(LocaleKeys.search_bar_title),
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
            onTap: onTap,
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
                      tooltip: tr(LocaleKeys.common_back),
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
                      _hasActiveSearch
                          ? activeSearchText!
                          : tr(LocaleKeys.search_bar_placeholder),
                      style: _hasActiveSearch
                          ? AppColors.googleDarkText.textTheme.textStyle
                              .copyWith(
                              fontSize: 15,
                              fontWeight: AppFontWeight.medium.weight,
                            )
                          : AppColors.onSurfaceVariant.textTheme.textStyle
                              .copyWith(
                              fontSize: 15,
                              fontWeight: AppFontWeight.regular.weight,
                            ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (_hasActiveSearch)
                    IconButton(
                      icon: const Icon(
                        Icons.close_rounded,
                        color: AppColors.googleDarkText,
                        size: 20,
                      ),
                      onPressed: onClearSearch,
                      tooltip: tr(LocaleKeys.cancel),
                      padding: const EdgeInsets.all(8),
                      constraints: const BoxConstraints(),
                    )
                  else
                    IconButton(
                      icon: const Icon(
                        Icons.mic_none_rounded,
                        color: AppColors.googleDarkText,
                        size: 22,
                      ),
                      onPressed: () {},
                      tooltip: tr(LocaleKeys.search_bar_voice),
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

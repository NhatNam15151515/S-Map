import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:s_map/commons/styles/styles.dart';
import 'package:s_map/commons/utils/utils.dart';
import 'package:s_map/generated/locale_keys.g.dart';

class SearchThisAreaButton extends StatelessWidget {
  final bool isVisible;
  final bool isLoading;
  final VoidCallback onPressed;

  const SearchThisAreaButton({
    super.key,
    required this.isVisible,
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final style = AppStyle.of(context);

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      opacity: isVisible ? 1.0 : 0.0,
      child: IgnorePointer(
        ignoring: !isVisible,
        child: AnimatedScale(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutBack,
          scale: isVisible ? 1.0 : 0.8,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: isLoading ? null : onPressed,
              borderRadius: BorderRadius.circular(24),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: AppColors.outlineVariant.withAlpha(100),
                    width: 0.8,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color.fromRGBO(0, 0, 0, 0.12),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isLoading)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.sMapTeal,
                        ),
                      )
                    else
                      const Icon(
                        Icons.refresh_rounded,
                        size: 18,
                        color: AppColors.sMapTeal,
                      ),
                    const SizedBox(width: 8),
                    Text(
                      isLoading
                          ? tr(LocaleKeys.searching_this_area)
                          : tr(LocaleKeys.search_this_area),
                      style: style.blackTextColor.textTheme.boldStyle.copyWith(
                        fontSize: 13,
                        color: AppColors.sMapDarkTeal,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

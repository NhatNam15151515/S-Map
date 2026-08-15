import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:s_map/commons/styles/styles.dart';
import 'package:s_map/commons/utils/utils.dart';
import 'package:s_map/generated/locale_keys.g.dart';

class SearchInputField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback onClear;
  final VoidCallback onBackPressed;
  final VoidCallback? onVoicePressed;

  const SearchInputField({
    super.key,
    required this.controller,
    this.focusNode,
    required this.onQueryChanged,
    this.onSubmitted,
    required this.onClear,
    required this.onBackPressed,
    this.onVoicePressed,
  });

  @override
  Widget build(BuildContext context) {
    final style = AppStyle.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      height: 52,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: AppColors.outlineVariant.withAlpha(120),
          width: 0.8,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.06),
            blurRadius: 12,
            offset: Offset(0, 3),
          ),
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.02),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: AppColors.googleDarkText,
              size: 22,
            ),
            onPressed: onBackPressed,
            tooltip: tr(LocaleKeys.common_back),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onChanged: onQueryChanged,
              onSubmitted: onSubmitted,
              style: style.blackTextColor.textTheme.textStyle.copyWith(
                fontSize: 15,
                fontWeight: AppFontWeight.regular.weight,
              ),
              decoration: InputDecoration(
                hintText: tr(LocaleKeys.search_input_hint),
                hintStyle: AppColors.onSurfaceVariant.textTheme.textStyle.copyWith(
                  fontSize: 15,
                  fontWeight: AppFontWeight.regular.weight,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          if (controller.text.isNotEmpty)
            IconButton(
              icon: const Icon(
                Icons.close_rounded,
                color: AppColors.onSurfaceVariant,
                size: 20,
              ),
              onPressed: onClear,
              tooltip: tr(LocaleKeys.clear_search),
            )
          else ...[
            IconButton(
              icon: const Icon(
                Icons.mic_none_rounded,
                color: AppColors.googleDarkText,
                size: 22,
              ),
              onPressed: onVoicePressed ?? () {},
              tooltip: tr(LocaleKeys.search_bar_voice),
            ),
          ],
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:s_map/commons/styles/styles.dart';
import 'package:s_map/commons/utils/utils.dart';
import 'package:s_map/constants/constants.dart';
import 'package:s_map/generated/locale_keys.g.dart';

class GoogleSignInButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback? onPressed;

  const GoogleSignInButton({
    super.key,
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton(
        onPressed: isLoading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: AppColors.white,
          side: BorderSide(
            color: AppColors.outlineVariant.withAlpha(180),
            width: 1,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
          ),
          elevation: 0.5,
          shadowColor: Colors.black.withAlpha(15),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AppAsset.google.image.build(
              size: const Size(20, 20),
            ),
            const SizedBox(width: 12),
            Text(
              tr(LocaleKeys.loginWithGoogle),
              style: AppColors.googleDarkText.textTheme.boldStyle.copyWith(
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

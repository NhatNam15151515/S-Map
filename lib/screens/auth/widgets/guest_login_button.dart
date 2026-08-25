import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:s_map/commons/styles/styles.dart';
import 'package:s_map/commons/utils/utils.dart';
import 'package:s_map/generated/locale_keys.g.dart';

class GuestLoginButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback? onPressed;

  const GuestLoginButton({
    super.key,
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton(
        onPressed: isLoading ? null : onPressed,
        child: Text(
          tr(LocaleKeys.continueAsGuest),
          style: AppColors.sMapTeal.textTheme.boldStyle.copyWith(
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

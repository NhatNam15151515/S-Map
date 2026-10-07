import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:s_map/commons/widgets/widgets.dart';
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
    return AppButton.outlined(
      text: tr(LocaleKeys.loginWithGoogle),
      icon: AppAsset.google.image.build(
        size: const Size(20, 20),
      ),
      isLoading: isLoading,
      onPressed: onPressed,
      elevation: 0.5,
    );
  }
}

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:s_map/commons/widgets/widgets.dart';
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
      child: AppButton.text(
        text: tr(LocaleKeys.continueAsGuest),
        isLoading: isLoading,
        onPressed: onPressed,
      ),
    );
  }
}

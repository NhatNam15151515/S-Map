import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:s_map/commons/styles/styles.dart';
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
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton(
        onPressed: isLoading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: colorScheme.surface,
          side: BorderSide(
            color: colorScheme.outline.withAlpha(80),
            width: 1,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
          ),
          elevation: 0.5,
          shadowColor: colorScheme.shadow.withValues(alpha: 0.08),
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
              style: colorScheme.onSurface.textTheme.boldStyle.copyWith(
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

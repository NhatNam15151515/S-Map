import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:s_map/commons/styles/styles.dart';
import 'package:s_map/commons/validators/validators.dart';
import 'package:s_map/commons/widgets/widgets.dart';
import 'package:s_map/generated/locale_keys.g.dart';

class LoginFormWidget extends StatelessWidget {
  final CustomTextEditingController usernameController;
  final CustomTextEditingController passwordController;
  final bool isLoading;
  final VoidCallback onLogin;

  const LoginFormWidget({
    super.key,
    required this.usernameController,
    required this.passwordController,
    required this.isLoading,
    required this.onLogin,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Username / Email input
        AppTextField(
          title: tr(LocaleKeys.account),
          controller: usernameController,
          hint: tr(LocaleKeys.usernameOrEmailHint),
          validator: (value) => Validator.instance.isEmpty(value)
              ? tr(LocaleKeys.usernameValidation)
              : null,
        ),
        const SizedBox(height: 14),

        // Password input
        AppTextField(
          title: tr(LocaleKeys.password),
          controller: passwordController,
          hint: tr(LocaleKeys.passwordHint),
          validator: (value) => Validator.instance.isEmpty(value)
              ? tr(LocaleKeys.passwordValidation)
              : null,
          obscure: true,
        ),
        const SizedBox(height: 24),

        // Primary Login button
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: isLoading
                ? null
                : () {
                    final res = usernameController.validate() == true &&
                        passwordController.validate() == true;
                    if (res) onLogin();
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
              elevation: 0,
            ),
            child: isLoading
                ? SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(colorScheme.onPrimary),
                    ),
                  )
                : Text(
                    tr(LocaleKeys.login),
                    style: colorScheme.onPrimary.textTheme.subTitleStyle.copyWith(
                      fontSize: 16,
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:s_map/commons/mixin/mixin.dart';
import 'package:s_map/commons/utils/utils.dart';
import 'package:s_map/commons/widgets/widgets.dart';
import 'package:s_map/screens/auth/widgets/widgets.dart';

class LoginScreen extends StatefulWidget {
  static const String path = '/LoginScreen';
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with AppMixin {
  late CustomTextEditingController usernameController;
  late CustomTextEditingController passwordController;
  bool isLoading = false;

  @override
  void initState() {
    usernameController = CustomTextEditingController(text: "");
    passwordController = CustomTextEditingController(text: "");
    super.initState();
  }

  @override
  void dispose() {
    usernameController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  void _handleGoogleSignIn() async {
    setState(() => isLoading = true);
    try {
      final success = await authCubit.signInWithGoogle();
      if (!success && mounted) {
        showError(tr(LocaleKeys.login_google_failed));
      }
    } catch (e) {
      if (mounted) {
        showError(tr(LocaleKeys.login_google_error, args: [e.toString()]));
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _handleLogin() async {
    setState(() => isLoading = true);
    try {
      await authCubit.loginWithCredentials(
        username: usernameController.text.isNotEmpty
            ? usernameController.text
            : tr(
                LocaleKeys.default_user_name,
                args: [appName],
              ),
        password: passwordController.text,
      );
    } catch (e) {
      if (mounted) {
        showError(tr(LocaleKeys.login_failed, args: [e.toString()]));
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _handleGuestLogin() async {
    setState(() => isLoading = true);
    try {
      await authCubit.loginGuest(username: tr(LocaleKeys.guest));
    } catch (e) {
      if (mounted) {
        showError(tr(LocaleKeys.login_failed, args: [e.toString()]));
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              LoginHeaderWidget(appName: appName),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  children: [
                    LoginFormWidget(
                      usernameController: usernameController,
                      passwordController: passwordController,
                      isLoading: isLoading,
                      onLogin: _handleLogin,
                    ),
                    const SizedBox(height: 28),
                    const LoginDividerWidget(),
                    const SizedBox(height: 24),
                    GoogleSignInButton(
                      isLoading: isLoading,
                      onPressed: _handleGoogleSignIn,
                    ),
                    const SizedBox(height: 28),
                    GuestLoginButton(
                      isLoading: isLoading,
                      onPressed: _handleGuestLogin,
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:s_map/commons/cubits/cubits.dart';
import 'package:s_map/commons/mixin/mixin.dart';
import 'package:s_map/commons/widgets/widgets.dart';
import 'package:s_map/screens/auth/widgets/widgets.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with AppMixin {
  late CustomTextEditingController usernameController;
  late CustomTextEditingController passwordController;

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

  void _handleGoogleSignIn() {
    authCubit.signInWithGoogle();
  }

  void _handleLogin() {
    authCubit.loginWithCredentials(
      username: usernameController.text.isNotEmpty
          ? usernameController.text
          : tr(
              LocaleKeys.default_user_name,
              args: [appName],
            ),
      password: passwordController.text,
    );
  }

  void _handleGuestLogin() {
    authCubit.loginGuest(username: tr(LocaleKeys.guest));
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthCubit, AuthState>(
      listener: (context, state) {
        if (state.errorMessage != null) {
          showError(state.errorMessage!);
        }
      },
      builder: (context, state) {
        final isLoading = state.isLoading;

        return Scaffold(
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
      },
    );
  }
}

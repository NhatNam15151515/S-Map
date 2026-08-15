import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:s_map/commons/mixin/mixin.dart';
import 'package:s_map/commons/styles/styles.dart';
import 'package:s_map/commons/utils/utils.dart';
import 'package:s_map/commons/validators/validators.dart';
import 'package:s_map/commons/widgets/widgets.dart';
import 'package:s_map/constants/constants.dart';
import 'package:s_map/models/models.dart';

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
    setState(() {
      isLoading = true;
    });

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
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  void _handleLogin({String? username}) async {
    setState(() {
      isLoading = true;
    });

    try {
      final user = User(
        username: username ??
            (usernameController.text.isNotEmpty
                ? usernameController.text
                : "Người dùng S-Map"),
      );

      // Lưu trạng thái đăng nhập và vào màn hình chính
      authCubit.onLoggedIn(user);
    } catch (e) {
      showError("Đăng nhập thất bại: $e");
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
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
              // Header with gradient & App Logo
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 36),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.sMapTealSurface,
                      AppColors.white,
                    ],
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.sMapLightTeal,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.sMapTeal.withAlpha(30),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: AppAsset.logo.image.build(
                        size: const Size(56, 56),
                        color: AppColors.sMapTeal,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "S-Map",
                      style: AppColors.sMapDarkTeal.textTheme.headlineStyle
                          .copyWith(
                        letterSpacing: 1,
                        fontSize: 28,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "Khám phá và lưu trữ địa điểm của bạn",
                      style: AppColors.onSurfaceVariant.textTheme.textStyle
                          .copyWith(
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),

              // Form Section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
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
                                final res =
                                    usernameController.validate() == true &&
                                        passwordController.validate() == true;
                                if (res) _handleLogin();
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.sMapTeal,
                          foregroundColor: AppColors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                          elevation: 0,
                        ),
                        child: isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                ),
                              )
                            : Text(
                                tr(LocaleKeys.login),
                                style: AppColors.white.textTheme.subTitleStyle
                                    .copyWith(
                                  fontSize: 16,
                                ),
                              ),
                      ),
                    ),

                    const SizedBox(height: 28),

                    // Divider with "hoặc"
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 1,
                            color: AppColors.outlineVariant.withAlpha(150),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            tr(LocaleKeys.or),
                            style: AppColors
                                .onSurfaceVariant.textTheme.captionStyle
                                .copyWith(
                              fontSize: 13,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Container(
                            height: 1,
                            color: AppColors.outlineVariant.withAlpha(150),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Google Sign-In Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: OutlinedButton(
                        onPressed: isLoading ? null : _handleGoogleSignIn,
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
                            const _GoogleLogoWidget(size: 20),
                            const SizedBox(width: 12),
                            Text(
                              tr(LocaleKeys.loginWithGoogle),
                              style: styles.blackTextColor.textTheme.boldStyle
                                  .copyWith(
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 28),

                    // Guest / Skip login button (Trải nghiệm ngay)
                    Center(
                      child: TextButton(
                        onPressed: () {
                          _handleLogin(username: tr(LocaleKeys.guest));
                        },
                        child: Text(
                          tr(LocaleKeys.continueAsGuest),
                          style:
                              AppColors.sMapTeal.textTheme.boldStyle.copyWith(
                            fontSize: 14,
                          ),
                        ),
                      ),
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

/// Official Google 4-Color Logo Widget
class _GoogleLogoWidget extends StatelessWidget {
  final double size;
  const _GoogleLogoWidget({this.size = 24});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _GoogleLogoPainter(),
      ),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final center = Offset(w / 2, h / 2);
    final radius = w / 2;

    final strokeWidth = w * 0.22;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    final rect =
        Rect.fromCircle(center: center, radius: radius - strokeWidth / 2);

    // Blue arc (bottom right to top right)
    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(rect, -0.7, 1.4, false, paint);

    // Green arc (bottom right to bottom left)
    paint.color = const Color(0xFF34A853);
    canvas.drawArc(rect, 0.7, 1.3, false, paint);

    // Yellow arc (bottom left to top left)
    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(rect, 2.0, 1.4, false, paint);

    // Red arc (top left to top right)
    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(rect, 3.4, 1.2, false, paint);

    // Blue horizontal bar
    final barPaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.fill;

    final barHeight = strokeWidth;
    final barWidth = radius + strokeWidth / 2;
    canvas.drawRect(
      Rect.fromLTWH(
        center.dx,
        center.dy - barHeight / 2,
        barWidth - strokeWidth * 0.4,
        barHeight,
      ),
      barPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

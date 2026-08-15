import 'package:flutter/material.dart';
import 'package:s_map/commons/styles/styles.dart';
import 'package:s_map/commons/utils/app_colors.dart';
import 'package:s_map/constants/constants.dart';
import 'package:shimmer/shimmer.dart';

import '../../commons/mixin/app_mixin.dart';

class InitialScreen extends StatefulWidget {
  static const String path = '/';

  const InitialScreen({super.key});

  @override
  State<InitialScreen> createState() => _InitialScreenState();
}

class _InitialScreenState extends State<InitialScreen>
    with AppMixin, SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
    _animController.forward();
    appCubit.initMetaData();
    super.initState();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.sMapTealGradientStart,
              AppColors.sMapTeal,
              AppColors.sMapDarkTeal,
            ],
          ),
        ),
        child: Center(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Logo
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.white.withAlpha(30),
                    shape: BoxShape.circle,
                  ),
                  child: AppAsset.logo.image.build(
                    size: const Size(64, 64),
                    color: AppColors.white,
                  ),
                ),
                const SizedBox(height: 24),
                // App name
                Shimmer.fromColors(
                  baseColor: AppColors.white,
                  highlightColor: AppColors.white.withAlpha(128),
                  child: Text(
                    "S-Map",
                    style: AppColors.white.textTheme.displayStyle.copyWith(
                      letterSpacing: 2,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Khám phá thế giới xung quanh",
                  style: AppColors.white
                      .withAlpha(200)
                      .textTheme
                      .textStyle
                      .copyWith(
                        fontSize: 14,
                        letterSpacing: 0.5,
                      ),
                ),
                const SizedBox(height: 48),
                SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.white.withAlpha(180),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

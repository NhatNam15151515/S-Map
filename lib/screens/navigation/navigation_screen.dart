import 'package:flutter/material.dart';
import 'package:s_map/commons/styles/styles.dart';
import 'package:s_map/commons/utils/app_colors.dart';

class NavigationScreen extends StatefulWidget {
  static const String path = '/navigation';

  const NavigationScreen({super.key});

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceDim,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: AppColors.sMapLightTeal,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.navigation_rounded,
                size: 56,
                color: AppColors.sMapTeal,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              "Dẫn đường",
              style: AppColors.googleDarkText.textTheme.subTitleStyle.copyWith(
                fontSize: 20,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Tính năng đang được phát triển",
              style: AppColors.onSurfaceVariant.textTheme.textStyle.copyWith(
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

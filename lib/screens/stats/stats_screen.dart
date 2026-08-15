import 'package:flutter/material.dart';
import 'package:s_map/commons/styles/styles.dart';
import 'package:s_map/commons/utils/utils.dart';

class StatsScreen extends StatefulWidget {
  static const String path = '/stats';

  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
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
                Icons.bar_chart_rounded,
                size: 56,
                color: AppColors.sMapTeal,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              "Thống kê",
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

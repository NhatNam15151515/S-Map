import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:s_map/commons/utils/utils.dart';
import 'package:s_map/commons/widgets/widgets.dart';
import 'package:s_map/generated/locale_keys.g.dart';

class RouteDrawingScreen extends StatelessWidget {
  static const String path = '/route_drawing';

  const RouteDrawingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceDim,
      body: FeaturePlaceholderWidget(
        icon: Icons.route_rounded,
        title: tr(LocaleKeys.route_drawing),
      ),
    );
  }
}

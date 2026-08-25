import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:s_map/commons/utils/utils.dart';
import 'package:s_map/commons/widgets/widgets.dart';
import 'package:s_map/generated/locale_keys.g.dart';
import 'package:s_map/routers/app_routes.dart';
import 'widgets/widgets.dart';

class SavedScreen extends StatefulWidget {
  const SavedScreen({super.key});

  @override
  State<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends State<SavedScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: TitleAppBar(
        title: tr(LocaleKeys.savedPlaces),
        rightWidget: IconButton(
          icon: const Icon(
            Icons.gesture_rounded,
            color: AppColors.sMapTeal,
          ),
          tooltip: tr(LocaleKeys.route_drawing_ui_title),
          onPressed: () => context.push(AppRoutes.routeDrawing),
        ),
      ),
      body: const SavedScreenContent(),
    );
  }
}

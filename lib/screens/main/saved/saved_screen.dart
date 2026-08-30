import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:s_map/commons/styles/styles.dart';
import 'package:s_map/generated/locale_keys.g.dart';
import 'package:s_map/routers/app_routes.dart';
import 'widgets/widgets.dart';

class SavedScreen extends StatelessWidget {
  const SavedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            tr(LocaleKeys.savedPlaces),
            style: colorScheme.onSurface.textTheme.boldStyle.copyWith(fontSize: 20),
          ),
          centerTitle: false,
          elevation: 0,
          backgroundColor: colorScheme.surface,
          actions: [
            IconButton(
              icon: Icon(
                Icons.gesture_rounded,
                color: colorScheme.primary,
              ),
              tooltip: tr(LocaleKeys.route_drawing_ui_title),
              onPressed: () => context.push(AppRoutes.routeDrawing),
            ),
            const SizedBox(width: 8),
          ],
          bottom: TabBar(
            labelColor: colorScheme.primary,
            unselectedLabelColor: colorScheme.onSurfaceVariant,
            indicatorColor: colorScheme.primary,
            indicatorWeight: 3,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 14),
            tabs: [
              Tab(
                icon: const Icon(Icons.bookmark_rounded, size: 20),
                text: tr(LocaleKeys.savedPlaces),
              ),
              Tab(
                icon: const Icon(Icons.alt_route_rounded, size: 20),
                text: tr(LocaleKeys.route_drawing_ui_saved_routes_title),
              ),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            SavedScreenContent(),
            SavedRoutesTabContent(),
          ],
        ),
      ),
    );
  }
}

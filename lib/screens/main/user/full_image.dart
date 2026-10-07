import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:s_map/commons/styles/styles.dart';
import 'package:s_map/commons/utils/utils.dart';
import 'package:s_map/routers/routers.dart';

class FullImageScreen extends StatelessWidget {
  final AppImage args;

  const FullImageScreen({super.key, required this.args});

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Stack(
        children: [
          Container(
            alignment: Alignment.center,
            color: colorScheme.surface,
            child: args.build(),
          ),
          // Top gradient overlay
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 120,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    colorScheme.shadow.withValues(alpha: 0.4),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // Back button
          Positioned(
            left: 16,
            top: MediaQuery.paddingOf(context).top + 8,
            child: Container(
              decoration: BoxDecoration(
                color: colorScheme.surface.withValues(alpha: 0.8),
                shape: BoxShape.circle,
                border: Border.all(
                  color: colorScheme.outline.withValues(alpha: 0.2),
                  width: 0.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.shadow.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: IconButton(
                onPressed: () {
                  context.pop();
                },
                icon: Icon(
                  Icons.arrow_back_rounded,
                  color: colorScheme.onSurface,
                  size: 24,
                ),
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(
                  minWidth: 40,
                  minHeight: 40,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

extension AppImageToFullScreen on AppImage {
  Widget buildWithFullScreen(
    BuildContext context, {
    Widget? placeHolder,
    Widget? error,
    Size? size,
    BoxFit fit = BoxFit.contain,
    Color? color,
    Alignment? alignment,
    double? memCacheWidth,
    double? memCacheHeight,
    String? cacheKey,
  }) {
    return GestureDetector(
      onTap: () {
        context.push(AppRoutes.fullImage, extra: this);
      },
      child: build(
        placeHolder: placeHolder,
        error: error,
        size: size,
        fit: fit,
        color: color,
        alignment: alignment,
        memCacheWidth: memCacheWidth,
        memCacheHeight: memCacheHeight,
        cacheKey: cacheKey,
      ),
    );
  }
}

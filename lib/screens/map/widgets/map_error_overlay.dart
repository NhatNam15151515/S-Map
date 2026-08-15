import 'package:s_map/commons/mixin/app_mixin.dart';
import 'package:s_map/commons/utils/app_colors.dart';
import 'package:s_map/commons/widgets/widgets.dart';
import 'package:flutter/material.dart';

class MapErrorOverlay extends StatelessWidget with AppMixin {
  final String errorMessage;
  final VoidCallback onRetry;

  const MapErrorOverlay({
    super.key,
    required this.errorMessage,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: AppColors.white,
        child: EmptyWidget(
          title: errorMessage,
          onRefresh: onRetry,
        ),
      ),
    );
  }
}

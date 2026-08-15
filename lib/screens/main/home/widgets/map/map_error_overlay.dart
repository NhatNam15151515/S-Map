import 'package:flutter/material.dart';
import 'package:s_map/commons/mixin/mixin.dart';
import 'package:s_map/commons/utils/utils.dart';
import 'package:s_map/commons/widgets/widgets.dart';

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

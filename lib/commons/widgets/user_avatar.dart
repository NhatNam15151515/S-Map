import 'package:s_map/commons/mixin/app_mixin.dart';
import 'package:s_map/commons/utils/app_colors.dart';
import 'package:flutter/material.dart';

class ProfileAvatar extends StatelessWidget with AppMixin {
  final double? size;
  final double borderWidth;
  const ProfileAvatar({super.key, this.size, this.borderWidth = 1.5});

  @override
  Widget build(BuildContext context) {
    final effectiveSize = size ?? 36.0;
    return Container(
      width: effectiveSize,
      height: effectiveSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.sMapTeal,
          width: borderWidth,
        ),
        color: AppColors.sMapLightTeal,
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.person_rounded,
        size: effectiveSize * 0.6,
        color: AppColors.sMapTeal,
      ),
    );
  }
}

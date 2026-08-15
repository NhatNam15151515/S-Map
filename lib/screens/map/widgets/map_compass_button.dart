import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:s_map/commons/cubits/cubits.dart';
import 'package:s_map/commons/utils/app_colors.dart';

class MapCompassButton extends StatelessWidget {
  final double rotation;
  final MapOrientationMode orientationMode;
  final VoidCallback onTap;

  const MapCompassButton({
    super.key,
    required this.rotation,
    required this.orientationMode,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isHeadingUp = orientationMode == MapOrientationMode.headingUp;

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.white,
        shape: BoxShape.circle,
        border: isHeadingUp
            ? Border.all(color: AppColors.googleBlue, width: 2)
            : null,
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.12),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Center(
            child: Transform.rotate(
              angle: -(rotation * math.pi / 180),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    Icons.navigation_rounded,
                    size: 22,
                    color: isHeadingUp
                        ? AppColors.googleBlue
                        : AppColors.googleRed,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

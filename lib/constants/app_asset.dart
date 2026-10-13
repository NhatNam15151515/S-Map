import 'package:flutter/material.dart';
import 'package:s_map/commons/utils/app_image.dart';

enum AppAsset {
  avatar("avatar.png"),
  logo("white-s-map-logo-removed-background.png"),
  logoLight("white-s-map-logo-removed-background.png"),
  logoDark("black-s-map-logo-removed-background.png"),
  google("google_ic.svg"),
  redMarker("red_marker.png"),
  ;

  const AppAsset(this.source);

  final String source;

  AppImage get image => AppImage(fullPath);
  static const String assetImagesPath = "assets/images";

  String get fullPath => "$assetImagesPath/$source";

  /// Lấy logo phù hợp theo theme giao diện sáng / tối
  static AppAsset logoOf(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? AppAsset.logoDark : AppAsset.logoLight;
  }
}

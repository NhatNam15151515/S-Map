import 'package:s_map/commons/utils/utils.dart';

enum AppAsset {
  avatar("avatar.png"),
  logo("logo.png"),
  google("google_ic.svg"),
  redMarker("red_marker.png"),
  ;

  const AppAsset(this.source);

  final String source;

  AppImage get image => AppImage(fullPath);
  static const String assetImagesPath = "assets/images";

  String get fullPath => "$assetImagesPath/$source";
}

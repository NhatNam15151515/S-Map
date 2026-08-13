import 'package:s_map/commons/utils/app_image.dart';

enum AppAsset {
  avatar("avatar.png"),
  logo("logo.png"),
  ;

  const AppAsset(this.source);

  final String source;

  AppImage get image => AppImage(fullPath);
  static const String assetImagesPath = "assets/images";

  String get fullPath => "$assetImagesPath/$source";
}

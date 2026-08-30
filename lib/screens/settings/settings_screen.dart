import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:s_map/commons/cubits/cubits.dart';
import 'package:s_map/commons/mixin/mixin.dart';
import 'package:s_map/commons/styles/styles.dart';
import 'package:s_map/commons/widgets/widgets.dart';
import 'package:s_map/localizations/app_localization.dart';
import 'package:s_map/routers/app_routes.dart';
import 'package:s_map/screens/settings/widgets/widgets.dart';

class SettingsScreen extends StatelessWidget with AppMixin {
  const SettingsScreen({super.key});

  String _getThemeModeSubtitle(ThemeMode mode, bool isDarkMode) {
    switch (mode) {
      case ThemeMode.system:
        return tr(LocaleKeys.themeModeSystem);
      case ThemeMode.dark:
        return tr(LocaleKeys.themeModeDark);
      case ThemeMode.light:
        return tr(LocaleKeys.themeModeLight);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appCubit = context.watch<AppCubit>();
    final isDarkMode = appCubit.state.isDarkMode;
    final themeMode = appCubit.state.themeMode;
    final currentLocale = appCubit.state.supportedLocale;

    return Scaffold(
      appBar: TitleBackAppBar(title: tr(LocaleKeys.settings)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. General Section
            SettingsSectionTitle(title: tr(LocaleKeys.general)),
            SettingsGroupCard(
              children: [
                SettingsItemTile(
                  icon: Icons.download_for_offline_outlined,
                  title: tr(LocaleKeys.offline_maps_title),
                  subtitle: tr(LocaleKeys.offline_maps_subtitle),
                  onTap: () => context.push(AppRoutes.offlineRegions),
                ),
                const SettingsDivider(),
                SettingsItemTile(
                  icon: Icons.dark_mode_rounded,
                  title: tr(LocaleKeys.darkMode),
                  subtitle: _getThemeModeSubtitle(themeMode, isDarkMode),
                  onTap: () => ThemeModeDialog.show(context, themeMode),
                  trailing: Switch(
                    value: isDarkMode,
                    onChanged: (value) {
                      context.read<AppCubit>().toggleDarkMode(value);
                    },
                    activeTrackColor: context.colorScheme.primary,
                  ),
                ),
                const SettingsDivider(),
                SettingsItemTile(
                  icon: Icons.language_rounded,
                  title: tr(LocaleKeys.language),
                  subtitle: currentLocale == SupportedLocale.vi ? 'Tiếng Việt' : 'English',
                  onTap: () => LanguageDialog.show(context, currentLocale),
                ),
                const SettingsDivider(),
                SettingsItemTile(
                  icon: Icons.map_rounded,
                  title: tr(LocaleKeys.mapType),
                  subtitle: tr(LocaleKeys.defaultMap),
                  onTap: () => PolicyDialog.show(
                    context,
                    title: tr(LocaleKeys.mapType),
                    content: 'Bản đồ chuẩn vector độ nét cao tối ưu cho giao thông tại Việt Nam.',
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // 2. About Section
            SettingsSectionTitle(title: tr(LocaleKeys.aboutSection)),
            SettingsGroupCard(
              children: [
                SettingsItemTile(
                  icon: Icons.info_outline_rounded,
                  title: tr(
                    LocaleKeys.aboutSMap,
                    args: [appCubit.state.appName],
                  ),
                  subtitle: tr(LocaleKeys.appVersion),
                  onTap: () => AppAboutDialog.show(
                    context,
                    appName: appCubit.state.appName,
                    appVersion: '1.0.0',
                  ),
                ),
                const SettingsDivider(),
                SettingsItemTile(
                  icon: Icons.privacy_tip_outlined,
                  title: tr(LocaleKeys.privacyPolicy),
                  onTap: () => PolicyDialog.show(
                    context,
                    title: tr(LocaleKeys.privacyPolicy),
                    content: 'S-Map tôn trọng và cam kết bảo vệ quyền riêng tư của bạn. Dữ liệu vị trí chỉ được sử dụng cho mục đích dẫn đường và tìm kiếm địa điểm ngoại tuyến cục bộ trên thiết bị.',
                  ),
                ),
                const SettingsDivider(),
                SettingsItemTile(
                  icon: Icons.description_outlined,
                  title: tr(LocaleKeys.termAndCondition),
                  onTap: () => PolicyDialog.show(
                    context,
                    title: tr(LocaleKeys.termAndCondition),
                    content: 'Khi sử dụng ứng dụng S-Map, bạn đồng ý tuân thủ luật an toàn giao thông đường bộ và các quy định hiện hành.',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

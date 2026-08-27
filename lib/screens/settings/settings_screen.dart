import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:s_map/commons/cubits/cubits.dart';
import 'package:s_map/commons/mixin/mixin.dart';
import 'package:s_map/commons/styles/styles.dart';
import 'package:s_map/commons/utils/utils.dart';
import 'package:s_map/commons/widgets/widgets.dart';
import 'package:s_map/routers/app_routes.dart';
import 'package:s_map/screens/settings/widgets/widgets.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with AppMixin {
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

  void _showThemeModeDialog(BuildContext context, ThemeMode currentMode) {
    final style = AppStyle.of(context);
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: style.colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            tr(LocaleKeys.themeMode),
            style: style.blackTextColor.textTheme.boldStyle.copyWith(
              fontSize: 18,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildThemeOptionTile(
                dialogContext: dialogContext,
                title: tr(LocaleKeys.themeModeSystem),
                value: ThemeMode.system,
                groupValue: currentMode,
                style: style,
              ),
              const SizedBox(height: 4),
              _buildThemeOptionTile(
                dialogContext: dialogContext,
                title: tr(LocaleKeys.themeModeLight),
                value: ThemeMode.light,
                groupValue: currentMode,
                style: style,
              ),
              const SizedBox(height: 4),
              _buildThemeOptionTile(
                dialogContext: dialogContext,
                title: tr(LocaleKeys.themeModeDark),
                value: ThemeMode.dark,
                groupValue: currentMode,
                style: style,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(
                tr(LocaleKeys.common_cancel),
                style: const TextStyle(color: AppColors.sMapTeal),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildThemeOptionTile({
    required BuildContext dialogContext,
    required String title,
    required ThemeMode value,
    required ThemeMode groupValue,
    required AppStyle style,
  }) {
    final isSelected = value == groupValue;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: ValueKey('theme_option_${value.name}'),
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          context.read<AppCubit>().onChangeThemeMode(value);
          Navigator.of(dialogContext).pop();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              Icon(
                isSelected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: isSelected
                    ? AppColors.sMapTeal
                    : (style.greysTextColor.isNotEmpty
                        ? style.greysTextColor.first
                        : AppColors.onSurfaceVariant),
                size: 22,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: style.blackTextColor.textTheme.textStyle.copyWith(
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appCubit = context.watch<AppCubit>();
    final isDarkMode = appCubit.state.isDarkMode;
    final themeMode = appCubit.state.themeMode;

    return Scaffold(
      appBar: TitleBackAppBar(title: tr(LocaleKeys.settings)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // General section
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
                  onTap: () => _showThemeModeDialog(context, themeMode),
                  trailing: Switch(
                    value: isDarkMode,
                    onChanged: (value) {
                      context.read<AppCubit>().toggleDarkMode(value);
                    },
                    activeTrackColor: AppColors.sMapTeal,
                  ),
                ),
                const SettingsDivider(),
                SettingsItemTile(
                  icon: Icons.language_rounded,
                  title: tr(LocaleKeys.language),
                  subtitle: tr(LocaleKeys.vietnamese),
                ),
                const SettingsDivider(),
                SettingsItemTile(
                  icon: Icons.map_rounded,
                  title: tr(LocaleKeys.mapType),
                  subtitle: tr(LocaleKeys.defaultMap),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // About section
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
                ),
                const SettingsDivider(),
                SettingsItemTile(
                  icon: Icons.privacy_tip_outlined,
                  title: tr(LocaleKeys.privacyPolicy),
                ),
                const SettingsDivider(),
                SettingsItemTile(
                  icon: Icons.description_outlined,
                  title: tr(LocaleKeys.termAndCondition),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

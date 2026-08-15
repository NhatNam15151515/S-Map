import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:s_map/commons/mixin/mixin.dart';
import 'package:s_map/commons/utils/utils.dart';
import 'package:s_map/commons/widgets/widgets.dart';
import 'package:s_map/screens/settings/widgets/widgets.dart';
import 'package:s_map/services/services.dart';

class SettingsScreen extends StatefulWidget {
  static const String path = '/settings';

  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with AppMixin {
  @override
  Widget build(BuildContext context) {
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
                  icon: Icons.dark_mode_rounded,
                  title: tr(LocaleKeys.darkMode),
                  trailing: Switch(
                    value: false,
                    onChanged: (value) {},
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
                    args: [PackageInfoService.instance.appName],
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

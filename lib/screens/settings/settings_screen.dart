import 'package:flutter/material.dart';
import 'package:s_map/commons/mixin/app_mixin.dart';
import 'package:s_map/commons/utils/app_colors.dart';
import 'package:s_map/commons/styles/styles.dart';
import 'package:s_map/commons/widgets/app_bar.dart';

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
      appBar: TitleBackAppBar(title: "Cài đặt"),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // General section
            _sectionTitle("Chung"),
            _settingsCard([
              _settingsItem(
                icon: Icons.dark_mode_rounded,
                title: "Chế độ tối",
                trailing: Switch(
                  value: false,
                  onChanged: (value) {},
                  activeTrackColor: AppColors.sMapTeal,
                ),
              ),
              _divider(),
              _settingsItem(
                icon: Icons.language_rounded,
                title: "Ngôn ngữ",
                subtitle: "Tiếng Việt",
              ),
              _divider(),
              _settingsItem(
                icon: Icons.map_rounded,
                title: "Kiểu bản đồ",
                subtitle: "Mặc định",
              ),
            ]),

            const SizedBox(height: 20),

            // About section
            _sectionTitle("Thông tin"),
            _settingsCard([
              _settingsItem(
                icon: Icons.info_outline_rounded,
                title: "Về S-Map",
                subtitle: "Phiên bản 1.0.0",
              ),
              _divider(),
              _settingsItem(
                icon: Icons.privacy_tip_outlined,
                title: "Chính sách quyền riêng tư",
              ),
              _divider(),
              _settingsItem(
                icon: Icons.description_outlined,
                title: "Điều khoản sử dụng",
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: AppColors.onSurfaceVariant.textTheme.overlineStyle.copyWith(
          fontSize: 12,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _settingsCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(children: children),
    );
  }

  Widget _settingsItem({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: trailing == null ? () {} : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.sMapTeal.withAlpha(15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: AppColors.sMapTeal),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: styles.blackTextColor.textTheme.boldStyle
                          .copyWith(fontSize: 15),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style:
                            AppColors.onSurfaceVariant.textTheme.captionStyle,
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null)
                trailing
              else
                const Icon(Icons.chevron_right_rounded,
                    color: AppColors.onSurfaceVariant, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _divider() {
    return Padding(
      padding: const EdgeInsets.only(left: 60),
      child:
          Divider(height: 0.5, color: AppColors.outlineVariant.withAlpha(128)),
    );
  }
}

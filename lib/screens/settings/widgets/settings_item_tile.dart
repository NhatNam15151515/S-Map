import 'package:flutter/material.dart';
import 'package:s_map/commons/styles/styles.dart';
import 'package:s_map/commons/utils/utils.dart';

class SettingsItemTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const SettingsItemTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final style = AppStyle.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.sMapTeal.withAlpha(25),
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
                      style: style.blackTextColor.textTheme.boldStyle
                          .copyWith(fontSize: 15),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: (style.greysTextColor.isNotEmpty
                                ? style.greysTextColor.first
                                : AppColors.onSurfaceVariant)
                            .textTheme
                            .captionStyle,
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null)
                trailing!
              else
                Icon(
                  Icons.chevron_right_rounded,
                  color: style.greysTextColor.isNotEmpty
                      ? style.greysTextColor.first
                      : AppColors.onSurfaceVariant,
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class SettingsGroupCard extends StatelessWidget {
  final List<Widget> children;

  const SettingsGroupCard({
    super.key,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final style = AppStyle.of(context);
    return Container(
      decoration: BoxDecoration(
        color: style.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(children: children),
    );
  }
}

class SettingsDivider extends StatelessWidget {
  const SettingsDivider({super.key});

  @override
  Widget build(BuildContext context) {
    final style = AppStyle.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 60),
      child: Divider(
        height: 0.5,
        color: style.colorScheme.outline.withAlpha(128),
      ),
    );
  }
}

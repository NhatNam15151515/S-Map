import 'package:flutter/material.dart';
import 'package:s_map/commons/styles/styles.dart';

class SettingsItemTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool isDestructive;

  const SettingsItemTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final activeColor =
        isDestructive ? colorScheme.error : colorScheme.primary;
    final textColor =
        isDestructive ? colorScheme.error : colorScheme.onSurface;

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
                  color: activeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: activeColor),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: textColor.textTheme.boldStyle
                          .copyWith(fontSize: 15),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: colorScheme.onSurfaceVariant.textTheme
                            .captionStyle,
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null)
                trailing!
              else if (!isDestructive)
                Icon(
                  Icons.chevron_right_rounded,
                  color: colorScheme.onSurfaceVariant,
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
    final colorScheme = context.colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
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
    final colorScheme = context.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(left: 60),
      child: Divider(
        height: 0.5,
        color: colorScheme.outline.withValues(alpha: 0.25),
      ),
    );
  }
}

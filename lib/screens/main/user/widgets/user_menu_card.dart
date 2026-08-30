import 'package:flutter/material.dart';
import 'package:s_map/commons/styles/styles.dart';

class UserMenuTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool isDestructive;

  const UserMenuTile({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final color =
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
                  color: (isDestructive ? colorScheme.error : colorScheme.primary)
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: isDestructive ? colorScheme.error : colorScheme.primary,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: color.textTheme.boldStyle.copyWith(fontSize: 15),
                ),
              ),
              if (!isDestructive)
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

class UserMenuCard extends StatelessWidget {
  final List<Widget> children;

  const UserMenuCard({
    super.key,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outline.withAlpha(50),
          width: 0.5,
        ),
      ),
      child: Column(
        children: children,
      ),
    );
  }
}

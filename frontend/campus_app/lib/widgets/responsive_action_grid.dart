import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../utils/responsive.dart';

class ActionItem {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const ActionItem({
    required this.icon,
    required this.title,
    required this.onTap,
  });
}

class ResponsiveActionGrid extends StatelessWidget {
  final List<ActionItem> items;

  const ResponsiveActionGrid({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    final columns = Responsive.gridColumns(context, max: 4);
    return LayoutBuilder(
      builder: (context, constraints) {
        final spacing = 12.0;
        final itemWidth =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: items.map((item) {
            return SizedBox(
              width: itemWidth.clamp(140, constraints.maxWidth),
              child: _ActionTile(item: item),
            );
          }).toList(),
        );
      },
    );
  }
}

class _ActionTile extends StatelessWidget {
  final ActionItem item;

  const _ActionTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(item.icon, size: 36, color: AppTheme.primaryLight),
              const SizedBox(height: 10),
              Text(
                item.title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

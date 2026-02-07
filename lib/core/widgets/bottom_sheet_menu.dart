import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import 'icon_badge.dart';

/// A reusable bottom sheet menu item
class BottomSheetMenuItem {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  const BottomSheetMenuItem({
    required this.icon,
    required this.title,
    required this.onTap,
    this.iconColor = AppColors.primary,
    this.subtitle,
  });
}

/// A reusable bottom sheet menu with consistent styling.
///
/// Provides haptic feedback and proper accessibility.
class BottomSheetMenu extends StatelessWidget {
  final String title;
  final List<BottomSheetMenuItem> items;

  const BottomSheetMenu({
    super.key,
    required this.title,
    required this.items,
  });

  /// Shows the bottom sheet menu
  static Future<void> show({
    required BuildContext context,
    required String title,
    required List<BottomSheetMenuItem> items,
  }) {
    HapticFeedback.lightImpact();
    return showModalBottomSheet(
      context: context,
      builder: (ctx) => BottomSheetMenu(title: title, items: items),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 24),
          ...items.map<Widget>((item) => _MenuItemTile(item: item)),
        ],
      ),
    );
  }
}

class _MenuItemTile extends StatelessWidget {
  final BottomSheetMenuItem item;

  const _MenuItemTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${item.title}. ${item.subtitle ?? ""}',
      child: ListTile(
        leading: IconBadge(
          icon: item.icon,
          color: item.iconColor,
        ),
        title: Text(item.title),
        subtitle: item.subtitle != null ? Text(item.subtitle!) : null,
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          HapticFeedback.lightImpact();
          Navigator.pop(context);
          item.onTap();
        },
      ),
    );
  }
}

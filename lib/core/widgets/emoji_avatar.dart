import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Reusable avatar widget that handles emoji, URL, and fallback cases.
///
/// If [avatarUrl] starts with "emoji:", displays the emoji as text.
/// If [avatarUrl] is a URL, displays it as a NetworkImage.
/// Otherwise, shows a person icon fallback.
class EmojiAvatar extends StatelessWidget {
  final String? avatarUrl;
  final double radius;

  const EmojiAvatar({
    super.key,
    this.avatarUrl,
    this.radius = 48,
  });

  @override
  Widget build(BuildContext context) {
    if (avatarUrl != null && avatarUrl!.startsWith('emoji:')) {
      final emoji = avatarUrl!.substring(6);
      return CircleAvatar(
        radius: radius,
        backgroundColor: AppColors.gray200,
        child: Text(
          emoji,
          style: TextStyle(fontSize: radius * 0.9),
        ),
      );
    }

    if (avatarUrl != null && avatarUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: AppColors.gray200,
        backgroundImage: NetworkImage(avatarUrl!),
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.gray200,
      child: Icon(
        Icons.person,
        size: radius,
        color: AppColors.gray500,
      ),
    );
  }
}

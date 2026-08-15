import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../utils/image_url.dart';

/// Reusable avatar widget that handles emoji, URL, and fallback cases.
///
/// If [avatarUrl] starts with "emoji:", displays the emoji as text.
/// If [avatarUrl] is an http(s) URL, displays it as a NetworkImage.
/// Otherwise, shows a person icon fallback — anything else (a sentinel, a
/// legacy non-URL value) would make the network loader throw
/// `No host specified in URI`.
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

    if (isNetworkImageUrl(avatarUrl)) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: AppColors.gray200,
        backgroundImage: NetworkImage(avatarUrl!),
        // Keep the neutral gray circle if the picture fails to load.
        onBackgroundImageError: (_, _) {},
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

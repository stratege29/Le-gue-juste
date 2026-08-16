import 'package:flutter/material.dart';

import '../constants/app_constants.dart';
import '../theme/app_colors.dart';
import '../utils/image_url.dart';

/// Avatar for a group (gazoil), rendered from [GroupEntity.imageUrl].
///
/// The stored value can be either:
/// - a sentinel such as `icon:restaurant`, written when the user picks a
///   Material icon at creation time. It is NOT a URL and must never be
///   handed to [Image.network] (it throws `No host specified in URI`);
/// - a real http(s) URL pointing to an uploaded picture;
/// - `null` / empty, in which case a generic group icon is shown.
class GroupAvatar extends StatelessWidget {
  /// The raw `imageUrl` value coming from Firestore.
  final String? imageUrl;

  /// Width and height of the avatar box.
  final double size;

  /// Size of the icon shown when [imageUrl] is not a network image.
  final double iconSize;

  const GroupAvatar({
    super.key,
    required this.imageUrl,
    this.size = 56,
    this.iconSize = 28,
  });

  /// Prefix used to store a Material icon key instead of a real image URL.
  static const String iconPrefix = 'icon:';

  /// Returns the icon matching an `icon:<key>` sentinel, or `null` when
  /// [imageUrl] is not a sentinel.
  static IconData? iconFor(String? imageUrl) {
    if (imageUrl == null || !imageUrl.startsWith(iconPrefix)) return null;
    final key = imageUrl.substring(iconPrefix.length);
    return AppConstants.groupIcons[key] ?? Icons.group;
  }

  /// Whether [imageUrl] can safely be loaded over the network.
  static bool isNetworkImage(String? imageUrl) => isNetworkImageUrl(imageUrl);

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(size * 0.28);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: radius,
      ),
      child: isNetworkImage(imageUrl)
          ? ClipRRect(
              borderRadius: radius,
              child: Image.network(
                imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => _fallbackIcon(),
              ),
            )
          : _fallbackIcon(),
    );
  }

  Widget _fallbackIcon() => Icon(
        iconFor(imageUrl) ?? Icons.group,
        color: AppColors.primary,
        size: iconSize,
      );
}

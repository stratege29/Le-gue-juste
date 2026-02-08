import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../theme/app_colors.dart';
import '../theme/app_radius.dart';

/// A shimmer loading skeleton widget.
///
/// Use instead of CircularProgressIndicator for better UX.
class SkeletonLoader extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;

  const SkeletonLoader({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = AppRadius.md,
  });

  /// Creates a circular skeleton (for avatars)
  const SkeletonLoader.circle({
    super.key,
    required double size,
  })  : width = size,
        height = size,
        borderRadius = 999;

  /// Creates a text line skeleton
  const SkeletonLoader.text({
    super.key,
    this.width = double.infinity,
    this.height = 16,
  }) : borderRadius = AppRadius.sm;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Shimmer.fromColors(
      baseColor: isDark ? AppColors.gray800 : AppColors.gray200,
      highlightColor: isDark ? AppColors.gray700 : AppColors.primaryLight.withValues(alpha: 0.15),
      period: const Duration(milliseconds: 1500),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: AppColors.gray200,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}

/// A skeleton for list items (card with icon + text)
class SkeletonListItem extends StatelessWidget {
  const SkeletonListItem({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const SkeletonLoader.circle(size: 48),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonLoader(width: 120, height: 16, borderRadius: AppRadius.sm),
                  const SizedBox(height: 8),
                  SkeletonLoader(width: 80, height: 12, borderRadius: AppRadius.sm),
                ],
              ),
            ),
            SkeletonLoader(width: 60, height: 20, borderRadius: AppRadius.sm),
          ],
        ),
      ),
    );
  }
}

/// A skeleton for the summary card
class SkeletonSummaryCard extends StatelessWidget {
  const SkeletonSummaryCard({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Shimmer.fromColors(
      baseColor: isDark ? AppColors.gray800 : AppColors.gray300,
      highlightColor: isDark ? AppColors.gray700 : AppColors.primaryLight.withValues(alpha: 0.2),
      period: const Duration(milliseconds: 1500),
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(20),
        height: 140,
        decoration: BoxDecoration(
          color: AppColors.gray300,
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
      ),
    );
  }
}

/// A skeleton screen with summary card and list items
class SkeletonScreen extends StatelessWidget {
  final int itemCount;
  final bool showSummaryCard;

  const SkeletonScreen({
    super.key,
    this.itemCount = 5,
    this.showSummaryCard = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (showSummaryCard) const SkeletonSummaryCard(),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: itemCount,
            itemBuilder: (context, index) => const SkeletonListItem(),
          ),
        ),
      ],
    );
  }
}

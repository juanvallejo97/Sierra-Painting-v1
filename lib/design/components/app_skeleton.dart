import 'package:flutter/material.dart';
import 'package:sierra_painting/design/tokens.dart';

/// Skeleton loader for loading states
///
/// Shows placeholder content structure while data loads
class AppSkeleton extends StatelessWidget {
  final double? width;
  final double height;
  final BorderRadius? borderRadius;

  const AppSkeleton({super.key, this.width, this.height = 16, this.borderRadius});

  const AppSkeleton.card({super.key, this.width = double.infinity, this.height = 120})
    : borderRadius = const BorderRadius.all(Radius.circular(DesignTokens.radiusLG));

  const AppSkeleton.text({super.key, this.width = double.infinity, this.height = 16})
    : borderRadius = const BorderRadius.all(Radius.circular(DesignTokens.radiusSM));

  const AppSkeleton.circle({super.key, required double size}) : width = size, height = size, borderRadius = null;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius:
            borderRadius ??
            (width == height ? BorderRadius.circular(width! / 2) : BorderRadius.circular(DesignTokens.radiusSM)),
      ),
    );
  }
}

/// Skeleton card for list items
class SkeletonCard extends StatelessWidget {
  const SkeletonCard({super.key});

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(DesignTokens.spaceMD),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppSkeleton.text(width: double.infinity, height: 20),
            SizedBox(height: DesignTokens.spaceSM),
            AppSkeleton.text(width: 200, height: 16),
            SizedBox(height: DesignTokens.spaceSM),
            AppSkeleton.text(width: 150, height: 14),
          ],
        ),
      ),
    );
  }
}

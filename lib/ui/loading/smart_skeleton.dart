/// PHASE 2: SKELETON CODE - Smart Skeleton Loaders
///
/// PURPOSE:
/// - Performance-aware loading states
/// - Fallback to simple spinners on low-end devices
/// - Respect Reduce Motion system preference
/// - Feature flag controlled (shimmer can be disabled remotely)
/// - Timeout detection (show spinner if data takes >3s)

library smart_skeleton;

import 'dart:async';
import 'package:flutter/material.dart';

// ============================================================================
// SMART SKELETON - Main Widget
// ============================================================================

class SmartSkeleton extends StatefulWidget {
  final Widget child;
  final bool isLoading;
  final Duration timeout;
  final Widget? fallback;

  const SmartSkeleton({
    super.key,
    required this.child,
    required this.isLoading,
    this.timeout = const Duration(seconds: 3),
    this.fallback,
  });

  @override
  State<SmartSkeleton> createState() => _SmartSkeletonState();
}

class _SmartSkeletonState extends State<SmartSkeleton> {
  Timer? _timeoutTimer;
  bool _showFallback = false;

  @override
  void initState() {
    super.initState();
    _startTimeoutTimer();
  }

  @override
  void didUpdateWidget(SmartSkeleton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isLoading != oldWidget.isLoading) {
      if (widget.isLoading) {
        _startTimeoutTimer();
      } else {
        _cancelTimeoutTimer();
      }
    }
  }

  @override
  void dispose() {
    _cancelTimeoutTimer();
    super.dispose();
  }

  void _startTimeoutTimer() {
    if (!widget.isLoading) return;

    _showFallback = false;
    _timeoutTimer = Timer(widget.timeout, () {
      if (mounted && widget.isLoading) {
        setState(() {
          _showFallback = true;
        });
      }
    });
  }

  void _cancelTimeoutTimer() {
    _timeoutTimer?.cancel();
    _timeoutTimer = null;
    _showFallback = false;
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isLoading) {
      return widget.child;
    }

    // TODO(Phase 3): Check FeatureFlags.isEnabled(FeatureFlag.shimmerLoaders)
    final shimmerEnabled = false; // Default to false

    // TODO(Phase 3): Check device performance tier
    final isLowEndDevice = _isLowEndDevice();

    // TODO(Phase 3): Check Reduce Motion preference
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    // Show simple spinner if:
    // - Timeout exceeded, OR
    // - Low-end device, OR
    // - Reduce Motion enabled, OR
    // - Shimmer flag disabled
    if (_showFallback || isLowEndDevice || reduceMotion || !shimmerEnabled) {
      return widget.fallback ?? _buildSimpleSpinner();
    }

    // TODO(Phase 3): Integrate shimmer package
    return _buildShimmerSkeleton();
  }

  bool _isLowEndDevice() {
    // TODO(Phase 3): Use devicePixelRatio and performance tier detection
    final pixelRatio = MediaQuery.of(context).devicePixelRatio;
    return pixelRatio < 2.0;
  }

  Widget _buildSimpleSpinner() {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }

  Widget _buildShimmerSkeleton() {
    // TODO(Phase 3): Use Shimmer widget from shimmer package
    return Container(
      color: Colors.grey[300],
      child: const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}

// ============================================================================
// SKELETON CARD - Reusable Skeleton Card
// ============================================================================

class SkeletonCard extends StatelessWidget {
  final double? height;
  final double? width;
  final BorderRadius? borderRadius;

  const SkeletonCard({
    super.key,
    this.height,
    this.width,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[800] : Colors.grey[300],
        borderRadius: borderRadius ?? BorderRadius.circular(8),
      ),
    );
  }
}

// ============================================================================
// SKELETON TEXT - Text-shaped Skeleton
// ============================================================================

class SkeletonText extends StatelessWidget {
  final double width;
  final double height;
  final BorderRadius? borderRadius;

  const SkeletonText({
    super.key,
    required this.width,
    this.height = 16,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[800] : Colors.grey[300],
        borderRadius: borderRadius ?? BorderRadius.circular(4),
      ),
    );
  }
}

// ============================================================================
// SKELETON LIST - List of Skeleton Cards
// ============================================================================

class SkeletonList extends StatelessWidget {
  final int itemCount;
  final double itemHeight;
  final EdgeInsets? padding;

  const SkeletonList({
    super.key,
    this.itemCount = 5,
    this.itemHeight = 100,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: padding ?? const EdgeInsets.all(16),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: SkeletonCard(height: itemHeight),
        );
      },
    );
  }
}

// ============================================================================
// SKELETON AVATAR - Circle Avatar Skeleton
// ============================================================================

class SkeletonAvatar extends StatelessWidget {
  final double size;

  const SkeletonAvatar({
    super.key,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[800] : Colors.grey[300],
        shape: BoxShape.circle,
      ),
    );
  }
}

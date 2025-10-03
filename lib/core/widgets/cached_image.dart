/// Cached Image Widget
///
/// PURPOSE:
/// Optimized image widget with caching, progressive loading, and error handling.
/// Uses cached_network_image for better performance.
///
/// USAGE:
/// ```dart
/// CachedImage(
///   imageUrl: 'https://example.com/image.jpg',
///   width: 300,
///   height: 200,
///   fit: BoxFit.cover,
/// )
/// ```
///
/// FEATURES:
/// - Automatic caching (disk + memory)
/// - Progressive loading with placeholder
/// - Error handling with fallback
/// - Optimized for list views
///
/// PERFORMANCE:
/// - Cache hit: ~1-5ms
/// - Cache miss: ~100-500ms (network)
/// - Memory cached images: instant

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Cached image widget with optimized performance
class CachedImage extends StatelessWidget {
  /// Image URL
  final String imageUrl;

  /// Image width
  final double? width;

  /// Image height
  final double? height;

  /// Box fit
  final BoxFit? fit;

  /// Border radius
  final double? borderRadius;

  /// Placeholder color
  final Color? placeholderColor;

  /// Error icon
  final IconData errorIcon;

  /// Cache key (optional, defaults to imageUrl)
  final String? cacheKey;

  const CachedImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.placeholderColor,
    this.errorIcon = Icons.broken_image,
    this.cacheKey,
  });

  @override
  Widget build(BuildContext context) {
    final widget = CachedNetworkImage(
      imageUrl: imageUrl,
      cacheKey: cacheKey,
      width: width,
      height: height,
      fit: fit,
      placeholder: (context, url) => Container(
        width: width,
        height: height,
        color: placeholderColor ?? Colors.grey[200],
        child: const Center(
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      errorWidget: (context, url, error) => Container(
        width: width,
        height: height,
        color: Colors.grey[300],
        child: Icon(
          errorIcon,
          color: Colors.grey[600],
          size: 48,
        ),
      ),
      // Performance optimizations
      memCacheWidth: width?.toInt(),
      memCacheHeight: height?.toInt(),
      maxWidthDiskCache: 1000,
      maxHeightDiskCache: 1000,
      fadeInDuration: const Duration(milliseconds: 200),
      fadeOutDuration: const Duration(milliseconds: 100),
    );

    if (borderRadius != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius!),
        child: widget,
      );
    }

    return widget;
  }
}

/// Circular cached image (for avatars, profile pictures)
class CachedCircleImage extends StatelessWidget {
  /// Image URL
  final String imageUrl;

  /// Radius
  final double radius;

  /// Placeholder color
  final Color? placeholderColor;

  /// Error icon
  final IconData errorIcon;

  const CachedCircleImage({
    super.key,
    required this.imageUrl,
    this.radius = 24.0,
    this.placeholderColor,
    this.errorIcon = Icons.person,
  });

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: placeholderColor ?? Colors.grey[300],
      child: ClipOval(
        child: CachedNetworkImage(
          imageUrl: imageUrl,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          placeholder: (context, url) => Icon(
            errorIcon,
            size: radius,
            color: Colors.grey[600],
          ),
          errorWidget: (context, url, error) => Icon(
            errorIcon,
            size: radius,
            color: Colors.grey[600],
          ),
          // Optimize for small avatars
          memCacheWidth: (radius * 2 * 2).toInt(), // 2x for retina
          memCacheHeight: (radius * 2 * 2).toInt(),
          maxWidthDiskCache: 200,
          maxHeightDiskCache: 200,
        ),
      ),
    );
  }
}

/// Cached background image
class CachedBackgroundImage extends StatelessWidget {
  /// Image URL
  final String imageUrl;

  /// Child widget
  final Widget child;

  /// Box fit
  final BoxFit? fit;

  /// Opacity
  final double opacity;

  const CachedBackgroundImage({
    super.key,
    required this.imageUrl,
    required this.child,
    this.fit = BoxFit.cover,
    this.opacity = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: Opacity(
            opacity: opacity,
            child: CachedNetworkImage(
              imageUrl: imageUrl,
              fit: fit,
              placeholder: (context, url) => Container(
                color: Colors.grey[200],
              ),
              errorWidget: (context, url, error) => Container(
                color: Colors.grey[300],
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

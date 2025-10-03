/// Performance Overlay - Development Tool
///
/// PURPOSE:
/// Visual overlay showing performance metrics during development.
/// Helps identify performance issues early.
///
/// USAGE:
/// Wrap MaterialApp with PerformanceOverlay in debug mode:
/// ```dart
/// if (kDebugMode) {
///   return PerformanceOverlay(child: MaterialApp(...));
/// }
/// ```
///
/// METRICS:
/// - Frame render time (should be < 16ms for 60fps)
/// - Memory usage
/// - Network requests count
/// - Active animations

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

class PerformanceOverlay extends StatefulWidget {
  final Widget child;
  final bool enabled;

  const PerformanceOverlay({
    super.key,
    required this.child,
    this.enabled = kDebugMode,
  });

  @override
  State<PerformanceOverlay> createState() => _PerformanceOverlayState();
}

class _PerformanceOverlayState extends State<PerformanceOverlay> {
  int _frameCount = 0;
  double _averageFrameTime = 0.0;
  double _maxFrameTime = 0.0;
  final List<double> _frameTimes = [];
  final int _maxSamples = 60; // Track last 60 frames

  @override
  void initState() {
    super.initState();
    if (widget.enabled) {
      SchedulerBinding.instance.addTimingsCallback(_onFrame);
    }
  }

  @override
  void dispose() {
    if (widget.enabled) {
      SchedulerBinding.instance.removeTimingsCallback(_onFrame);
    }
    super.dispose();
  }

  void _onFrame(List<FrameTiming> timings) {
    if (!mounted) return;

    for (final timing in timings) {
      final frameTime = timing.totalSpan.inMilliseconds;
      _frameTimes.add(frameTime.toDouble());
      
      if (_frameTimes.length > _maxSamples) {
        _frameTimes.removeAt(0);
      }

      _frameCount++;
      _averageFrameTime = _frameTimes.reduce((a, b) => a + b) / _frameTimes.length;
      _maxFrameTime = _frameTimes.reduce((a, b) => a > b ? a : b);
    }

    if (mounted) {
      setState(() {});
    }
  }

  Color _getFrameColor() {
    if (_averageFrameTime < 16) return Colors.green;
    if (_averageFrameTime < 32) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      return widget.child;
    }

    return Stack(
      children: [
        widget.child,
        Positioned(
          top: 40,
          right: 10,
          child: Material(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    '⚡ Performance',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _getFrameColor(),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${_averageFrameTime.toStringAsFixed(1)}ms avg',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'Max: ${_maxFrameTime.toStringAsFixed(1)}ms',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
                    ),
                  ),
                  Text(
                    'FPS: ${(1000 / _averageFrameTime).toStringAsFixed(0)}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
                    ),
                  ),
                  Text(
                    'Frames: $_frameCount',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Performance banner for debug mode
class DebugPerformanceBanner extends StatelessWidget {
  final Widget child;

  const DebugPerformanceBanner({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) {
      return child;
    }

    return Banner(
      message: 'DEBUG',
      location: BannerLocation.topEnd,
      child: child,
    );
  }
}

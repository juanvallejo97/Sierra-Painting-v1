/// PHASE 2: SKELETON CODE - Enhanced KPI Cards V2
///
/// PURPOSE:
/// - Animated value transitions (smooth number changes)
/// - Trend indicators (up/down arrows with percentage)
/// - Drill-down navigation (tap to see details)
/// - Color-coded status (green = good, red = bad, amber = neutral)
/// - Sparkline mini charts (optional)
/// - Responsive sizing for mobile/tablet/desktop

library kpi_card_v2;

import 'package:flutter/material.dart';

// ============================================================================
// DATA STRUCTURES
// ============================================================================

enum TrendDirection {
  up,
  down,
  neutral,
}

enum KPIStatus {
  good, // Green - positive metric
  warning, // Amber - needs attention
  critical, // Red - urgent issue
  neutral, // Gray - informational only
}

class KPIData {
  final String label;
  final double value;
  final String? unit;
  final double? previousValue;
  final TrendDirection? trendDirection;
  final double? trendPercentage;
  final KPIStatus status;
  final List<double>? sparklineData;
  final VoidCallback? onTap;
  final String? subtitle;

  const KPIData({
    required this.label,
    required this.value,
    this.unit,
    this.previousValue,
    this.trendDirection,
    this.trendPercentage,
    this.status = KPIStatus.neutral,
    this.sparklineData,
    this.onTap,
    this.subtitle,
  });

  /// Calculate trend direction automatically
  TrendDirection get calculatedTrend {
    if (trendDirection != null) return trendDirection!;

    if (previousValue == null) return TrendDirection.neutral;

    if (value > previousValue!) {
      return TrendDirection.up;
    } else if (value < previousValue!) {
      return TrendDirection.down;
    } else {
      return TrendDirection.neutral;
    }
  }

  /// Calculate trend percentage automatically
  double get calculatedTrendPercentage {
    if (trendPercentage != null) return trendPercentage!;

    if (previousValue == null || previousValue == 0) return 0.0;

    final change = value - previousValue!;
    return (change / previousValue!) * 100;
  }
}

// ============================================================================
// MAIN KPI CARD V2
// ============================================================================

class KPICardV2 extends StatelessWidget {
  final KPIData data;
  final bool showTrend;
  final bool showSparkline;
  final bool animate;
  final Duration animationDuration;

  const KPICardV2({
    super.key,
    required this.data,
    this.showTrend = true,
    this.showSparkline = false,
    this.animate = true,
    this.animationDuration = const Duration(milliseconds: 1000),
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: data.onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: _getStatusGradient(),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(context),
              const SizedBox(height: 16),
              _buildValue(context),
              if (data.subtitle != null) _buildSubtitle(context),
              if (showTrend && data.previousValue != null) ...[
                const SizedBox(height: 8),
                _buildTrendIndicator(context),
              ],
              if (showSparkline && data.sparklineData != null) ...[
                const SizedBox(height: 16),
                _buildSparkline(context),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            data.label,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
        _buildStatusIndicator(context),
      ],
    );
  }

  Widget _buildValue(BuildContext context) {
    final valueString = _formatValue(data.value);

    if (animate) {
      return AnimatedValue(
        value: data.value,
        duration: animationDuration,
        builder: (context, animatedValue) {
          return Text(
            '${_formatValue(animatedValue)}${data.unit ?? ''}',
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          );
        },
      );
    }

    return Text(
      '$valueString${data.unit ?? ''}',
      style: Theme.of(context).textTheme.headlineLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
    );
  }

  Widget _buildSubtitle(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        data.subtitle!,
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }

  Widget _buildStatusIndicator(BuildContext context) {
    final color = _getStatusColor();

    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _buildTrendIndicator(BuildContext context) {
    final trend = data.calculatedTrend;
    final percentage = data.calculatedTrendPercentage.abs();

    IconData icon;
    Color color;

    switch (trend) {
      case TrendDirection.up:
        icon = Icons.arrow_upward;
        color = Colors.green;
        break;
      case TrendDirection.down:
        icon = Icons.arrow_downward;
        color = Colors.red;
        break;
      case TrendDirection.neutral:
        icon = Icons.remove;
        color = Colors.grey;
        break;
    }

    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(
          '${percentage.toStringAsFixed(1)}%',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(width: 8),
        Text(
          'vs previous',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _buildSparkline(BuildContext context) {
    // TODO(Phase 3): Integrate sparkline chart package or custom painter
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Center(
        child: Text('Sparkline chart'),
      ),
    );
  }

  LinearGradient? _getStatusGradient() {
    // TODO(Phase 3): Add subtle gradients based on status
    return null;
  }

  Color _getStatusColor() {
    switch (data.status) {
      case KPIStatus.good:
        return Colors.green;
      case KPIStatus.warning:
        return Colors.amber;
      case KPIStatus.critical:
        return Colors.red;
      case KPIStatus.neutral:
        return Colors.grey;
    }
  }

  String _formatValue(double value) {
    // TODO(Phase 3): Add better number formatting (K, M, B suffixes)
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    } else if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    } else if (value % 1 == 0) {
      return value.toInt().toString();
    } else {
      return value.toStringAsFixed(1);
    }
  }
}

// ============================================================================
// ANIMATED VALUE WIDGET
// ============================================================================

class AnimatedValue extends StatelessWidget {
  final double value;
  final Duration duration;
  final Widget Function(BuildContext, double) builder;

  const AnimatedValue({
    super.key,
    required this.value,
    required this.duration,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    // TODO(Phase 3): Check MediaQuery.disableAnimations for reduce motion
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    if (reduceMotion) {
      return builder(context, value);
    }

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, animatedValue, child) {
        return builder(context, animatedValue);
      },
    );
  }
}

// ============================================================================
// KPI GRID LAYOUT
// ============================================================================

class KPIGrid extends StatelessWidget {
  final List<KPIData> kpis;
  final int crossAxisCount;
  final double mainAxisSpacing;
  final double crossAxisSpacing;
  final double childAspectRatio;

  const KPIGrid({
    super.key,
    required this.kpis,
    this.crossAxisCount = 2,
    this.mainAxisSpacing = 16,
    this.crossAxisSpacing = 16,
    this.childAspectRatio = 1.5,
  });

  @override
  Widget build(BuildContext context) {
    // TODO(Phase 3): Make responsive based on screen size
    // Mobile: 1 column, Tablet: 2 columns, Desktop: 4 columns

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: mainAxisSpacing,
        crossAxisSpacing: crossAxisSpacing,
        childAspectRatio: childAspectRatio,
      ),
      itemCount: kpis.length,
      itemBuilder: (context, index) {
        return KPICardV2(data: kpis[index]);
      },
    );
  }
}

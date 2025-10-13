/// Estimate List Content Widget
///
/// PURPOSE:
/// Displays estimate list with loading/error/empty states.
/// Embedded in dashboard, handles all list logic internally.
///
/// FEATURES:
/// - Loading state with skeleton
/// - Error state with retry
/// - Empty state with action
/// - List with pull-to-refresh
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sierra_painting/design/design.dart';
import 'package:sierra_painting/features/estimates/presentation/providers/estimate_list_provider.dart';
import 'package:sierra_painting/features/estimates/presentation/widgets/estimate_list_item.dart';

class EstimateListContent extends ConsumerWidget {
  final VoidCallback? onCreateEstimate;

  const EstimateListContent({super.key, this.onCreateEstimate});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estimateListAsync = ref.watch(estimateListProvider);

    return estimateListAsync.when(
      data: (estimates) {
        if (estimates.isEmpty) {
          return AppEmpty(
            icon: Icons.description,
            title: 'No Estimates Yet',
            description:
                'Create an estimate to send quotes to potential customers.',
            actionLabel: onCreateEstimate != null ? 'Create Estimate' : null,
            onAction: onCreateEstimate,
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(estimateListProvider);
            // Wait for the refresh to complete
            await ref.read(estimateListProvider.future);
          },
          child: ListView.separated(
            padding: const EdgeInsets.all(DesignTokens.spaceMD),
            itemCount: estimates.length,
            separatorBuilder: (context, index) =>
                const SizedBox(height: DesignTokens.spaceSM),
            itemBuilder: (context, index) {
              final estimate = estimates[index];
              return EstimateListItem(
                estimate: estimate,
                onTap: () {
                  if (estimate.id != null) {
                    Navigator.of(
                      context,
                    ).pushNamed('/estimates/${estimate.id}');
                  }
                },
              );
            },
          ),
        );
      },
      loading: () => _buildLoading(),
      error: (error, stack) => _buildError(context, ref, error),
    );
  }

  Widget _buildLoading() {
    return ListView.separated(
      padding: const EdgeInsets.all(DesignTokens.spaceMD),
      itemCount: 5, // Show 5 skeleton items
      separatorBuilder: (context, index) =>
          const SizedBox(height: DesignTokens.spaceSM),
      itemBuilder: (context, index) =>
          const AppSkeleton(width: double.infinity, height: 100),
    );
  }

  Widget _buildError(BuildContext context, WidgetRef ref, Object error) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(DesignTokens.spaceXL),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: theme.colorScheme.error.withValues(alpha: 0.5),
            ),
            const SizedBox(height: DesignTokens.spaceMD),
            Text(
              'Failed to load estimates',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: DesignTokens.spaceSM),
            Text(
              error.toString(),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: DesignTokens.spaceLG),
            AppButton(
              label: 'Retry',
              icon: Icons.refresh,
              onPressed: () {
                ref.invalidate(estimateListProvider);
              },
            ),
          ],
        ),
      ),
    );
  }
}

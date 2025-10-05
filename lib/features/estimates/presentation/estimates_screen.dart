/// Estimates Screen
///
/// PURPOSE:
/// Manage and view customer estimates/quotes.
/// Create new estimates and track their status.
///
/// FEATURES:
/// - List all estimates
/// - Create new estimates
/// - View estimate details
/// - Generate estimate PDFs
/// - Track estimate status (draft, sent, accepted, rejected)
///
/// PERFORMANCE:
/// - Uses PaginatedListView for efficient list rendering
/// - Automatic pagination at 80% scroll
/// - Memory-efficient with lazy loading
///
/// TODO:
/// - Implement estimate creation form
/// - Add PDF generation integration
/// - Add estimate filtering and search
library;

import 'package:flutter/material.dart';
import 'package:sierra_painting/core/widgets/app_navigation.dart';
import 'package:sierra_painting/design/design.dart';
// import 'package:sierra_painting/core/widgets/paginated_list_view.dart'; // Uncomment when implementing list

class EstimatesScreen extends StatelessWidget {
  const EstimatesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Estimates')),
      drawer: const AppDrawer(),
      body: const _EstimatesBody(),
      bottomNavigationBar: const AppNavigationBar(),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Create new estimate
        },
        tooltip: 'Create Estimate',
        child: const Icon(Icons.add),
      ),
    );
  }
}

/// Estimates body - separated for better rebuild isolation
class _EstimatesBody extends StatelessWidget {
  const _EstimatesBody();

  @override
  Widget build(BuildContext context) {
    // TODO: Replace with actual data from repository
    final hasEstimates = false;

    if (!hasEstimates) {
      return const AppEmpty(
        icon: Icons.description,
        title: 'No Estimates Yet',
        description: 'Create an estimate to send to potential customers.',
        actionLabel: 'Create Estimate',
        onAction: null, // TODO: Wire to create estimate action
      );
    }

    // Performance-optimized list using PaginatedListView
    // When data is available, replace with:
    //
    // return PaginatedListView<Estimate>(
    //   itemBuilder: (context, estimate, index) => EstimateListItem(estimate: estimate),
    //   onLoadMore: () async {
    //     return await ref.read(estimateRepositoryProvider).fetchEstimates(page: currentPage);
    //   },
    //   emptyWidget: const AppEmpty(
    //     icon: Icons.description,
    //     title: 'No Estimates Yet',
    //     description: 'Create an estimate to send to potential customers.',
    //   ),
    //   itemExtent: 80.0, // Set for fixed-height items for better performance
    // );

  // ...existing code...
  }
}

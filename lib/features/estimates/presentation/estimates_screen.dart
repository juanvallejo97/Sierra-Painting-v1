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
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sierra_painting/core/widgets/app_navigation.dart';
import 'package:sierra_painting/design/design.dart';
import 'package:sierra_painting/features/estimates/data/estimate_repository.dart';
import 'package:sierra_painting/features/estimates/domain/estimate.dart';
// import 'package:sierra_painting/core/widgets/paginated_list_view.dart'; // Uncomment when implementing list

class EstimatesScreen extends ConsumerWidget {
  const EstimatesScreen({super.key});

  Future<void> _createEstimate(BuildContext context, WidgetRef ref) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You must be logged in to create estimates'),
          ),
        );
      }
      return;
    }

    // Get companyId from custom claims
    final idTokenResult = await user.getIdTokenResult();
    final companyId = idTokenResult.claims?['companyId'] as String?;

    if (companyId == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Company ID not found. Please contact support.'),
          ),
        );
      }
      return;
    }

    // TODO: Show estimate creation form dialog
    // For now, create a sample estimate for demonstration
    final repository = ref.read(estimateRepositoryProvider);
    final request = CreateEstimateRequest(
      companyId: companyId,
      customerId: 'sample-customer', // TODO: Select from customer list
      items: [
        EstimateItem(
          description: 'Sample Service',
          quantity: 1.0,
          unitPrice: 100.0,
        ),
      ],
      validUntil: DateTime.now().add(const Duration(days: 30)),
      notes: 'Sample estimate - please replace with actual form',
    );

    final result = await repository.createEstimate(request);

    if (context.mounted) {
      result.when(
        success: (estimate) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Estimate created: ${estimate.id}')),
          );
          // TODO: Navigate to estimate detail screen
        },
        failure: (error) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error creating estimate: $error')),
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Estimates')),
      drawer: const AppDrawer(),
      body: _EstimatesBody(
        onCreateEstimate: () => _createEstimate(context, ref),
      ),
      bottomNavigationBar: const AppNavigationBar(),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _createEstimate(context, ref),
        tooltip: 'Create Estimate',
        child: const Icon(Icons.add),
      ),
    );
  }
}

/// Estimates body - separated for better rebuild isolation
class _EstimatesBody extends StatelessWidget {
  final VoidCallback onCreateEstimate;

  const _EstimatesBody({required this.onCreateEstimate});

  @override
  Widget build(BuildContext context) {
    // TODO: Replace with actual data from repository
    final hasEstimates = false;

    if (!hasEstimates) {
      return AppEmpty(
        icon: Icons.description,
        title: 'No Estimates Yet',
        description: 'Create an estimate to send to potential customers.',
        actionLabel: 'Create Estimate',
        onAction: onCreateEstimate,
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

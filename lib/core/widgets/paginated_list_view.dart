/// Paginated List View
///
/// PURPOSE:
/// Optimized list view with built-in pagination, loading states, and error handling.
/// Follows best practices for Flutter list performance.
///
/// USAGE:
/// ```dart
/// PaginatedListView<Job>(
///   itemBuilder: (context, job, index) => JobTile(job: job),
///   onLoadMore: () async {
///     return await jobRepository.fetchJobs(page: currentPage);
///   },
///   emptyWidget: const EmptyJobsList(),
/// )
/// ```
///
/// FEATURES:
/// - Lazy loading with ListView.builder
/// - Automatic pagination when 80% scrolled
/// - Loading indicators
/// - Error handling
/// - Pull-to-refresh
/// - Empty state handling
///
/// PERFORMANCE:
/// - Only builds visible items
/// - Minimal rebuilds
/// - Smooth scrolling
/// - Memory efficient

import 'package:flutter/material.dart';

/// Callback for loading more items
typedef LoadMoreCallback<T> = Future<List<T>> Function();

/// Paginated list view with optimized performance
class PaginatedListView<T> extends StatefulWidget {
  /// Item builder
  final Widget Function(BuildContext context, T item, int index) itemBuilder;

  /// Load more callback
  final LoadMoreCallback<T> onLoadMore;

  /// Initial items
  final List<T>? initialItems;

  /// Empty state widget
  final Widget? emptyWidget;

  /// Error widget builder
  final Widget Function(Object error)? errorBuilder;

  /// Enable pull to refresh
  final bool enableRefresh;

  /// Item extent (height) for fixed-height lists
  final double? itemExtent;

  /// Separator builder
  final Widget Function(BuildContext, int)? separatorBuilder;

  /// Scroll controller
  final ScrollController? controller;

  /// Scroll physics
  final ScrollPhysics? physics;

  /// Padding
  final EdgeInsets? padding;

  const PaginatedListView({
    super.key,
    required this.itemBuilder,
    required this.onLoadMore,
    this.initialItems,
    this.emptyWidget,
    this.errorBuilder,
    this.enableRefresh = true,
    this.itemExtent,
    this.separatorBuilder,
    this.controller,
    this.physics,
    this.padding,
  });

  @override
  State<PaginatedListView<T>> createState() => _PaginatedListViewState<T>();
}

class _PaginatedListViewState<T> extends State<PaginatedListView<T>> {
  late final ScrollController _scrollController;
  late List<T> _items;
  bool _isLoading = false;
  bool _hasMore = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _scrollController = widget.controller ?? ScrollController();
    _items = widget.initialItems ?? [];
    
    // Add scroll listener for pagination
    _scrollController.addListener(_onScroll);

    // Load initial data if no initial items
    if (_items.isEmpty) {
      _loadMore();
    }
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _scrollController.dispose();
    }
    super.dispose();
  }

  void _onScroll() {
    if (_isLoading || !_hasMore) return;

    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    
    // Load more when 80% scrolled
    if (currentScroll >= maxScroll * 0.8) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final newItems = await widget.onLoadMore();
      
      setState(() {
        _items.addAll(newItems);
        _isLoading = false;
        _hasMore = newItems.isNotEmpty;
      });
    } catch (error) {
      setState(() {
        _error = error;
        _isLoading = false;
      });
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _items.clear();
      _hasMore = true;
      _error = null;
    });
    
    await _loadMore();
  }

  @override
  Widget build(BuildContext context) {
    // Show error if initial load failed
    if (_error != null && _items.isEmpty) {
      final errorWidget = widget.errorBuilder?.call(_error!) ??
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text('Error loading items: $_error'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _loadMore,
                  child: const Text('Retry'),
                ),
              ],
            ),
          );

      return widget.enableRefresh
          ? RefreshIndicator(
              onRefresh: _refresh,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: SizedBox(
                  height: MediaQuery.of(context).size.height * 0.8,
                  child: errorWidget,
                ),
              ),
            )
          : errorWidget;
    }

    // Show empty state
    if (_items.isEmpty && !_isLoading) {
      final emptyWidget = widget.emptyWidget ??
          const Center(
            child: Text('No items found'),
          );

      return widget.enableRefresh
          ? RefreshIndicator(
              onRefresh: _refresh,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: SizedBox(
                  height: MediaQuery.of(context).size.height * 0.8,
                  child: emptyWidget,
                ),
              ),
            )
          : emptyWidget;
    }

    // Build list
    final listView = widget.separatorBuilder != null
        ? ListView.separated(
            controller: _scrollController,
            physics: widget.physics,
            padding: widget.padding,
            itemCount: _items.length + (_hasMore ? 1 : 0),
            itemExtent: widget.itemExtent,
            separatorBuilder: widget.separatorBuilder!,
            itemBuilder: (context, index) {
              if (index >= _items.length) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: CircularProgressIndicator(),
                  ),
                );
              }
              return widget.itemBuilder(context, _items[index], index);
            },
          )
        : ListView.builder(
            controller: _scrollController,
            physics: widget.physics,
            padding: widget.padding,
            itemCount: _items.length + (_hasMore ? 1 : 0),
            itemExtent: widget.itemExtent,
            itemBuilder: (context, index) {
              if (index >= _items.length) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: CircularProgressIndicator(),
                  ),
                );
              }
              return widget.itemBuilder(context, _items[index], index);
            },
          );

    return widget.enableRefresh
        ? RefreshIndicator(
            onRefresh: _refresh,
            child: listView,
          )
        : listView;
  }
}

/// Optimized grid view with pagination
class PaginatedGridView<T> extends StatefulWidget {
  /// Item builder
  final Widget Function(BuildContext context, T item, int index) itemBuilder;

  /// Load more callback
  final LoadMoreCallback<T> onLoadMore;

  /// Initial items
  final List<T>? initialItems;

  /// Cross axis count
  final int crossAxisCount;

  /// Child aspect ratio
  final double childAspectRatio;

  /// Cross axis spacing
  final double crossAxisSpacing;

  /// Main axis spacing
  final double mainAxisSpacing;

  /// Empty state widget
  final Widget? emptyWidget;

  /// Enable pull to refresh
  final bool enableRefresh;

  /// Padding
  final EdgeInsets? padding;

  const PaginatedGridView({
    super.key,
    required this.itemBuilder,
    required this.onLoadMore,
    this.initialItems,
    this.crossAxisCount = 2,
    this.childAspectRatio = 1.0,
    this.crossAxisSpacing = 8.0,
    this.mainAxisSpacing = 8.0,
    this.emptyWidget,
    this.enableRefresh = true,
    this.padding,
  });

  @override
  State<PaginatedGridView<T>> createState() => _PaginatedGridViewState<T>();
}

class _PaginatedGridViewState<T> extends State<PaginatedGridView<T>> {
  late final ScrollController _scrollController;
  late List<T> _items;
  bool _isLoading = false;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _items = widget.initialItems ?? [];
    
    _scrollController.addListener(_onScroll);

    if (_items.isEmpty) {
      _loadMore();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_isLoading || !_hasMore) return;

    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    
    if (currentScroll >= maxScroll * 0.8) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final newItems = await widget.onLoadMore();
      
      setState(() {
        _items.addAll(newItems);
        _isLoading = false;
        _hasMore = newItems.isNotEmpty;
      });
    } catch (error) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _items.clear();
      _hasMore = true;
    });
    
    await _loadMore();
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty && !_isLoading) {
      final emptyWidget = widget.emptyWidget ??
          const Center(child: Text('No items found'));

      return widget.enableRefresh
          ? RefreshIndicator(
              onRefresh: _refresh,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: SizedBox(
                  height: MediaQuery.of(context).size.height * 0.8,
                  child: emptyWidget,
                ),
              ),
            )
          : emptyWidget;
    }

    final gridView = GridView.builder(
      controller: _scrollController,
      padding: widget.padding,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: widget.crossAxisCount,
        childAspectRatio: widget.childAspectRatio,
        crossAxisSpacing: widget.crossAxisSpacing,
        mainAxisSpacing: widget.mainAxisSpacing,
      ),
      itemCount: _items.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= _items.length) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }
        return widget.itemBuilder(context, _items[index], index);
      },
    );

    return widget.enableRefresh
        ? RefreshIndicator(
            onRefresh: _refresh,
            child: gridView,
          )
        : gridView;
  }
}

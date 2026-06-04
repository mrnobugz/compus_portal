import 'package:flutter/material.dart';
import '../utils/paginated_list_controller.dart';
import 'async_state_views.dart';

class PaginatedListView extends StatefulWidget {
  final PaginatedListController<Map<String, dynamic>> controller;
  final Widget Function(BuildContext context, Map<String, dynamic> item)
      itemBuilder;
  final String emptyMessage;
  final IconData emptyIcon;

  const PaginatedListView({
    super.key,
    required this.controller,
    required this.itemBuilder,
    this.emptyMessage = 'Nothing here yet',
    this.emptyIcon = Icons.inbox_outlined,
  });

  @override
  State<PaginatedListView> createState() => _PaginatedListViewState();
}

class _PaginatedListViewState extends State<PaginatedListView> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerUpdate);
    _scrollController.addListener(_onScroll);
    widget.controller.loadInitial();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerUpdate);
    _scrollController.dispose();
    super.dispose();
  }

  void _onControllerUpdate() {
    if (mounted) setState(() {});
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    widget.controller.onScroll(
      _scrollController.position.pixels,
      _scrollController.position.maxScrollExtent,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;

    if (c.isLoading && c.items.isEmpty) {
      return const LoadingView(message: 'Loading…');
    }

    if (c.error != null && c.items.isEmpty) {
      return ErrorStateView(message: c.error!, onRetry: c.refresh);
    }

    if (c.items.isEmpty) {
      return EmptyStateView(message: widget.emptyMessage, icon: widget.emptyIcon);
    }

    return RefreshIndicator(
      onRefresh: c.refresh,
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: c.items.length + (c.hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= c.items.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          return widget.itemBuilder(context, c.items[index]);
        },
      ),
    );
  }
}

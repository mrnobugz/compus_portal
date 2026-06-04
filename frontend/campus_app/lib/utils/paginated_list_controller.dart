import 'package:flutter/foundation.dart';
import '../core/api_exception.dart';
import '../services/api_service.dart';

/// Reusable reactive controller for paginated API lists.
class PaginatedListController<T extends Map<String, dynamic>>
    extends ChangeNotifier {
  final Future<PaginatedResponse<T>> Function(int page) fetchPage;

  PaginatedListController({required this.fetchPage});

  final List<T> items = [];
  bool isLoading = false;
  bool isLoadingMore = false;
  bool hasMore = true;
  String? error;
  int _page = 1;

  Future<void> loadInitial() async {
    _page = 1;
    hasMore = true;
    items.clear();
    error = null;
    isLoading = true;
    notifyListeners();

    try {
      final response = await fetchPage(_page);
      items.addAll(response.results);
      hasMore = response.hasMore;
    } catch (e) {
      error = _message(e);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() => loadInitial();

  Future<void> loadMore() async {
    if (!hasMore || isLoading || isLoadingMore) return;
    isLoadingMore = true;
    notifyListeners();

    try {
      _page += 1;
      final response = await fetchPage(_page);
      items.addAll(response.results);
      hasMore = response.hasMore;
      error = null;
    } catch (e) {
      _page -= 1;
      error = _message(e);
    } finally {
      isLoadingMore = false;
      notifyListeners();
    }
  }

  void onScroll(double pixels, double maxExtent) {
    if (pixels >= maxExtent - 200) {
      loadMore();
    }
  }

  String _message(Object e) {
    if (e is ApiException) return e.message;
    return 'Something went wrong. Check your connection.';
  }
}

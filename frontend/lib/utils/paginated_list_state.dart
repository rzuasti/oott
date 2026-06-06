import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../theme/dimens.dart';
import '../widgets/pagination_progress.dart';
import 'api/api_error.dart';

/// Shared state and orchestration for screens that show a paged, server-backed
/// list (devices, notifications). Provides the common pagination state, the
/// responsive page-size/page-count getters, the cancel-token-aware [runFetch]
/// helper, and disposal of the scroll controller and in-flight token.
///
/// Subclasses supply [phonePageSize], [widePageSize] and [isListEmpty], call
/// [runFetch] to load a page, and chain [dispose] via `super.dispose()`.
mixin PaginatedListState<W extends StatefulWidget> on State<W> {
  int currentPage = 0;
  // Total items matching the current filters, used to show how many pages exist
  // and to offer "go to last page".
  int totalCount = 0;
  bool isLoading = false;
  bool isPaging = false;
  bool didInitialFetch = false;
  String? error;
  CancelToken? fetchToken;
  final ScrollController scrollController = ScrollController();

  /// Page sizes for the phone and wider layouts.
  int get phonePageSize;
  int get widePageSize;

  /// Whether the list currently has no items. Controls whether a fetch shows
  /// the full loading state or refreshes the current page in place.
  bool get isListEmpty;

  int get pageSize => MediaQuery.sizeOf(context).width < Breakpoints.medium
      ? phonePageSize
      : widePageSize;
  int get totalPages => (totalCount / pageSize).ceil().clamp(1, 1 << 30);

  /// Runs a paged fetch with the orchestration shared by every paged list:
  /// optional scroll-to-top, cancel-token swap, loading flags, the
  /// unmounted/superseded guard, and error handling. [fetch] performs the
  /// request for the given page; [onResult] applies a still-current result to
  /// state (it is not called for cancelled, superseded, or failed fetches).
  Future<void> runFetch<R>(
    int page, {
    bool scrollToTop = false,
    bool paging = false,
    required Future<R> Function(int page, int perPage, CancelToken token) fetch,
    required void Function(R result) onResult,
  }) async {
    if (scrollToTop && scrollController.hasClients) {
      scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
    fetchToken?.cancel();
    final token = CancelToken();
    fetchToken = token;
    setState(() {
      isLoading = isListEmpty;
      isPaging = paging;
      error = null;
    });
    paginationLoading.value = paging;
    try {
      final result = await fetch(page, pageSize, token);
      if (!mounted || token != fetchToken) return;
      paginationLoading.value = false;
      onResult(result);
    } catch (e) {
      if (!mounted || token != fetchToken) return;
      if (e is DioException && e.type == DioExceptionType.cancel) return;
      setState(() {
        error = dioErrorToUserMessage(e);
        isLoading = false;
        isPaging = false;
      });
      paginationLoading.value = false;
    }
  }

  @override
  void dispose() {
    fetchToken?.cancel();
    scrollController.dispose();
    // Clear any in-flight cue so it doesn't linger after leaving the page.
    paginationLoading.value = false;
    super.dispose();
  }
}

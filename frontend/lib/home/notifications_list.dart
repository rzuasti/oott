import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../model/notification.dart' as oott_model;
import '../navigation.dart';
import '../theme/dimens.dart';
import '../utils/friendly_date_formatter.dart';
import '../utils/oott_api.dart';
import '../utils/ui_snackbars.dart';
import '../widgets/empty_state.dart';
import '../widgets/filter_selector.dart';
import '../widgets/pagination_bar.dart';
import '../widgets/pagination_progress.dart';
import '../widgets/skeleton.dart';
import 'notification_card.dart';

// Phones show fewer notifications so the list and its pagination controls fit
// on screen at once on the common current phones (e.g. iPhone 15, Pixel 8);
// wider layouts have the vertical room for a couple more.
const _phonePageSize = 4;
const _widePageSize = 5;

// Durations for the list's enter/exit animations.
const _insertDuration = Duration(milliseconds: 300);
const _removeDuration = Duration(milliseconds: 250);

enum _NotificationFilter {
  newOnly('New'),
  oldOnly('Old'),
  all('All');

  const _NotificationFilter(this.label);

  final String label;

  bool? get isNew => switch (this) {
    _NotificationFilter.newOnly => true,
    _NotificationFilter.oldOnly => false,
    _NotificationFilter.all => null,
  };
}

class NotificationsList extends StatefulWidget {
  const NotificationsList({super.key, this.trailingSlivers = const []});

  final List<Widget> trailingSlivers;

  @override
  State<NotificationsList> createState() => _NotificationsListState();
}

class _NotificationsListState extends State<NotificationsList>
    with RouteAware, WidgetsBindingObserver {
  _NotificationFilter _filter = _NotificationFilter.newOnly;
  Timer? _notificationTimer;

  int _currentPage = 0;
  bool _didInitialFetch = false;
  List<oott_model.Notification> _items = [];
  bool _isLoading = false;
  bool _isPaging = false;

  // Drives the animated list. Recreated on every reset (filter/page change,
  // initial load) so the new dataset mounts fresh without per-row animations;
  // kept stable across background refreshes so inserts/removals animate.
  GlobalKey<SliverAnimatedListState> _listKey = GlobalKey();
  // Ids of freshly arrived items that should play their highlight on next build.
  final Set<int> _flashIds = {};
  final FriendlyDateFormatter _formatter = FriendlyDateFormatter();

  int get _pageSize => MediaQuery.sizeOf(context).width < Breakpoints.medium
      ? _phonePageSize
      : _widePageSize;
  // Total notifications matching the current filter, used to show how many pages
  // exist and to offer "go to last page".
  int _totalCount = 0;
  int get _totalPages => (_totalCount / _pageSize).ceil().clamp(1, 1 << 30);
  String? _error;
  CancelToken? _fetchToken;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startTimer();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is ModalRoute<void>) {
      routeObserver.subscribe(this, route);
    }
    // Deferred from initState so the page size can read the screen width from
    // MediaQuery, which is only available once dependencies are in place.
    if (!_didInitialFetch) {
      _didInitialFetch = true;
      _fetchPage(0);
    }
  }

  @override
  void didPushNext() {
    _notificationTimer?.cancel();
    _notificationTimer = null;
  }

  @override
  void didPopNext() {
    _fetchPage(_currentPage, animateDiff: true);
    _startTimer();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _notificationTimer?.cancel();
      _notificationTimer = null;
    } else if (state == AppLifecycleState.resumed) {
      _fetchPage(_currentPage, animateDiff: true);
      _startTimer();
    }
  }

  void _startTimer() {
    _notificationTimer?.cancel();
    _notificationTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _fetchPage(_currentPage, animateDiff: true),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    routeObserver.unsubscribe(this);
    _notificationTimer?.cancel();
    _fetchToken?.cancel();
    _scrollController.dispose();
    // Clear any in-flight cue so it doesn't linger after leaving the page.
    paginationLoading.value = false;
    super.dispose();
  }

  /// Fetches [page]. When [scrollToTop] is set, the list animates back to its
  /// first item, so changing pages always starts the new page from the top.
  /// When [paging] is set the current page stays visible and the pagination
  /// bar shows a progress cue; background refreshes leave [paging] false so
  /// they don't flash the bar.
  ///
  /// When [animateDiff] is set (background refreshes), the new data is merged
  /// into the existing list so arrivals and departures animate. Otherwise the
  /// fetch is a reset (initial load, filter or page change): the list is
  /// rebuilt wholesale with no per-row animation.
  Future<void> _fetchPage(
    int page, {
    bool scrollToTop = false,
    bool paging = false,
    bool animateDiff = false,
  }) async {
    if (scrollToTop && _scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
    _fetchToken?.cancel();
    final token = CancelToken();
    _fetchToken = token;
    setState(() {
      _isLoading = _items.isEmpty;
      _isPaging = paging;
      _error = null;
    });
    paginationLoading.value = paging;
    try {
      final result = await BackendAPI.instance.listNotifications(
        _filter.isNew,
        page: page,
        perPage: _pageSize,
        cancelToken: token,
      );
      if (!mounted || token != _fetchToken) return;
      paginationLoading.value = false;
      if (animateDiff && !_isLoading) {
        // Merge into the live list so changes animate. Scalars are updated
        // without setState here; _reconcile schedules the rebuild itself so it
        // can defer swapping in the empty state until exit animations finish.
        _currentPage = page;
        _totalCount = result.totalCount;
        _isLoading = false;
        _isPaging = false;
        _reconcile(result.items);
        return;
      }
      // Reset: a fresh dataset. Recreate the list key so the animated list
      // mounts anew and shows the rows immediately, without insert animations.
      setState(() {
        _listKey = GlobalKey();
        _currentPage = page;
        _totalCount = result.totalCount;
        _items = result.items;
        _isLoading = false;
        _isPaging = false;
      });
    } catch (e) {
      if (!mounted || token != _fetchToken) return;
      if (e is DioException && e.type == DioExceptionType.cancel) return;
      setState(() {
        _error = dioErrorToUserMessage(e);
        _isLoading = false;
        _isPaging = false;
      });
      paginationLoading.value = false;
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      await BackendAPI.instance.markAllNotificationsAsRead();
    } catch (e) {
      if (!mounted) return;
      UISnackbars.showError(context, dioErrorToUserMessage(e));
      return;
    }
    if (!mounted) return;
    _fetchPage(_currentPage, animateDiff: true);
    UISnackbars.showSuccess(context, 'All notifications marked as read');
  }

  /// Toggles an item's read state on the backend. Returns true when the item
  /// should leave the current list (so the caller can remove it); the actual
  /// removal is performed by [_removeItem] via the card's `onRemove` callback,
  /// which keeps the animated list and `_items` in sync. Under the "All" filter
  /// the item stays and is just recoloured in place.
  Future<bool> _setRead(oott_model.Notification item, bool read) async {
    if (item.isNew == !read) {
      if (mounted) {
        UISnackbars.showWarning(
          context,
          'Notification was already marked as ${read ? 'read' : 'unread'}',
        );
      }
      return false;
    }
    try {
      if (read) {
        await BackendAPI.instance.markNotificationAsRead(item.id);
      } else {
        await BackendAPI.instance.markNotificationAsNew(item.id);
      }
    } catch (e) {
      if (!mounted) return false;
      UISnackbars.showError(context, dioErrorToUserMessage(e));
      return false;
    }
    if (!mounted) return false;
    UISnackbars.showSuccess(
      context,
      'Event marked as ${read ? 'read' : 'unread'}',
    );
    if (_filter != _NotificationFilter.all) return true;
    setState(() {
      final i = _items.indexWhere((n) => n.id == item.id);
      if (i != -1) _items[i] = _items[i].copyWith(isNew: !read);
    });
    return false;
  }

  /// Inserts [item] at [index] with a slide-in animation and queues its
  /// arrival highlight. Mutates `_items` in lockstep with the animated list.
  void _animatedInsert(int index, oott_model.Notification item) {
    _items.insert(index, item);
    _flashIds.add(item.id);
    _listKey.currentState?.insertItem(index, duration: _insertDuration);
  }

  /// Removes the item with [id] from `_items` and the animated list. When
  /// [animated] is true the row collapses with a slide/fade; when false (a
  /// swipe, already animated by [Dismissible]) it is dropped instantly.
  void _removeItem(int id, {required bool animated}) {
    final index = _items.indexWhere((n) => n.id == id);
    if (index == -1) return;
    final removed = _items.removeAt(index);
    _listKey.currentState?.removeItem(
      index,
      (context, animation) => animated
          ? _buildRemovingRow(removed, animation)
          : const SizedBox.shrink(),
      duration: animated ? _removeDuration : Duration.zero,
    );
  }

  /// Removes an item in response to a card action (swipe or mark read/unread
  /// that drops it from the current filter), then refreshes the surrounding
  /// chrome (header button, pagination, empty state). The total is decremented
  /// locally so the page count stays accurate without re-fetching; background
  /// refreshes re-sync it from the backend. Removals driven by [_reconcile] use
  /// [_removeItem] directly so they don't double-count against a fresh total.
  void _removeAndSettle(int id, {required bool animated}) {
    _removeItem(id, animated: animated);
    if (_totalCount > 0) _totalCount--;
    _afterStructuralChange();
  }

  /// Reconciles the live list with a freshly fetched [incoming] page: drops
  /// rows the backend no longer returns, applies in-place read-state changes,
  /// and slides newly fetched rows in at the top. Cheap O(n) scans suit the
  /// small page sizes and read more clearly than a full diff.
  void _reconcile(List<oott_model.Notification> incoming) {
    final incomingIds = incoming.map((n) => n.id).toSet();

    // Removals first, high index to low so earlier indices stay valid.
    for (var i = _items.length - 1; i >= 0; i--) {
      if (!incomingIds.contains(_items[i].id)) {
        _removeItem(_items[i].id, animated: true);
      }
    }

    // In-place read-state changes (e.g. "mark all as read" under "All").
    for (final n in incoming) {
      final i = _items.indexWhere((x) => x.id == n.id);
      if (i != -1 && _items[i].isNew != n.isNew) _items[i] = n;
    }

    // Insert fresh ids at their position in the newest-first ordering.
    final present = _items.map((n) => n.id).toSet();
    for (var i = 0; i < incoming.length; i++) {
      final n = incoming[i];
      if (!present.contains(n.id)) {
        _animatedInsert(i.clamp(0, _items.length), n);
        present.add(n.id);
      }
    }

    _afterStructuralChange();
  }

  /// Rebuilds the surrounding widgets after the list's contents change. When
  /// the list has emptied, the rebuild is deferred so exit animations finish
  /// before the empty state replaces the animated list (which would cut them
  /// off); otherwise it runs immediately to refresh the header and pagination.
  void _afterStructuralChange() {
    if (_items.isEmpty) {
      Future.delayed(_removeDuration, () {
        if (mounted) setState(() {});
      });
    } else if (mounted) {
      setState(() {});
    }
  }

  String _emptyMessage() => switch (_filter) {
    _NotificationFilter.newOnly => 'No new notifications',
    _NotificationFilter.oldOnly => 'No old notifications',
    _NotificationFilter.all => 'No notifications yet',
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildNotificationsHeader(context),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => _fetchPage(_currentPage, animateDiff: true),
            child: CustomScrollView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                ..._buildNotificationSlivers(context),
                ...widget.trailingSlivers,
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNotificationsHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Notifications',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const Spacer(),
            if (_filter == _NotificationFilter.newOnly && _items.isNotEmpty)
              IconButton(
                onPressed: _markAllAsRead,
                icon: const Icon(Icons.done_all),
                tooltip: 'Mark all as read',
              ),
          ],
        ),
        FilterSelector<_NotificationFilter>(
          values: _NotificationFilter.values,
          selected: _filter,
          labelOf: (f) => f.label,
          onSelected: (f) {
            setState(() => _filter = f);
            _fetchPage(0);
          },
        ),
      ],
    );
  }

  List<Widget> _buildNotificationSlivers(BuildContext context) {
    if (_isLoading) {
      return [const SliverToBoxAdapter(child: ListSkeleton(rows: 4))];
    }
    if (_error != null) {
      return [
        SliverFillRemaining(
          child: Center(
            child: Text(
              'Error: $_error',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ),
      ];
    }
    if (_items.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: EmptyState(
            icon: Icons.notifications_off_outlined,
            message: _emptyMessage(),
          ),
        ),
      ];
    }
    return [
      _buildNotificationSliver(),
      if (_currentPage > 0 || _totalPages > 1)
        SliverToBoxAdapter(
          child: PaginationBar(
            currentPage: _currentPage,
            totalPages: _totalPages,
            isLoading: _isPaging,
            onPageChanged: (page) =>
                _fetchPage(page, scrollToTop: true, paging: true),
          ),
        ),
    ];
  }

  Widget _buildNotificationSliver() {
    return SliverAnimatedList(
      key: _listKey,
      initialItemCount: _items.length,
      itemBuilder: (context, index, animation) =>
          _buildRow(_items[index], animation),
    );
  }

  Widget _buildRow(oott_model.Notification item, Animation<double> animation) {
    return SizeTransition(
      sizeFactor: animation,
      axisAlignment: -1,
      child: FadeTransition(
        opacity: animation,
        child: NotificationCard(
          key: ValueKey(item.id),
          item: item,
          formatter: _formatter,
          flash: _flashIds.contains(item.id),
          onFlashComplete: () => _flashIds.remove(item.id),
          onSetRead: (read) => _setRead(item, read),
          onRemove: ({required bool animated}) =>
              _removeAndSettle(item.id, animated: animated),
        ),
      ),
    );
  }

  // Builds a disappearing row for the animated list's removal transition. It is
  // inert (no key, no interaction) so it can't clash with a live card.
  Widget _buildRemovingRow(
    oott_model.Notification item,
    Animation<double> animation,
  ) {
    return SizeTransition(
      sizeFactor: animation,
      axisAlignment: -1,
      child: FadeTransition(
        opacity: animation,
        child: IgnorePointer(
          child: NotificationCard(
            item: item,
            formatter: _formatter,
            onSetRead: (_) async => false,
          ),
        ),
      ),
    );
  }
}

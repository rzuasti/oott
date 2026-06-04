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

  int get _pageSize => MediaQuery.sizeOf(context).width < Breakpoints.medium
      ? _phonePageSize
      : _widePageSize;
  bool _hasNextPage = false;
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
    _fetchPage(_currentPage);
    _startTimer();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _notificationTimer?.cancel();
      _notificationTimer = null;
    } else if (state == AppLifecycleState.resumed) {
      _fetchPage(_currentPage);
      _startTimer();
    }
  }

  void _startTimer() {
    _notificationTimer?.cancel();
    _notificationTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _fetchPage(_currentPage),
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
  Future<void> _fetchPage(
    int page, {
    bool scrollToTop = false,
    bool paging = false,
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
      setState(() {
        _currentPage = page;
        _hasNextPage = result.hasNextPage;
        _items = result.items;
        _isLoading = false;
        _isPaging = false;
      });
      paginationLoading.value = false;
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
    _fetchPage(_currentPage);
    UISnackbars.showSuccess(context, 'All notifications marked as read');
  }

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
    if (_filter != _NotificationFilter.all) {
      setState(() => _items = _items.where((n) => n.id != item.id).toList());
      return true;
    }
    setState(
      () => _items = _items
          .map((n) => n.id == item.id ? n.copyWith(isNew: !read) : n)
          .toList(),
    );
    return false;
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
            onRefresh: () => _fetchPage(_currentPage),
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
      if (_currentPage > 0 || _hasNextPage)
        SliverToBoxAdapter(
          child: PaginationBar(
            currentPage: _currentPage,
            hasNextPage: _hasNextPage,
            isLoading: _isPaging,
            onPageChanged: (page) =>
                _fetchPage(page, scrollToTop: true, paging: true),
          ),
        ),
    ];
  }

  Widget _buildNotificationSliver() {
    final formatter = FriendlyDateFormatter();
    return SliverList.builder(
      itemCount: _items.length,
      itemBuilder: (context, index) {
        final item = _items[index];
        return NotificationCard(
          key: ValueKey(item.id),
          item: item,
          formatter: formatter,
          onSetRead: (read) => _setRead(item, read),
        );
      },
    );
  }
}

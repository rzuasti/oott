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
import '../widgets/pagination_bar.dart';
import '../widgets/skeleton.dart';
import 'notification_card.dart';

const _pageSize = 5;

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
  List<oott_model.Notification> _items = [];
  bool _isLoading = false;
  bool _hasNextPage = false;
  String? _error;
  CancelToken? _fetchToken;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _fetchPage(0);
    _startTimer();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is ModalRoute<void>) {
      routeObserver.subscribe(this, route);
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
    super.dispose();
  }

  /// Fetches [page] and scrolls back to the top of the list, so changing pages
  /// always starts the new page from its first item.
  void _goToPage(int page) {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
    _fetchPage(page);
  }

  Future<void> _fetchPage(int page) async {
    _fetchToken?.cancel();
    final token = CancelToken();
    _fetchToken = token;
    setState(() {
      _isLoading = true;
      _error = null;
    });
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
      });
    } catch (e) {
      if (!mounted || token != _fetchToken) return;
      if (e is DioException && e.type == DioExceptionType.cancel) return;
      setState(() {
        _error = dioErrorToUserMessage(e);
        _isLoading = false;
      });
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
          child: CustomScrollView(
            controller: _scrollController,
            slivers: [
              ..._buildNotificationSlivers(context),
              ...widget.trailingSlivers,
            ],
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
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(
            horizontal: Insets.sm,
            vertical: Insets.xs,
          ),
          child: Wrap(
            spacing: Insets.sm,
            children: _NotificationFilter.values
                .map(
                  (f) => ChoiceChip(
                    label: Text(f.label),
                    selected: _filter == f,
                    onSelected: (_) {
                      setState(() => _filter = f);
                      _fetchPage(0);
                    },
                  ),
                )
                .toList(),
          ),
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
            isLoading: _isLoading,
            onPageChanged: _goToPage,
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

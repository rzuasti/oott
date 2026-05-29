import 'dart:async';

import 'package:flutter/material.dart';

import '../model/notification.dart' as oott_model;
import '../utils/friendly_date_formatter.dart';
import '../utils/oott_api.dart';
import '../utils/ui_snackbars.dart';
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

class _NotificationsListState extends State<NotificationsList> {
  _NotificationFilter _filter = _NotificationFilter.newOnly;
  Timer? _notificationTimer;

  int _currentPage = 0;
  List<oott_model.Notification> _items = [];
  bool _isLoading = false;
  bool _hasNextPage = false;

  @override
  void initState() {
    super.initState();
    _fetchPage(0);
    _notificationTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _fetchPage(_currentPage),
    );
  }

  @override
  void dispose() {
    _notificationTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchPage(int page) async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      final results = await BackendAPI.instance
          .listNotifications(_filter.isNew, page * _pageSize, limit: _pageSize + 1);
      if (!mounted) return;
      setState(() {
        _currentPage = page;
        _hasNextPage = results.length > _pageSize;
        _items = _hasNextPage ? results.take(_pageSize).toList() : results;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _markAllAsRead(BuildContext context) async {
    await BackendAPI.instance.markAllNotificationsAsRead();
    _fetchPage(_currentPage);
    if (context.mounted) {
      UISnackbars.showSuccess(context, 'All notifications marked as read');
    }
  }

  Future<bool> _setRead(
    BuildContext context,
    oott_model.Notification item,
    bool read,
  ) async {
    if (item.isNew == !read) {
      UISnackbars.showWarning(
        context,
        'Notification was already marked as ${read ? 'read' : 'unread'}',
      );
      return false;
    }
    if (read) {
      await BackendAPI.instance.markNotificationAsRead(item.id);
    } else {
      await BackendAPI.instance.markNotificationAsNew(item.id);
    }
    if (!context.mounted) return false;
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

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildNotificationsHeader(context),
        Expanded(
          child: CustomScrollView(
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
                onPressed: () => _markAllAsRead(context),
                icon: const Icon(Icons.done_all),
                tooltip: 'Mark all as read',
              ),
          ],
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Wrap(
            spacing: 8.0,
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
      return [
        const SliverFillRemaining(
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }
    if (_items.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 12),
            child: Center(
              child: Text(
                'No items found',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
      ];
    }
    return [
      _buildNotificationSliver(),
      if (_currentPage > 0 || _hasNextPage) _buildPaginationControls(context),
    ];
  }

  Widget _buildNotificationSliver() {
    final formatter = FriendlyDateFormatter();
    return SliverList.builder(
      itemCount: _items.length,
      itemBuilder: (context, index) {
        final item = _items[index];
        return NotificationCard(
          item: item,
          formatter: formatter,
          onSetRead: (ctx, read) => _setRead(ctx, item, read),
        );
      },
    );
  }

  Widget _buildPaginationControls(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton.outlined(
              onPressed: _currentPage > 0 && !_isLoading
                  ? () => _fetchPage(0)
                  : null,
              icon: const Icon(Icons.first_page),
              tooltip: 'First page',
            ),
            const SizedBox(width: 8),
            IconButton.outlined(
              onPressed: _currentPage > 0 && !_isLoading
                  ? () => _fetchPage(_currentPage - 1)
                  : null,
              icon: const Icon(Icons.chevron_left),
              tooltip: 'Previous page',
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Page ${_currentPage + 1}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            IconButton.outlined(
              onPressed: _hasNextPage && !_isLoading
                  ? () => _fetchPage(_currentPage + 1)
                  : null,
              icon: const Icon(Icons.chevron_right),
              tooltip: 'Next page',
            ),
          ],
        ),
      ),
    );
  }
}

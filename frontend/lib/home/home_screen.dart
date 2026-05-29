import 'dart:async';

import 'package:flutter/material.dart';

import '../model/notification.dart' as oott_model;
import '../utils/friendly_date_formatter.dart';
import '../utils/oott_api.dart';
import '../utils/ui_snackbars.dart';
import '../widgets/arp_scanner_card.dart';
import '../widgets/device_summary_card.dart';
import 'notification_card.dart';

const _twoColumnBreakpoint = 700.0;
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

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final isTwoColumn = constraints.maxWidth >= _twoColumnBreakpoint;
        return isTwoColumn
            ? _buildTwoColumn(context)
            : _buildSingleColumn(context);
      },
    );
  }

  Widget _buildTwoColumn(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildNotificationsHeader(context),
              Expanded(
                child: CustomScrollView(
                  slivers: [
                    ..._buildNotificationSlivers(context),
                  ],
                ),
              ),
            ],
          ),
        ),
        const VerticalDivider(width: 32),
        const SizedBox(
          width: 300,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DeviceSummaryCard(),
                SizedBox(height: 16),
                ArpScannerCard(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSingleColumn(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _buildNotificationsHeader(context)),
        ..._buildNotificationSlivers(context),
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.only(top: 24),
            child: DeviceSummaryCard(),
          ),
        ),
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.only(top: 16, bottom: 20),
            child: ArpScannerCard(),
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

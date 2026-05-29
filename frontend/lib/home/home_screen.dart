import 'dart:async';

import 'package:flutter/material.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

import '../model/notification.dart' as oott_model;
import '../utils/friendly_date_formatter.dart';
import '../utils/oott_api.dart';
import '../utils/ui_snackbars.dart';
import '../widgets/arp_scanner_card.dart';
import '../widgets/device_summary_card.dart';
import 'notification_card.dart';

const _twoColumnBreakpoint = 700.0;

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

  late final _pagingController =
      PagingController<int, oott_model.Notification>(
        getNextPageKey: (state) => state.lastPageIsEmpty
            ? null
            : (state.items == null ? 0 : state.items?.length),
        fetchPage: (pageKey) =>
            BackendAPI.instance.listNotifications(_filter.isNew, pageKey),
      );

  @override
  void initState() {
    super.initState();
    _notificationTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _pagingController.refresh(),
    );
  }

  @override
  void dispose() {
    _notificationTimer?.cancel();
    _pagingController.dispose();
    super.dispose();
  }

  Future<void> _markAllAsRead(BuildContext context) async {
    await BackendAPI.instance.markAllNotificationsAsRead();
    _pagingController.refresh();
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
      _pagingController.value = _pagingController.value.filterItems(
        (n) => n.id != item.id,
      );
      return true;
    }
    _pagingController.mapItems(
      (n) => n.id == item.id ? n.copyWith(isNew: !read) : n,
    );
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isTwoColumn = constraints.maxWidth >= _twoColumnBreakpoint;
        return PagingListener(
          controller: _pagingController,
          builder: (context, state, fetchNextPage) => isTwoColumn
              ? _buildTwoColumn(context, state, fetchNextPage)
              : _buildSingleColumn(context, state, fetchNextPage),
        );
      },
    );
  }

  Widget _buildTwoColumn(
    BuildContext context,
    PagingState<int, oott_model.Notification> state,
    void Function() fetchNextPage,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildNotificationsHeader(context, state),
              Expanded(
                child: CustomScrollView(
                  slivers: [_buildNotificationSliver(state, fetchNextPage)],
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

  Widget _buildSingleColumn(
    BuildContext context,
    PagingState<int, oott_model.Notification> state,
    void Function() fetchNextPage,
  ) {
    final isEmpty =
        !state.isLoading && state.items != null && state.items!.isEmpty;
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _buildNotificationsHeader(context, state)),
        if (isEmpty)
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
          )
        else
          _buildNotificationSliver(state, fetchNextPage),
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

  Widget _buildNotificationsHeader(
    BuildContext context,
    PagingState<int, oott_model.Notification> state,
  ) {
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
            if (_filter == _NotificationFilter.newOnly &&
                (state.items?.isNotEmpty ?? false))
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
                      _pagingController.refresh();
                    },
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildNotificationSliver(
    PagingState<int, oott_model.Notification> state,
    void Function() fetchNextPage,
  ) {
    final formatter = FriendlyDateFormatter();
    return PagedSliverList<int, oott_model.Notification>(
      state: state,
      fetchNextPage: fetchNextPage,
      builderDelegate: PagedChildBuilderDelegate(
        itemBuilder: (context, item, index) => NotificationCard(
          item: item,
          formatter: formatter,
          onSetRead: (ctx, read) => _setRead(ctx, item, read),
        ),
      ),
    );
  }
}

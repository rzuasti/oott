import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

import '../model/arp_scanner_status.dart';
import '../model/device_summary.dart';
import '../model/notification.dart' as oott_model;
import '../utils/friendly_date_formatter.dart';
import '../utils/oott_api.dart';
import '../utils/ui_snackbars.dart';
import '../widgets/arp_scanner_card.dart';

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
  // Notification state
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

  // Device summary state
  DeviceSummary? _deviceSummary;
  bool _isLoadingDeviceSummary = true;
  String? _deviceSummaryError;
  Timer? _deviceSummaryTimer;

  // Scanner status state
  ArpScannerStatus? _scannerStatus;
  DateTime? _scannerStatusReceivedAt;
  bool _isLoadingScanner = true;
  String? _scannerError;
  Timer? _scannerRefreshTimer;
  Timer? _scannerTickTimer;

  @override
  void initState() {
    super.initState();
    _notificationTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _pagingController.refresh(),
    );
    _loadDeviceSummary();
    _deviceSummaryTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _loadDeviceSummary(),
    );
    _loadScannerStatus();
    _scannerRefreshTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _loadScannerStatus(),
    );
    _scannerTickTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) {
        if (mounted) setState(() {});
      },
    );
  }

  @override
  void dispose() {
    _notificationTimer?.cancel();
    _pagingController.dispose();
    _deviceSummaryTimer?.cancel();
    _scannerRefreshTimer?.cancel();
    _scannerTickTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadDeviceSummary() async {
    try {
      final summary = await BackendAPI.instance.getDeviceSummary();
      if (!mounted) return;
      setState(() {
        _deviceSummary = summary;
        _deviceSummaryError = null;
        _isLoadingDeviceSummary = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _deviceSummaryError = e.toString();
        _isLoadingDeviceSummary = false;
      });
    }
  }

  Future<void> _loadScannerStatus() async {
    try {
      final status = await BackendAPI.instance.getArpScannerStatus();
      if (!mounted) return;
      setState(() {
        _scannerStatus = status;
        _scannerStatusReceivedAt = DateTime.now();
        _scannerError = null;
        _isLoadingScanner = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _scannerError = e.toString();
        _isLoadingScanner = false;
      });
    }
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
        SizedBox(
          width: 300,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildDeviceSummaryCard(context),
                const SizedBox(height: 16),
                _buildScannerCard(),
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
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _buildNotificationsHeader(context, state)),
        _buildNotificationSliver(state, fetchNextPage),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: 24),
            child: _buildDeviceSummaryCard(context),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 20),
            child: _buildScannerCard(),
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
        const SizedBox(height: 8),
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
        itemBuilder: (context, item, index) => _NotificationCard(
          item: item,
          formatter: formatter,
          onSetRead: (ctx, read) => _setRead(ctx, item, read),
        ),
      ),
    );
  }

  Widget _buildDeviceSummaryCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Devices', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            if (_isLoadingDeviceSummary)
              const Center(child: CircularProgressIndicator())
            else if (_deviceSummaryError != null)
              Text(
                'Error loading device summary',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                ),
              )
            else if (_deviceSummary != null) ...[
              _SummaryRow(
                label: 'Registered',
                value: '${_deviceSummary!.totalRegistered}',
              ),
              const Divider(height: 20),
              Text(
                'Seen in the last 24 hours',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
              const SizedBox(height: 6),
              _SummaryRow(
                label: 'Registered',
                value: '${_deviceSummary!.seenLastDayRegistered}',
              ),
              _SummaryRow(
                label: 'Unregistered',
                value: '${_deviceSummary!.seenLastDayUnregistered}',
              ),
              const Divider(height: 20),
              Text(
                'Seen in the last 7 days',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
              const SizedBox(height: 6),
              _SummaryRow(
                label: 'Registered',
                value: '${_deviceSummary!.seenLastWeekRegistered}',
              ),
              _SummaryRow(
                label: 'Unregistered',
                value: '${_deviceSummary!.seenLastWeekUnregistered}',
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildScannerCard() {
    return ArpScannerCard(
      status: _scannerStatus,
      statusReceivedAt: _scannerStatusReceivedAt,
      error: _scannerError,
      isLoading: _isLoadingScanner,
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final oott_model.Notification item;
  final FriendlyDateFormatter formatter;
  final Future<bool> Function(BuildContext, bool read) onSetRead;

  const _NotificationCard({
    required this.item,
    required this.formatter,
    required this.onSetRead,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: item.isNew ? theme.colorScheme.secondaryContainer : null,
      child: Dismissible(
        key: UniqueKey(),
        confirmDismiss: (direction) => direction == DismissDirection.startToEnd
            ? onSetRead(context, false)
            : onSetRead(context, true),
        background: Container(
          color: theme.colorScheme.tertiaryContainer,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.only(left: 16),
          child: const Icon(Icons.mark_email_unread),
        ),
        secondaryBackground: Container(
          color: theme.colorScheme.primaryContainer,
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 16),
          child: const Icon(Icons.done),
        ),
        child: ListTile(
          leading: Icon(
            item.notificationType.icon,
            color: item.isNew ? theme.colorScheme.primary : null,
          ),
          title: Text(
            '${formatter.format(item.createdOn)} - ${item.title}',
            style: item.isNew
                ? const TextStyle(fontWeight: FontWeight.bold)
                : null,
          ),
          subtitle: Text(item.body, maxLines: 5),
          trailing: PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) async {
              if (value == 'view_device') {
                if (item.isNew) await onSetRead(context, true);
                if (context.mounted) {
                  context.push('/devices/${item.macAddress}');
                }
              } else if (value == 'mark_read') {
                await onSetRead(context, true);
              } else if (value == 'mark_new') {
                await onSetRead(context, false);
              }
            },
            itemBuilder: (context) => [
              if (item.macAddress != null)
                const PopupMenuItem(
                  value: 'view_device',
                  child: Text('View device'),
                ),
              if (item.isNew)
                const PopupMenuItem(
                  value: 'mark_read',
                  child: Text('Mark as read'),
                ),
              if (!item.isNew)
                const PopupMenuItem(
                  value: 'mark_new',
                  child: Text('Mark as unread'),
                ),
            ],
          ),
          onTap: item.macAddress != null
              ? () async {
                  if (item.isNew) await onSetRead(context, true);
                  if (context.mounted) {
                    context.push('/devices/${item.macAddress}');
                  }
                }
              : null,
          isThreeLine: true,
        ),
      ),
    );
  }
}

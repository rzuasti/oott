import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../model/device.dart';
import '../model/device_type.dart';
import '../navigation.dart';
import '../utils/friendly_date_formatter.dart';
import '../utils/oott_api.dart';
import '../widgets/status_badge.dart';
import 'device_actions.dart';

const _pageSize = 5;

enum _DeviceFilter {
  newDevices('Not registered'),
  registered('Registered'),
  all('All');

  const _DeviceFilter(this.label);

  final String label;
}

class DeviceList extends StatefulWidget {
  const DeviceList({super.key});

  @override
  State<DeviceList> createState() => _DeviceListState();
}

class _DeviceListState extends State<DeviceList> with RouteAware {
  _DeviceFilter _filter = _DeviceFilter.newDevices;
  List<Device> _devices = [];
  bool _isLoading = true;
  String? _error;
  final TextEditingController _ownerController = TextEditingController();
  DeviceType? _typeFilter;
  Timer? _ownerDebounce;

  int _currentPage = 0;
  bool _hasNextPage = false;

  @override
  void initState() {
    super.initState();
    _ownerController.addListener(_onOwnerChanged);
    _fetchPage(0);
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
  void didPopNext() {
    _fetchPage(_currentPage);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _ownerDebounce?.cancel();
    _ownerController.dispose();
    super.dispose();
  }

  void _onOwnerChanged() {
    _ownerDebounce?.cancel();
    _ownerDebounce = Timer(
      const Duration(milliseconds: 500),
      () => _fetchPage(0),
    );
  }

  Future<void> _fetchPage(int page) async {
    setState(() {
      _isLoading = _devices.isEmpty;
      _error = null;
    });
    try {
      bool? isRegistered;
      if (_filter == _DeviceFilter.newDevices) isRegistered = false;
      if (_filter == _DeviceFilter.registered) isRegistered = true;

      final results = await BackendAPI.instance.listDevices(
        isRegistered: isRegistered,
        owner: _ownerController.text.isEmpty ? null : _ownerController.text,
        deviceType: _typeFilter,
        offset: page * _pageSize,
        limit: _pageSize + 1,
      );
      if (!mounted) return;
      setState(() {
        _currentPage = page;
        _hasNextPage = results.length > _pageSize;
        _devices = _hasNextPage ? results.take(_pageSize).toList() : results;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  String _emptyMessage() => switch (_filter) {
    _DeviceFilter.newDevices => 'No unregistered devices',
    _DeviceFilter.registered => 'No registered devices',
    _DeviceFilter.all => 'No devices found',
  };

  bool get _hasActiveDetailFilters =>
      _ownerController.text.isNotEmpty || _typeFilter != null;

  void _showFilterSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _DeviceFilterSheet(
        ownerController: _ownerController,
        typeFilter: _typeFilter,
        hasActiveFilters: _hasActiveDetailFilters,
        onTypeChanged: (value) {
          setState(() => _typeFilter = value);
          _fetchPage(0);
        },
        onClear: () {
          setState(() {
            _ownerController.clear();
            _typeFilter = null;
          });
          _fetchPage(0);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final formatter = FriendlyDateFormatter();
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text('Devices', style: textTheme.headlineSmall)),
            Badge(
              isLabelVisible: _hasActiveDetailFilters,
              child: IconButton(
                icon: const Icon(Icons.filter_list),
                tooltip: 'Filter',
                onPressed: () => _showFilterSheet(context),
              ),
            ),
          ],
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Wrap(
            spacing: 8.0,
            children: _DeviceFilter.values
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
        if (_isLoading)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else if (_error != null)
          Expanded(child: Center(child: Text('Error: $_error')))
        else if (_devices.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 12),
            child: Center(
              child: Text(
                _emptyMessage(),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          )
        else
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _fetchPage(_currentPage),
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverList.builder(
                    itemCount: _devices.length,
                    itemBuilder: (context, index) => _DeviceCard(
                      device: _devices[index],
                      formatter: formatter,
                      onRefresh: () => _fetchPage(_currentPage),
                    ),
                  ),
                  if (_currentPage > 0 || _hasNextPage)
                    _buildPaginationControls(context),
                ],
              ),
            ),
          ),
      ],
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

class _DeviceFilterSheet extends StatelessWidget {
  final TextEditingController ownerController;
  final DeviceType? typeFilter;
  final bool hasActiveFilters;
  final ValueChanged<DeviceType?> onTypeChanged;
  final VoidCallback onClear;

  const _DeviceFilterSheet({
    required this.ownerController,
    required this.typeFilter,
    required this.hasActiveFilters,
    required this.onTypeChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Filters', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          TextField(
            controller: ownerController,
            decoration: const InputDecoration(
              labelText: 'Owner',
              prefixIcon: Icon(Icons.person_outline),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<DeviceType?>(
            initialValue: typeFilter,
            decoration: const InputDecoration(
              labelText: 'Type',
              border: OutlineInputBorder(),
            ),
            items: [
              const DropdownMenuItem(value: null, child: Text('All types')),
              ...DeviceType.values.map(
                (t) => DropdownMenuItem(
                  value: t,
                  child: Row(
                    children: [
                      Icon(t.icon, size: 16),
                      const SizedBox(width: 4),
                      Text(t.label),
                    ],
                  ),
                ),
              ),
            ],
            onChanged: onTypeChanged,
          ),
          const SizedBox(height: 16),
          if (hasActiveFilters)
            OutlinedButton(
              onPressed: () {
                onClear();
                Navigator.of(context).pop();
              },
              child: const Text('Clear filters'),
            ),
        ],
      ),
    );
  }
}

class _DeviceCard extends StatelessWidget {
  final Device device;
  final FriendlyDateFormatter formatter;
  final VoidCallback onRefresh;

  const _DeviceCard({
    required this.device,
    required this.formatter,
    required this.onRefresh,
  });

  String get _registeredName {
    final type = device.deviceType == DeviceType.unknown
        ? 'Device'
        : device.deviceType.label;
    return "${device.owner}'s $type";
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: device.isRegistered ? null : theme.colorScheme.secondaryContainer,
      child: ListTile(
        onTap: () => context.push('/devices/${device.macAddress}'),
        leading: Tooltip(
          message: device.deviceType == DeviceType.unknown
              ? 'Device type unknown'
              : device.deviceType.label,
          child: Icon(device.deviceType.icon),
        ),
        title: Row(
          children: [
            Flexible(
              child: Text(
                device.isRegistered ? _registeredName : device.ipv4Address,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            if (device.isRegistered)
              const StatusBadge(label: 'Registered', color: BadgeColor.success)
            else
              const StatusBadge(
                label: 'Not registered',
                color: BadgeColor.secondary,
              ),
          ],
        ),
        subtitle: Text(
          '${device.isRegistered ? '${device.ipv4Address}\n' : ''}'
          '${device.vendor} · ${device.macAddress}\n'
          'Last seen: ${formatter.format(device.lastSeen)}',
        ),
        isThreeLine: true,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) async {
                if (value == 'details') {
                  context.push('/devices/${device.macAddress}');
                } else if (value == 'forget') {
                  await confirmForgetDevice(context, device, onRefresh);
                } else if (value == 'register') {
                  await showRegisterDeviceDialog(context, device, onRefresh);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'details',
                  child: Text('View details'),
                ),
                if (device.isRegistered)
                  const PopupMenuItem(value: 'forget', child: Text('Forget')),
                if (!device.isRegistered)
                  const PopupMenuItem(
                    value: 'register',
                    child: Text('Register'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

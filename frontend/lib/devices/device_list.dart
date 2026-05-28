import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../model/device.dart';
import '../model/device_type.dart';
import '../utils/friendly_date_formatter.dart';
import '../utils/oott_api.dart';
import '../widgets/status_badge.dart';
import 'device_actions.dart';

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

class _DeviceListState extends State<DeviceList> {
  _DeviceFilter _filter = _DeviceFilter.newDevices;
  List<Device> _devices = [];
  bool _isLoading = true;
  String? _error;
  final TextEditingController _ownerController = TextEditingController();
  DeviceType? _typeFilter;
  Timer? _ownerDebounce;

  @override
  void initState() {
    super.initState();
    _ownerController.addListener(_onOwnerChanged);
    _loadDevices();
  }

  @override
  void dispose() {
    _ownerDebounce?.cancel();
    _ownerController.dispose();
    super.dispose();
  }

  void _onOwnerChanged() {
    _ownerDebounce?.cancel();
    _ownerDebounce = Timer(const Duration(milliseconds: 500), _loadDevices);
  }

  Future<void> _loadDevices() async {
    setState(() {
      _isLoading = _devices.isEmpty;
      _error = null;
    });
    try {
      bool? isRegistered;
      if (_filter == _DeviceFilter.newDevices) isRegistered = false;
      if (_filter == _DeviceFilter.registered) isRegistered = true;

      final devices = await BackendAPI.instance.listDevices(
        isRegistered: isRegistered,
        owner: _ownerController.text.isEmpty ? null : _ownerController.text,
        deviceType: _typeFilter,
      );
      if (!mounted) return;
      setState(() {
        _devices = devices;
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
          _loadDevices();
        },
        onClear: () {
          setState(() {
            _ownerController.clear();
            _typeFilter = null;
          });
          _loadDevices();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final formatter = FriendlyDateFormatter();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Devices'),
        actions: [
          Badge(
            isLabelVisible: _hasActiveDetailFilters,
            child: IconButton(
              icon: const Icon(Icons.filter_list),
              tooltip: 'Filter',
              onPressed: () => _showFilterSheet(context),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Align(
            alignment: Alignment.centerLeft,
            child: SingleChildScrollView(
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
                          _loadDevices();
                        },
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text('Error: $_error'))
          : _devices.isEmpty
          ? Center(child: Text(_emptyMessage()))
          : RefreshIndicator(
              onRefresh: _loadDevices,
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: _devices.length,
                itemBuilder: (context, index) => _DeviceCard(
                  device: _devices[index],
                  formatter: formatter,
                  onRefresh: _loadDevices,
                ),
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
            Text(device.ipv4Address),
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
          '${device.vendor} · ${device.macAddress}\n'
          'Last seen: ${formatter.format(device.lastSeen)}',
        ),
        isThreeLine: true,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (device.isRegistered) Text(device.owner),
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

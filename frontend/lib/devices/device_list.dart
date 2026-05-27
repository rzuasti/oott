import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../model/device.dart';
import '../model/device_type.dart';
import '../utils/friendly_date_formatter.dart';
import '../utils/oott_api.dart';
import '../widgets/status_badge.dart';
import 'device_actions.dart';

enum _DeviceFilter { newDevices, registered, all }

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

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  @override
  void dispose() {
    super.dispose();
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

  String _emptyMessage() {
    switch (_filter) {
      case _DeviceFilter.newDevices:
        return 'No unregistered devices';
      case _DeviceFilter.registered:
        return 'No registered devices';
      case _DeviceFilter.all:
        return 'No devices found';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final formatter = FriendlyDateFormatter();

    return Scaffold(
      appBar: AppBar(title: const Text('Devices')),
      body: Column(
        children: [
          Container(
            height: 50,
            alignment: Alignment.centerRight,
            child: Wrap(
              spacing: 8.0,
              children: [
                ChoiceChip(
                  label: const Text('Not registered'),
                  selected: _filter == _DeviceFilter.newDevices,
                  onSelected: (bool selected) {
                    setState(() => _filter = _DeviceFilter.newDevices);
                    _loadDevices();
                  },
                ),
                ChoiceChip(
                  label: const Text('Registered'),
                  selected: _filter == _DeviceFilter.registered,
                  onSelected: (bool selected) {
                    setState(() => _filter = _DeviceFilter.registered);
                    _loadDevices();
                  },
                ),
                ChoiceChip(
                  label: const Text('All'),
                  selected: _filter == _DeviceFilter.all,
                  onSelected: (bool selected) {
                    setState(() => _filter = _DeviceFilter.all);
                    _loadDevices();
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
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
                      itemBuilder: (context, index) {
                        final device = _devices[index];
                        return Card(
                          color: device.isRegistered
                              ? null
                              : theme.colorScheme.secondaryContainer,
                          child: ListTile(
                            onTap: () =>
                                context.push('/devices/${device.macAddress}'),
                            leading: Tooltip(
                              message: device.deviceType == DeviceType.unknown
                                  ? 'Device type unknown'
                                  : device.deviceType.label,
                              child: Icon(device.deviceType.icon),
                            ),
                            title: Row(
                              children: [
                                Text(device.ipv4Address),
                                if (!device.isRegistered) ...[
                                  const SizedBox(width: 8),
                                  const StatusBadge(
                                    label: 'Not registered',
                                    color: BadgeColor.secondary,
                                  ),
                                ],
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
                                      context.push(
                                        '/devices/${device.macAddress}',
                                      );
                                    } else if (value == 'forget') {
                                      await confirmForgetDevice(context, device, _loadDevices);
                                    } else if (value == 'register') {
                                      await showRegisterDeviceDialog(context, device, _loadDevices);
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    const PopupMenuItem(
                                      value: 'details',
                                      child: Text('View details'),
                                    ),
                                    if (device.isRegistered)
                                      const PopupMenuItem(
                                        value: 'forget',
                                        child: Text('Forget'),
                                      ),
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
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

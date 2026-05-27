import 'dart:async';

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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
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
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _ownerController,
                        decoration: const InputDecoration(
                          labelText: 'Owner',
                          prefixIcon: Icon(Icons.person_outline),
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<DeviceType?>(
                        initialValue: _typeFilter,
                        decoration: const InputDecoration(
                          labelText: 'Type',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('All'),
                          ),
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
                        onChanged: (value) {
                          setState(() => _typeFilter = value);
                          _loadDevices();
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
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
                                const SizedBox(width: 8),
                                if (device.isRegistered)
                                  const StatusBadge(
                                    label: 'Registered',
                                    color: BadgeColor.success,
                                  )
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

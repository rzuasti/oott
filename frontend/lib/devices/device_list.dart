import 'package:flutter/material.dart';

import '../model/device.dart';
import '../utils/friendly_date_formatter.dart';
import '../utils/oott_api.dart';
import '../utils/ui_snackbars.dart';
import '../widgets/status_badge.dart';

const _deviceTypes = [
  'phone',
  'laptop',
  'tablet',
  'server',
  'router',
  'tv',
  'printer',
  'unknown',
];

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

  Future<void> _confirmForget(Device device) async {
    final colorScheme = Theme.of(context).colorScheme;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Forget Device'),
        content: Text(
          'This device will be unregistered and will no longer be linked to '
          '${device.owner}. Are you sure?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Forget', style: TextStyle(color: colorScheme.error)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await BackendAPI.instance.forgetDevice(device.macAddress);
      if (!mounted) return;
      UISnackbars.showSuccess(context, 'Device forgotten');
      _loadDevices();
    } catch (e) {
      if (!mounted) return;
      UISnackbars.showError(context, 'Failed to forget device: $e');
    }
  }

  Future<void> _showRegisterDialog(Device device) async {
    final formKey = GlobalKey<FormState>();
    String owner = '';
    String deviceType = _deviceTypes.contains(device.deviceType)
        ? device.deviceType
        : 'unknown';

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Register Device'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  decoration: const InputDecoration(labelText: 'Owner'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Owner is required'
                      : null,
                  onSaved: (value) => owner = value?.trim() ?? '',
                ),
                const SizedBox(height: 16),
                InputDecorator(
                  decoration: const InputDecoration(labelText: 'Device Type'),
                  child: DropdownButton<String>(
                    value: deviceType,
                    isExpanded: true,
                    underline: const SizedBox(),
                    items: _deviceTypes
                        .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                        .toList(),
                    onChanged: (value) =>
                        setDialogState(() => deviceType = value ?? deviceType),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  formKey.currentState?.save();
                  Navigator.of(context).pop(true);
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (saved != true || !mounted) return;

    try {
      await BackendAPI.instance.registerDevice(
        device.macAddress,
        owner,
        deviceType,
      );
      if (!mounted) return;
      UISnackbars.showSuccess(context, 'Device registered');
      _loadDevices();
    } catch (e) {
      if (!mounted) return;
      UISnackbars.showError(context, 'Failed to register device: $e');
    }
  }

  IconData _deviceIcon(String deviceType) {
    switch (deviceType.toLowerCase()) {
      case 'phone':
        return Icons.phone_android;
      case 'laptop':
        return Icons.laptop;
      case 'tablet':
        return Icons.tablet_android;
      case 'server':
        return Icons.dns;
      case 'router':
        return Icons.router;
      case 'tv':
        return Icons.tv;
      case 'printer':
        return Icons.print;
      default:
        return Icons.device_unknown;
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
                            leading: Tooltip(
                              message:
                                  device.deviceType.isEmpty ||
                                      device.deviceType == 'unknown'
                                  ? 'Device type unknown'
                                  : device.deviceType,
                              child: Icon(_deviceIcon(device.deviceType)),
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
                                    if (value == 'forget') {
                                      await _confirmForget(device);
                                    } else if (value == 'register') {
                                      await _showRegisterDialog(device);
                                    }
                                  },
                                  itemBuilder: (context) => [
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

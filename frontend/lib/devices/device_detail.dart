import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../model/device.dart';
import '../model/device_type.dart';
import '../utils/friendly_date_formatter.dart';
import '../utils/oott_api.dart';
import '../utils/ui_snackbars.dart';
import '../widgets/status_badge.dart';

class DeviceDetail extends StatefulWidget {
  final String macAddress;

  const DeviceDetail({super.key, required this.macAddress});

  @override
  State<DeviceDetail> createState() => _DeviceDetailState();
}

class _DeviceDetailState extends State<DeviceDetail> {
  Device? _device;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDevice();
  }

  Future<void> _loadDevice() async {
    setState(() {
      _isLoading = _device == null;
      _error = null;
    });
    try {
      final device = await BackendAPI.instance.getDevice(widget.macAddress);
      if (!mounted) return;
      setState(() {
        _device = device;
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
      _loadDevice();
    } catch (e) {
      if (!mounted) return;
      UISnackbars.showError(context, 'Failed to forget device: $e');
    }
  }

  Future<void> _showRegisterDialog(Device device) async {
    final formKey = GlobalKey<FormState>();
    String owner = '';
    DeviceType deviceType = device.deviceType;

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
                  child: DropdownButton<DeviceType>(
                    value: deviceType,
                    isExpanded: true,
                    underline: const SizedBox(),
                    items: DeviceType.values
                        .map(
                          (t) =>
                              DropdownMenuItem(value: t, child: Text(t.label)),
                        )
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
        deviceType.name,
      );
      if (!mounted) return;
      UISnackbars.showSuccess(context, 'Device registered');
      _loadDevice();
    } catch (e) {
      if (!mounted) return;
      UISnackbars.showError(context, 'Failed to register device: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final device = _device;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Device Details'),
        leading: BackButton(onPressed: () => context.pop()),
        actions: [
          if (device != null)
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Error: $_error'),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _loadDevice,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : device == null
          ? const Center(child: Text('Device not found'))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DeviceHeader(device: device),
                  const SizedBox(height: 24),
                  _DeviceInfoCard(device: device),
                ],
              ),
            ),
    );
  }
}

class _DeviceHeader extends StatelessWidget {
  final Device device;

  const _DeviceHeader({required this.device});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(device.deviceType.icon, size: 48),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(device.ipv4Address, style: theme.textTheme.headlineSmall),
              const SizedBox(height: 4),
              if (device.isRegistered)
                StatusBadge(label: 'Registered', color: BadgeColor.success)
              else
                StatusBadge(
                  label: 'Not registered',
                  color: BadgeColor.secondary,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DeviceInfoCard extends StatelessWidget {
  final Device device;

  const _DeviceInfoCard({required this.device});

  @override
  Widget build(BuildContext context) {
    final formatter = FriendlyDateFormatter();

    return Card(
      child: Column(
        children: [
          _InfoRow(label: 'MAC Address', value: device.macAddress),
          const Divider(height: 1),
          _InfoRow(label: 'IP Address', value: device.ipv4Address),
          const Divider(height: 1),
          _InfoRow(
            label: 'Vendor',
            value: device.vendor.isEmpty ? '—' : device.vendor,
          ),
          const Divider(height: 1),
          _InfoRow(
            label: 'Last Seen',
            value: formatter.format(device.lastSeen),
          ),
          const Divider(height: 1),
          _InfoRow(label: 'Device Type', value: device.deviceType.label),
          const Divider(height: 1),
          _InfoRow(
            label: 'Owner',
            value: device.owner.isEmpty ? '—' : device.owner,
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(child: Text(value, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

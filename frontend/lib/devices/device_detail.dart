import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../model/device.dart';
import '../utils/friendly_date_formatter.dart';
import '../utils/oott_api.dart';
import '../widgets/status_badge.dart';
import 'device_actions.dart';
import 'device_event_history.dart';

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
                  await confirmForgetDevice(context, device, _loadDevice);
                } else if (value == 'register') {
                  await showRegisterDeviceDialog(context, device, _loadDevice);
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
                  const SizedBox(height: 24),
                  _SectionHeader(title: 'Event History'),
                  const SizedBox(height: 12),
                  DeviceEventHistory(device: device),
                ],
              ),
            ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(title, style: Theme.of(context).textTheme.titleMedium);
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
        Icon(
          device.deviceType.icon,
          size: 48,
          color: theme.colorScheme.onSurface,
        ),
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
    final rows = <(String, String)>[
      ('MAC Address', device.macAddress),
      ('IP Address', device.ipv4Address),
      ('Vendor', device.vendor.isEmpty ? '—' : device.vendor),
      ('Last Seen', formatter.format(device.lastSeen)),
      ('Device Type', device.deviceType.label),
      ('Owner', device.owner.isEmpty ? '—' : device.owner),
    ];

    return Card(
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            _InfoRow(label: rows[i].$1, value: rows[i].$2),
            if (i < rows.length - 1) const Divider(height: 1),
          ],
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

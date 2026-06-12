import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../model/device.dart';
import '../model/device_type.dart';
import '../routes.dart';
import '../utils/friendly_date_formatter.dart';
import '../utils/oott_api.dart';
import '../widgets/status_badge.dart';
import 'device_actions.dart';
import 'device_event_history.dart';
import 'device_identification_guide.dart';
import '../theme/dimens.dart';
import '../utils/placeholders.dart';

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
      if (e is DioException && e.type == DioExceptionType.cancel) return;
      setState(() {
        _error = dioErrorToUserMessage(e);
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final device = _device;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            BackButton(onPressed: () => context.pop()),
            Expanded(
              child: Text(
                'Device Details',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
          ],
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Error: $_error'),
                      const SizedBox(height: Insets.lg),
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
                  padding: const EdgeInsets.all(Insets.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _DeviceHeader(device: device),
                      const SizedBox(height: Insets.xxl),
                      _DeviceInfoCard(device: device),
                      const SizedBox(height: Insets.xxl),
                      _DeviceActions(device: device, onAction: _loadDevice),
                      const SizedBox(height: Insets.xxl),
                      _SectionHeader(title: 'Event History'),
                      const SizedBox(height: Insets.md),
                      DeviceEventHistory(device: device),
                    ],
                  ),
                ),
        ),
      ],
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
        const SizedBox(width: Insets.lg),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SelectableText(
                device.ipv4Address,
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: Insets.xs),
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
      (
        'Name',
        device.name == null || device.name!.isEmpty
            ? Placeholders.emptyValue
            : device.name!,
      ),
      ('MAC Address', device.macAddress),
      ('IP Address', device.ipv4Address),
      (
        'Vendor',
        device.vendor.isEmpty ? Placeholders.emptyValue : device.vendor,
      ),
      ('Last Seen', formatter.format(device.lastSeen)),
      (
        'Device Type',
        device.deviceType == DeviceType.unknown
            ? Placeholders.emptyValue
            : device.deviceType.label,
      ),
      ('Owner', device.owner.isEmpty ? Placeholders.emptyValue : device.owner),
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

class _DeviceActions extends StatelessWidget {
  final Device device;
  final VoidCallback onAction;

  const _DeviceActions({required this.device, required this.onAction});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final destructiveStyle = TextButton.styleFrom(
      foregroundColor: colorScheme.error,
    );

    final List<Widget> leading;
    final Widget destructive;
    if (device.isRegistered) {
      leading = [
        FilledButton.icon(
          onPressed: () => showEditDeviceDialog(context, device, onAction),
          icon: const Icon(Icons.edit),
          label: const Text('Edit'),
        ),
      ];
      destructive = TextButton.icon(
        style: destructiveStyle,
        onPressed: () => confirmForgetDevice(
          context,
          device,
          onAction,
          onDeleted: () => context.go(Routes.devices),
        ),
        icon: const Icon(Icons.link_off),
        label: const Text('Forget Device'),
      );
    } else {
      leading = [
        FilledButton.icon(
          onPressed: () => showRegisterDeviceDialog(context, device, onAction),
          icon: const Icon(Icons.how_to_reg),
          label: const Text('Register Device'),
        ),
        TextButton.icon(
          onPressed: () => showDeviceIdentificationDialog(context, device),
          icon: const Icon(Icons.help_outline),
          label: const Text('How to identify'),
        ),
      ];
      destructive = TextButton.icon(
        style: destructiveStyle,
        onPressed: () => confirmDeleteDevice(
          context,
          device,
          onAction,
          onDeleted: () => context.go(Routes.devices),
        ),
        icon: const Icon(Icons.delete_outline),
        label: const Text('Delete'),
      );
    }

    final isWide = MediaQuery.sizeOf(context).width >= Breakpoints.medium;
    if (isWide) {
      return Row(
        children: [
          for (var i = 0; i < leading.length; i++) ...[
            if (i > 0) const SizedBox(width: Insets.md),
            leading[i],
          ],
          const Spacer(),
          destructive,
        ],
      );
    }

    // On narrow phone widths the buttons don't fit on one line, so let them
    // wrap instead of overflowing.
    return Wrap(
      spacing: Insets.md,
      runSpacing: Insets.sm,
      children: [...leading, destructive],
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
      padding: const EdgeInsets.symmetric(
        horizontal: Insets.lg,
        vertical: Insets.md,
      ),
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
          Expanded(
            child: SelectableText(value, style: theme.textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

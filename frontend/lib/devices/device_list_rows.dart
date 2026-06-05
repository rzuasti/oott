import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../model/device.dart';
import '../model/device_type.dart';
import '../theme/app_colors.dart';
import '../utils/friendly_date_formatter.dart';
import '../widgets/status_badge.dart';
import 'device_actions.dart';
import 'device_list_sort.dart';

// Column layout shared between the header and data rows so cells line up.
const double _iconWidth = 40;
const double _trailingWidth = 48;
const Duration _onlineThreshold = Duration(minutes: 10);

class _ColumnSpec {
  final DeviceSortColumn column;
  final int flex;
  const _ColumnSpec(this.column, this.flex);
}

const List<_ColumnSpec> _columnSpecs = [
  _ColumnSpec(DeviceSortColumn.name, 3),
  _ColumnSpec(DeviceSortColumn.owner, 2),
  _ColumnSpec(DeviceSortColumn.macAddress, 3),
  _ColumnSpec(DeviceSortColumn.ipAddress, 2),
  _ColumnSpec(DeviceSortColumn.lastSeen, 3),
  _ColumnSpec(DeviceSortColumn.vendor, 2),
];

String _displayName(Device device) {
  if (device.name != null && device.name!.isNotEmpty) return device.name!;
  if (device.isRegistered && device.owner.isNotEmpty) {
    final type = device.deviceType == DeviceType.unknown
        ? 'Device'
        : device.deviceType.label;
    return "${device.owner}'s $type";
  }
  return '—';
}

class DeviceListHeaderDelegate extends SliverPersistentHeaderDelegate {
  final DeviceSortColumn sortColumn;
  final bool ascending;
  final void Function(DeviceSortColumn column) onTap;

  DeviceListHeaderDelegate({
    required this.sortColumn,
    required this.ascending,
    required this.onTap,
  });

  @override
  double get minExtent => 48;

  @override
  double get maxExtent => 48;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  _IconHeaderCell(
                    active: sortColumn,
                    ascending: ascending,
                    onTap: onTap,
                  ),
                  for (final spec in _columnSpecs)
                    _HeaderCell(
                      flex: spec.flex,
                      column: spec.column,
                      active: sortColumn,
                      ascending: ascending,
                      onTap: onTap,
                    ),
                  const SizedBox(width: _trailingWidth),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant DeviceListHeaderDelegate oldDelegate) {
    return oldDelegate.sortColumn != sortColumn ||
        oldDelegate.ascending != ascending;
  }
}

class _HeaderCell extends StatelessWidget {
  final int flex;
  final DeviceSortColumn column;
  final DeviceSortColumn active;
  final bool ascending;
  final void Function(DeviceSortColumn column) onTap;

  const _HeaderCell({
    required this.flex,
    required this.column,
    required this.active,
    required this.ascending,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isActive = column == active;
    final color = isActive
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurfaceVariant;
    return Expanded(
      flex: flex,
      child: InkWell(
        onTap: () => onTap(column),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Row(
            children: [
              Flexible(
                child: Text(
                  column.label,
                  style: theme.textTheme.labelLarge?.copyWith(color: color),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isActive) ...[
                const SizedBox(width: 4),
                Icon(
                  ascending ? Icons.arrow_upward : Icons.arrow_downward,
                  size: 16,
                  color: color,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// The leading device-type column shows only an icon per row, so its header is a
// compact icon button that sorts by device type rather than a labelled cell.
class _IconHeaderCell extends StatelessWidget {
  final DeviceSortColumn active;
  final bool ascending;
  final void Function(DeviceSortColumn column) onTap;

  const _IconHeaderCell({
    required this.active,
    required this.ascending,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isActive = active == DeviceSortColumn.deviceType;
    final color = isActive
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurfaceVariant;
    return SizedBox(
      width: _iconWidth,
      child: InkWell(
        onTap: () => onTap(DeviceSortColumn.deviceType),
        child: Tooltip(
          message: 'Sort by device type',
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.devices, size: 18, color: color),
                if (isActive)
                  Icon(
                    ascending ? Icons.arrow_upward : Icons.arrow_downward,
                    size: 14,
                    color: color,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class DeviceRowWide extends StatelessWidget {
  final Device device;
  final FriendlyDateFormatter formatter;
  final VoidCallback onRefresh;

  const DeviceRowWide({
    super.key,
    required this.device,
    required this.formatter,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: device.isRegistered ? null : theme.colorScheme.secondaryContainer,
      child: InkWell(
        onTap: () => context.push('/devices/${device.macAddress}'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              SizedBox(
                width: _iconWidth,
                child: Tooltip(
                  message: device.deviceType == DeviceType.unknown
                      ? 'Device type unknown'
                      : device.deviceType.label,
                  child: Icon(device.deviceType.icon),
                ),
              ),
              for (final spec in _columnSpecs)
                Expanded(
                  flex: spec.flex,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 12,
                    ),
                    child: _cellContent(theme, spec.column, device, formatter),
                  ),
                ),
              SizedBox(
                width: _trailingWidth,
                child: _DeviceActionsMenu(
                  device: device,
                  onRefresh: onRefresh,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Widget _cellContent(
  ThemeData theme,
  DeviceSortColumn column,
  Device device,
  FriendlyDateFormatter formatter,
) {
  switch (column) {
    case DeviceSortColumn.deviceType:
      // The device type is shown via the leading icon column, never a text cell.
      return const SizedBox.shrink();
    case DeviceSortColumn.name:
      return _OverflowTooltipText(
        text: _displayName(device),
        style: theme.textTheme.bodyMedium,
      );
    case DeviceSortColumn.owner:
      if (!device.isRegistered) {
        return const Align(
          alignment: Alignment.centerLeft,
          child: StatusBadge(
            label: 'Not registered',
            color: BadgeColor.secondary,
          ),
        );
      }
      return _OverflowTooltipText(
        text: device.owner.isEmpty ? '—' : device.owner,
        style: theme.textTheme.bodyMedium,
      );
    case DeviceSortColumn.macAddress:
      return _OverflowTooltipText(
        text: device.macAddress,
        style: theme.textTheme.bodyMedium?.copyWith(fontFamily: 'monospace'),
      );
    case DeviceSortColumn.ipAddress:
      return _OverflowTooltipText(
        text: device.ipv4Address,
        style: theme.textTheme.bodyMedium?.copyWith(fontFamily: 'monospace'),
      );
    case DeviceSortColumn.lastSeen:
      return Row(
        children: [
          _StatusDot(lastSeen: device.lastSeen),
          const SizedBox(width: 6),
          Flexible(
            child: _OverflowTooltipText(
              text: formatter.format(device.lastSeen),
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      );
    case DeviceSortColumn.vendor:
      return _OverflowTooltipText(
        text: device.vendor.isEmpty ? '—' : device.vendor,
        style: theme.textTheme.bodyMedium,
      );
  }
}

class _OverflowTooltipText extends StatelessWidget {
  final String text;
  final TextStyle? style;

  const _OverflowTooltipText({required this.text, this.style});

  @override
  Widget build(BuildContext context) {
    final effectiveStyle = DefaultTextStyle.of(context).style.merge(style);
    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: text, style: effectiveStyle),
          maxLines: 1,
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout(maxWidth: constraints.maxWidth);
        final child = Text(
          text,
          overflow: TextOverflow.ellipsis,
          style: style,
        );
        return painter.didExceedMaxLines
            ? Tooltip(message: text, child: child)
            : child;
      },
    );
  }
}

class DeviceRowCompact extends StatelessWidget {
  final Device device;
  final FriendlyDateFormatter formatter;
  final VoidCallback onRefresh;

  const DeviceRowCompact({
    super.key,
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
            Flexible(
              child: _OverflowTooltipText(text: _displayName(device)),
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
        subtitle: DefaultTextStyle.merge(
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _OverflowTooltipText(
                text:
                    '${device.isRegistered ? (device.owner.isEmpty ? '—' : device.owner) : device.ipv4Address} · ${device.macAddress}',
              ),
              if (!device.isRegistered && device.vendor.isNotEmpty)
                _OverflowTooltipText(text: device.vendor),
              Row(
                children: [
                  _StatusDot(lastSeen: device.lastSeen),
                  const SizedBox(width: 6),
                  Flexible(
                    child: _OverflowTooltipText(
                      text: 'Last seen: ${formatter.format(device.lastSeen)}',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        isThreeLine: true,
        trailing: _DeviceActionsMenu(device: device, onRefresh: onRefresh),
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  final DateTime lastSeen;

  const _StatusDot({required this.lastSeen});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isOnline = DateTime.now().difference(lastSeen) < _onlineThreshold;
    final color = isOnline
        ? theme.extension<AppColorExtension>()!.success
        : theme.colorScheme.outline;
    return Tooltip(
      message: isOnline ? 'Online' : 'Appears offline',
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}

class _DeviceActionsMenu extends StatelessWidget {
  final Device device;
  final VoidCallback onRefresh;

  const _DeviceActionsMenu({required this.device, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert),
      onSelected: (value) async {
        if (value == 'details') {
          context.push('/devices/${device.macAddress}');
        } else if (value == 'edit') {
          await showEditDeviceDialog(context, device, onRefresh);
        } else if (value == 'forget') {
          await confirmForgetDevice(context, device, onRefresh);
        } else if (value == 'register') {
          await showRegisterDeviceDialog(context, device, onRefresh);
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(value: 'details', child: Text('View details')),
        if (device.isRegistered)
          const PopupMenuItem(value: 'edit', child: Text('Edit')),
        if (device.isRegistered)
          const PopupMenuItem(value: 'forget', child: Text('Forget')),
        if (!device.isRegistered)
          const PopupMenuItem(value: 'register', child: Text('Register')),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import '../theme/dimens.dart';

enum DeviceSortColumn {
  deviceType('Device Type', 'device_type'),
  name('Name', 'name'),
  owner('Owner', 'owner'),
  macAddress('MAC Address', 'mac_address'),
  ipAddress('IP Address', 'ipv4_address'),
  lastSeen('Last Seen', 'last_seen'),
  vendor('Vendor', 'vendor');

  const DeviceSortColumn(this.label, this.apiName);

  final String label;
  final String apiName;
}

class DeviceSortSheet extends StatelessWidget {
  final DeviceSortColumn currentColumn;
  final bool ascending;
  final void Function(DeviceSortColumn column, bool ascending) onChanged;

  const DeviceSortSheet({
    super.key,
    required this.currentColumn,
    required this.ascending,
    required this.onChanged,
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
          Text('Sort by', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: Insets.sm),
          RadioGroup<DeviceSortColumn>(
            groupValue: currentColumn,
            onChanged: (value) {
              if (value != null) {
                onChanged(value, ascending);
                Navigator.of(context).pop();
              }
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final column in DeviceSortColumn.values)
                  RadioListTile<DeviceSortColumn>(
                    title: Text(column.label),
                    value: column,
                  ),
              ],
            ),
          ),
          const SizedBox(height: Insets.sm),
          Center(
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: true,
                  label: Text('Ascending'),
                  icon: Icon(Icons.arrow_upward),
                ),
                ButtonSegment(
                  value: false,
                  label: Text('Descending'),
                  icon: Icon(Icons.arrow_downward),
                ),
              ],
              selected: {ascending},
              onSelectionChanged: (selection) {
                onChanged(currentColumn, selection.first);
                Navigator.of(context).pop();
              },
            ),
          ),
        ],
      ),
    );
  }
}

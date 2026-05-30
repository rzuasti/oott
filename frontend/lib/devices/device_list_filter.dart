import 'package:flutter/material.dart';

import '../model/device_type.dart';

enum DeviceFilter {
  newDevices('Not registered'),
  registered('Registered'),
  all('All');

  const DeviceFilter(this.label);

  final String label;
}

class DeviceFilterSheet extends StatelessWidget {
  final TextEditingController ownerController;
  final DeviceType? typeFilter;
  final bool hasActiveFilters;
  final ValueChanged<DeviceType?> onTypeChanged;
  final VoidCallback onClear;

  const DeviceFilterSheet({
    super.key,
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

import 'package:flutter/material.dart';

import '../model/device.dart';
import '../model/device_type.dart';
import '../utils/oott_api.dart';
import '../utils/ui_snackbars.dart';

Future<void> confirmForgetDevice(
  BuildContext context,
  Device device,
  VoidCallback onRefresh,
) async {
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

  if (confirmed != true || !context.mounted) return;

  try {
    await BackendAPI.instance.forgetDevice(device.macAddress);
    if (!context.mounted) return;
    UISnackbars.showSuccess(context, 'Device forgotten');
    onRefresh();
  } catch (e) {
    if (!context.mounted) return;
    UISnackbars.showError(context, 'Failed to forget device: $e');
  }
}

Future<void> showRegisterDeviceDialog(
  BuildContext context,
  Device device,
  VoidCallback onRefresh,
) async {
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

  if (saved != true || !context.mounted) return;

  try {
    await BackendAPI.instance.registerDevice(
      device.macAddress,
      owner,
      deviceType.name,
    );
    if (!context.mounted) return;
    UISnackbars.showSuccess(context, 'Device registered');
    onRefresh();
  } catch (e) {
    if (!context.mounted) return;
    UISnackbars.showError(context, 'Failed to register device: $e');
  }
}

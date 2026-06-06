import 'package:flutter/material.dart';

import '../model/device.dart';
import '../model/device_type.dart';
import '../utils/oott_api.dart';
import '../utils/ui_snackbars.dart';
import '../theme/dimens.dart';

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
    UISnackbars.showError(
      context,
      'Failed to forget device. ${dioErrorToUserMessage(e)}',
    );
  }
}

Future<void> showEditDeviceDialog(
  BuildContext context,
  Device device,
  VoidCallback onRefresh,
) async {
  final formKey = GlobalKey<FormState>();
  String owner = device.owner;
  String name = device.name ?? '';
  String vendor = device.vendor;
  DeviceType deviceType = device.deviceType;

  final saved = await showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) {
        void save() {
          if (formKey.currentState?.validate() ?? false) {
            formKey.currentState?.save();
            Navigator.of(context).pop(true);
          }
        }

        return AlertDialog(
          title: const Text('Edit Device'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  initialValue: owner,
                  decoration: const InputDecoration(labelText: 'Owner'),
                  autofocus: true,
                  onFieldSubmitted: (_) => save(),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Owner is required'
                      : null,
                  onSaved: (value) => owner = value?.trim() ?? '',
                ),
                const SizedBox(height: Insets.lg),
                TextFormField(
                  initialValue: name,
                  decoration: const InputDecoration(
                    labelText: 'Name (optional)',
                  ),
                  onFieldSubmitted: (_) => save(),
                  onSaved: (value) => name = value?.trim() ?? '',
                ),
                const SizedBox(height: Insets.lg),
                TextFormField(
                  initialValue: vendor,
                  decoration: const InputDecoration(
                    labelText: 'Vendor (optional)',
                  ),
                  onFieldSubmitted: (_) => save(),
                  onSaved: (value) => vendor = value?.trim() ?? '',
                ),
                const SizedBox(height: Insets.lg),
                DropdownButtonFormField<DeviceType>(
                  initialValue: deviceType,
                  decoration: const InputDecoration(labelText: 'Device Type'),
                  items: DeviceType.values
                      .map(
                        (t) => DropdownMenuItem(
                          value: t,
                          child: Row(
                            children: [
                              Icon(t.icon, size: 16),
                              const SizedBox(width: Insets.xs),
                              Text(t.label),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setDialogState(() => deviceType = value ?? deviceType),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(onPressed: save, child: const Text('Save')),
          ],
        );
      },
    ),
  );

  if (saved != true || !context.mounted) return;

  try {
    await BackendAPI.instance.updateDevice(
      device.macAddress,
      owner,
      deviceType.apiName,
      vendor,
      name: name.isEmpty ? null : name,
    );
    if (!context.mounted) return;
    UISnackbars.showSuccess(context, 'Device updated');
    onRefresh();
  } catch (e) {
    if (!context.mounted) return;
    UISnackbars.showError(
      context,
      'Failed to update device. ${dioErrorToUserMessage(e)}',
    );
  }
}

Future<void> showRegisterDeviceDialog(
  BuildContext context,
  Device device,
  VoidCallback onRefresh,
) async {
  final formKey = GlobalKey<FormState>();
  String owner = '';
  String name = device.name ?? '';
  DeviceType deviceType = device.deviceType;

  final saved = await showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) {
        void save() {
          if (formKey.currentState?.validate() ?? false) {
            formKey.currentState?.save();
            Navigator.of(context).pop(true);
          }
        }

        return AlertDialog(
          title: const Text('Register Device'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  decoration: const InputDecoration(labelText: 'Owner'),
                  autofocus: true,
                  onFieldSubmitted: (_) => save(),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Owner is required'
                      : null,
                  onSaved: (value) => owner = value?.trim() ?? '',
                ),
                const SizedBox(height: Insets.lg),
                TextFormField(
                  initialValue: name,
                  decoration: const InputDecoration(
                    labelText: 'Name (optional)',
                  ),
                  onFieldSubmitted: (_) => save(),
                  onSaved: (value) => name = value?.trim() ?? '',
                ),
                const SizedBox(height: Insets.lg),
                DropdownButtonFormField<DeviceType>(
                  initialValue: deviceType,
                  decoration: const InputDecoration(labelText: 'Device Type'),
                  items: DeviceType.values
                      .map(
                        (t) => DropdownMenuItem(
                          value: t,
                          child: Row(
                            children: [
                              Icon(t.icon, size: 16),
                              const SizedBox(width: Insets.xs),
                              Text(t.label),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setDialogState(() => deviceType = value ?? deviceType),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(onPressed: save, child: const Text('Save')),
          ],
        );
      },
    ),
  );

  if (saved != true || !context.mounted) return;

  try {
    await BackendAPI.instance.registerDevice(
      device.macAddress,
      owner,
      deviceType.apiName,
      name: name.isEmpty ? null : name,
    );
    if (!context.mounted) return;
    UISnackbars.showSuccess(context, 'Device registered');
    onRefresh();
  } catch (e) {
    if (!context.mounted) return;
    UISnackbars.showError(
      context,
      'Failed to register device. ${dioErrorToUserMessage(e)}',
    );
  }
}

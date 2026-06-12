import 'package:flutter/material.dart';

import '../model/device.dart';
import '../model/device_type.dart';
import '../utils/oott_api.dart';
import '../utils/ui_snackbars.dart';
import '../theme/dimens.dart';

/// Confirms forgetting (and optionally permanently deleting) a registered
/// device.
///
/// On a successful permanent deletion [onDeleted] is invoked when provided
/// (e.g. to navigate away from a now-stale detail page); otherwise [onRefresh]
/// is used. A plain unregister always calls [onRefresh].
Future<void> confirmForgetDevice(
  BuildContext context,
  Device device,
  VoidCallback onRefresh, {
  VoidCallback? onDeleted,
}) async {
  final colorScheme = Theme.of(context).colorScheme;
  bool alsoDelete = false;

  final action = await showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: const Text('Forget Device'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This device will be unregistered and will no longer be linked '
              'to ${device.owner}. Are you sure?',
            ),
            const SizedBox(height: Insets.md),
            CheckboxListTile(
              value: alsoDelete,
              onChanged: (value) =>
                  setDialogState(() => alsoDelete = value ?? false),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text('Permanently delete this device'),
            ),
            if (alsoDelete) const _PermanentDeletionWarning(),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: colorScheme.error),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(alsoDelete ? 'Delete' : 'Forget'),
          ),
        ],
      ),
    ),
  );

  if (action != true || !context.mounted) return;

  try {
    if (alsoDelete) {
      await BackendAPI.instance.deleteDevice(device.macAddress);
      if (!context.mounted) return;
      UISnackbars.showSuccess(context, 'Device deleted');
      (onDeleted ?? onRefresh)();
    } else {
      await BackendAPI.instance.forgetDevice(device.macAddress);
      if (!context.mounted) return;
      UISnackbars.showSuccess(context, 'Device forgotten');
      onRefresh();
    }
  } catch (e) {
    if (!context.mounted) return;
    UISnackbars.showError(
      context,
      alsoDelete
          ? 'Failed to delete device. ${dioErrorToUserMessage(e)}'
          : 'Failed to forget device. ${dioErrorToUserMessage(e)}',
    );
  }
}

/// Confirms and performs the permanent deletion of a not-registered device,
/// erasing the device record and all of its event history.
///
/// On success [onDeleted] is invoked when provided (e.g. to navigate away from
/// a now-stale detail page); otherwise [onRefresh] is used.
Future<void> confirmDeleteDevice(
  BuildContext context,
  Device device,
  VoidCallback onRefresh, {
  VoidCallback? onDeleted,
}) async {
  final colorScheme = Theme.of(context).colorScheme;

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Delete Device'),
      content: const Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Are you sure you want to delete this device?'),
          SizedBox(height: Insets.md),
          _PermanentDeletionWarning(),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          style: TextButton.styleFrom(foregroundColor: colorScheme.error),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );

  if (confirmed != true || !context.mounted) return;

  try {
    await BackendAPI.instance.deleteDevice(device.macAddress);
    if (!context.mounted) return;
    UISnackbars.showSuccess(context, 'Device deleted');
    (onDeleted ?? onRefresh)();
  } catch (e) {
    if (!context.mounted) return;
    UISnackbars.showError(
      context,
      'Failed to delete device. ${dioErrorToUserMessage(e)}',
    );
  }
}

/// Embedded warning shown when a permanent deletion is about to happen.
class _PermanentDeletionWarning extends StatelessWidget {
  const _PermanentDeletionWarning();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(Insets.md),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(Insets.sm),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber, color: colorScheme.onErrorContainer),
          const SizedBox(width: Insets.sm),
          Expanded(
            child: Text(
              'This permanently erases the device and its entire event '
              'history. This action cannot be undone.',
              style: TextStyle(color: colorScheme.onErrorContainer),
            ),
          ),
        ],
      ),
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
            FilledButton(onPressed: save, child: const Text('Save')),
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
            FilledButton(onPressed: save, child: const Text('Register')),
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

import 'package:encrypter/encrypter/xor.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../theme/dimens.dart';
import '../utils/oott_api.dart';
import '../utils/pref_utils.dart';
import '../utils/push_service.dart';
import '../utils/ui_snackbars.dart';
import 'backend_config_dialog.dart';

class Settings extends StatefulWidget {
  const Settings({super.key, this.pushService});

  /// Injectable so widget tests can supply a fake; defaults to the real
  /// FCM-backed service.
  final PushService? pushService;

  @override
  State<Settings> createState() => _SettingsState();
}

class _SettingsState extends State<Settings> {
  String _baseUrl = '';
  String _apiKey = '';
  bool _apiKeyVisible = false;
  bool _isFirstRun = false;
  late String _selectedTheme;
  late final PushService _pushService;
  bool _pushEnabled = false;
  bool _pushBusy = false;
  bool _testBusy = false;
  // Whether the backend delivers notifications via push. The per-device push
  // toggle only makes sense then, so it stays hidden until this is confirmed.
  bool _pushMethodActive = false;

  @override
  void initState() {
    super.initState();
    _readConnectionFromPrefs();
    _isFirstRun = _baseUrl.isEmpty;
    _selectedTheme = context.read<AppState>().themeKey;
    _pushService = widget.pushService ?? FirebasePushService();
    _pushEnabled = pushEnabledOnThisDevice;
    _loadConfig();
    // First run / unconfigured: open the connection dialog immediately and keep
    // it open (non-dismissible) until the user saves a working configuration.
    if (_isFirstRun) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openConfigDialog(dismissible: false);
      });
    }
  }

  void _readConnectionFromPrefs() {
    _baseUrl = PrefUtil.getValue('base_url', '') as String;
    _apiKey = XOR().xorDecode(PrefUtil.getValue('api_key', '') as String);
  }

  // Learn the backend's notification method so the push toggle is only shown
  // when the backend actually delivers via push. Failures (e.g. the backend is
  // unreachable, as on first run) just leave the toggle hidden.
  Future<void> _loadConfig() async {
    try {
      final config = await BackendAPI.instance.getConfig();
      if (!mounted) return;
      setState(() => _pushMethodActive = config.notificationMethod == 'push');
    } catch (e) {
      debugPrint('Failed to load backend config: $e');
    }
  }

  // Opens the backend connection dialog and, on save, refreshes the screen with
  // the new connection details and re-reads the backend config.
  Future<void> _openConfigDialog({bool dismissible = true}) async {
    final saved = await showBackendConfigDialog(
      context,
      dismissible: dismissible,
    );
    if (!mounted || !saved) return;
    setState(() {
      _isFirstRun = false;
      _readConnectionFromPrefs();
    });
    _loadConfig();
  }

  // Enable or disable push on this specific device. The toggle reflects user
  // intent (persisted), but enabling can still fail if the OS permission is
  // declined, in which case the switch falls back to off.
  Future<void> _togglePush(bool value) async {
    setState(() => _pushBusy = true);
    try {
      if (value) {
        final enabled = await _pushService.enable();
        if (!mounted) return;
        if (enabled) {
          await setPushEnabledOnThisDevice(enabled: true);
          if (!mounted) return;
          setState(() => _pushEnabled = true);
          UISnackbars.showSuccess(
            context,
            'Push notifications enabled on this device',
          );
        } else {
          setState(() => _pushEnabled = false);
          // On iOS, surface the native APNs registration reason (if any) so the
          // failure can be diagnosed without a Mac to read the device console.
          final apnsStatus = await apnsRegistrationStatus();
          if (!mounted) return;
          UISnackbars.showError(
            context,
            apnsStatus != null
                ? 'Could not enable push. $apnsStatus'
                : 'Could not enable push. Check notification permission for '
                      'OOTT.',
          );
        }
      } else {
        await _pushService.disable();
        if (!mounted) return;
        await setPushEnabledOnThisDevice(enabled: false);
        if (!mounted) return;
        setState(() => _pushEnabled = false);
        UISnackbars.showSuccess(
          context,
          'Push notifications disabled on this device',
        );
      }
    } catch (e) {
      debugPrint('Failed to update push settings: $e');
      if (!mounted) return;
      UISnackbars.showError(context, 'Failed to update push settings');
    } finally {
      if (mounted) setState(() => _pushBusy = false);
    }
  }

  // Ask the backend to deliver a test push to every registered device, so the
  // user can confirm push is working end to end without waiting for a real
  // device event.
  Future<void> _sendTestNotification() async {
    setState(() => _testBusy = true);
    try {
      final delivered = await BackendAPI.instance.sendTestNotification();
      if (!mounted) return;
      if (delivered == 0) {
        // The request succeeded but no device received it — usually the backend
        // lost this device's token (e.g. after a restart); re-toggle to re-register.
        UISnackbars.showError(
          context,
          'No devices are registered to receive push notifications.',
        );
      } else {
        final devices = delivered == 1 ? 'device' : 'devices';
        UISnackbars.showSuccess(
          context,
          'Test notification sent to $delivered $devices.',
        );
      }
    } catch (e) {
      debugPrint('Failed to send test notification: $e');
      if (!mounted) return;
      UISnackbars.showError(context, 'Failed to send test notification');
    } finally {
      if (mounted) setState(() => _testBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildConnectionSummary(context),
          const SizedBox(height: Insets.lg),
          _buildAppSettings(context),
        ],
      ),
    );
  }

  // Read-only summary of the backend connection with a link to reconfigure it.
  Widget _buildConnectionSummary(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final configured = _baseUrl.isNotEmpty;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Insets.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Backend connection',
                    style: textTheme.titleLarge,
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _openConfigDialog(),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Re-configure'),
                ),
              ],
            ),
            const SizedBox(height: Insets.sm),
            _buildReadOnlyField(
              context,
              label: 'Base URL',
              value: configured ? _baseUrl : 'Not configured yet',
            ),
            const SizedBox(height: Insets.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: _buildReadOnlyField(
                    context,
                    label: 'API key',
                    value: !configured
                        ? 'Not configured yet'
                        : (_apiKeyVisible ? _apiKey : '••••••••'),
                  ),
                ),
                if (configured)
                  IconButton(
                    icon: Icon(
                      _apiKeyVisible ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () =>
                        setState(() => _apiKeyVisible = !_apiKeyVisible),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // App-level preferences (theme, per-device push) that apply immediately.
  Widget _buildAppSettings(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Insets.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('App settings', style: textTheme.titleLarge),
            const SizedBox(height: Insets.md),
            DropdownButtonFormField<String>(
              initialValue: _selectedTheme,
              decoration: const InputDecoration(
                border: UnderlineInputBorder(),
                labelText: 'Theme',
              ),
              items: const [
                DropdownMenuItem(value: 'alucard', child: Text('Alucard')),
                DropdownMenuItem(
                  value: 'catppuccin_latte',
                  child: Text('Catppuccin Latte'),
                ),
                DropdownMenuItem(
                  value: 'catppuccin_mocha',
                  child: Text('Catppuccin Mocha'),
                ),
                DropdownMenuItem(value: 'dracula', child: Text('Dracula')),
                DropdownMenuItem(
                  value: 'gruvbox_dark',
                  child: Text('Gruvbox Dark'),
                ),
                DropdownMenuItem(value: 'nord', child: Text('Nord')),
                DropdownMenuItem(
                  value: 'tokyo_night',
                  child: Text('Tokyo Night'),
                ),
              ],
              // Applies immediately; the theme persists itself, no Save needed.
              onChanged: (value) {
                if (value == null) return;
                setState(() => _selectedTheme = value);
                context.read<AppState>().setTheme(value);
              },
            ),
            if (_pushService.isSupported && _pushMethodActive) ...[
              const SizedBox(height: Insets.sm),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Push notifications on this device'),
                subtitle: const Text(
                  'Receive alerts on this device even when the app is closed.',
                ),
                value: _pushEnabled,
                onChanged: _pushBusy ? null : _togglePush,
              ),
              // Only useful once push is on for this device; sends a test push
              // through the full backend → relay → device path.
              if (_pushEnabled)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _testBusy ? null : _sendTestNotification,
                    icon: const Icon(Icons.notifications_active_outlined),
                    label: const Text('Send test notification'),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildReadOnlyField(
    BuildContext context, {
    required String label,
    required String value,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: Insets.xs),
        Text(value, style: textTheme.bodyLarge),
      ],
    );
  }
}

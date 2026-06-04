import 'package:encrypter/encrypter/xor.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../theme/app_colors.dart';
import '../theme/dimens.dart';
import '../utils/oott_api.dart';
import '../utils/pref_utils.dart';
import '../utils/ui_snackbars.dart';

class Settings extends StatefulWidget {
  const Settings({super.key});

  @override
  State<Settings> createState() => _SettingsState();
}

class _SettingsState extends State<Settings> {
  final _baseUrlController = TextEditingController();
  final _apiKeyController = TextEditingController();
  bool _apiKeyVisible = false;
  bool _testOk = false;
  bool _connectionModified = false;
  bool _isFirstRun = false;
  late String _selectedTheme;

  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _isFirstRun = (PrefUtil.getValue('base_url', '') as String).isEmpty;
    _baseUrlController.text = PrefUtil.getValue('base_url', '') as String;
    _apiKeyController.text = XOR().xorDecode(
      PrefUtil.getValue('api_key', '') as String,
    );
    _selectedTheme = context.read<AppState>().themeKey;
  }

  @override
  void dispose() {
    _baseUrlController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  void _onConnectionChanged(String _) {
    setState(() {
      _testOk = false;
      _connectionModified = true;
    });
  }

  Future<void> _testConnection() async {
    if (!_formKey.currentState!.validate()) return;
    final result = await BackendAPI.test(
      _baseUrlController.text,
      _apiKeyController.text,
    );
    if (!mounted) return;
    setState(() {
      _testOk = result == null;
      if (result == null) _connectionModified = false;
    });
    if (result == null) {
      UISnackbars.showSuccess(context, 'It works!');
    } else {
      UISnackbars.showError(context, result);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    try {
      final urlOk = await PrefUtil.setValue(
        'base_url',
        _baseUrlController.text,
      );
      if (!mounted) return;
      final keyOk = await PrefUtil.setValue(
        'api_key',
        XOR().xorEncode(_apiKeyController.text),
      );
      if (!mounted) return;
      final themeOk = await context.read<AppState>().setTheme(_selectedTheme);
      if (!mounted) return;
      if (urlOk && keyOk && themeOk) {
        BackendAPI.instance.reconfigureFromPrefs();
        UISnackbars.showSuccess(context, 'Settings saved successfully');
      } else {
        UISnackbars.showError(context, 'Failed to save settings');
      }
    } catch (e) {
      debugPrint('Failed to save settings: $e');
      if (!mounted) return;
      UISnackbars.showError(context, 'Failed to save settings');
    }
  }

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColorExtension>()!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final saveDisabled = _connectionModified && !_testOk;

    return SingleChildScrollView(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_isFirstRun) ...[
              Card(
                color: colorScheme.secondaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(Insets.lg),
                  child: Row(
                    children: [
                      Icon(
                        Icons.waving_hand_outlined,
                        color: colorScheme.onSecondaryContainer,
                      ),
                      const SizedBox(width: Insets.md),
                      Expanded(
                        child: Text(
                          'Welcome to OOTT! Point the app at your server’s API '
                          'below, then Test and Save to get started.',
                          style: textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSecondaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: Insets.lg),
            ],
            TextFormField(
              controller: _baseUrlController,
              onChanged: _onConnectionChanged,
              validator: (value) => value == null || value.isEmpty
                  ? 'The URL cannot be empty'
                  : null,
              decoration: const InputDecoration(
                border: UnderlineInputBorder(),
                labelText: "Base URL of your OOTT server's API",
                hintText: 'For example http://192.168.0.1:3000/api',
              ),
            ),
            const SizedBox(height: Insets.lg),
            TextFormField(
              controller: _apiKeyController,
              onChanged: _onConnectionChanged,
              validator: (value) => value == null || value.isEmpty
                  ? 'The API key cannot be empty'
                  : null,
              obscureText: !_apiKeyVisible,
              decoration: InputDecoration(
                border: const UnderlineInputBorder(),
                labelText: 'API key',
                suffixIcon: IconButton(
                  icon: Icon(
                    _apiKeyVisible ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: () =>
                      setState(() => _apiKeyVisible = !_apiKeyVisible),
                ),
              ),
            ),
            const SizedBox(height: Insets.lg),
            DropdownButtonFormField<String>(
              initialValue: _selectedTheme,
              decoration: const InputDecoration(
                border: UnderlineInputBorder(),
                labelText: 'Theme',
              ),
              items: const [
                DropdownMenuItem(
                  value: 'catppuccin_mocha',
                  child: Text('Catppuccin Mocha'),
                ),
                DropdownMenuItem(
                  value: 'gruvbox_dark',
                  child: Text('Gruvbox Dark'),
                ),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _selectedTheme = value);
              },
            ),
            const SizedBox(height: Insets.lg),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                FilledButton.icon(
                  onPressed: () {
                    _testConnection();
                  },
                  label: const Text('Test'),
                  icon: Icon(_testOk ? Icons.check : Icons.play_arrow),
                  style: FilledButton.styleFrom(
                    backgroundColor: _testOk
                        ? appColors.success
                        : colorScheme.secondary,
                    foregroundColor: _testOk
                        ? appColors.onSuccess
                        : colorScheme.onSecondary,
                  ),
                ),
                const SizedBox(width: Insets.sm),
                FilledButton.icon(
                  onPressed: saveDisabled ? null : _save,
                  label: const Text('Save'),
                  icon: const Icon(Icons.save),
                ),
              ],
            ),
            if (saveDisabled) ...[
              const SizedBox(height: Insets.sm),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'Test the connection before saving your changes.',
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

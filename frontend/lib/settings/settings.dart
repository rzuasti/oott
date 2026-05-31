import 'package:encrypter/encrypter/xor.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../theme/app_colors.dart';
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
  late String _selectedTheme;

  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
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

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    PrefUtil.setValue('base_url', _baseUrlController.text);
    PrefUtil.setValue('api_key', XOR().xorEncode(_apiKeyController.text));
    BackendAPI.instance.reconfigureFromPrefs();
    context.read<AppState>().setTheme(_selectedTheme);
    UISnackbars.showSuccess(context, 'Settings saved successfully');
  }

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColorExtension>()!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return SingleChildScrollView(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Settings', style: textTheme.headlineSmall),
            const SizedBox(height: 16),
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
            const SizedBox(height: 16),
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
            const SizedBox(height: 16),
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
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    _testConnection();
                  },
                  label: const Text('Test'),
                  icon: Icon(_testOk ? Icons.check : Icons.play_arrow),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _testOk
                        ? appColors.success
                        : colorScheme.secondary,
                    foregroundColor: _testOk
                        ? appColors.onSuccess
                        : colorScheme.onSecondary,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: (_connectionModified && !_testOk) ? null : _save,
                  label: const Text('Save'),
                  icon: const Icon(Icons.save),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

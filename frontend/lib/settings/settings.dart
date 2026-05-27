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
  _SettingsState createState() => _SettingsState();
}

class _SettingsState extends State<Settings> {
  bool _isLoading = true;
  bool _isSaving = false;
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
    _getData();
  }

  @override
  void dispose() {
    _baseUrlController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  void _getData() async {
    _baseUrlController.text = PrefUtil.getValue("base_url", "") as String;
    _apiKeyController.text = XOR().xorDecode(
      PrefUtil.getValue("api_key", "") as String,
    );
    _selectedTheme = context.read<AppState>().themeKey;
    _isLoading = false;
    setState(() {});
  }

  void _saveData() {
    PrefUtil.setValue("base_url", _baseUrlController.text);
    PrefUtil.setValue("api_key", XOR().xorEncode(_apiKeyController.text));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: Column(
                children: <Widget>[
                  SizedBox(height: 16),
                  // Base URL
                  TextFormField(
                    controller: _baseUrlController,
                    onChanged: (text) {
                      setState(() {
                        _testOk = false;
                        _connectionModified = true;
                      });
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return "The URL cannot be empty";
                      }
                      return null;
                    },
                    decoration: const InputDecoration(
                      border: UnderlineInputBorder(),
                      labelText: 'Base URL of your OOTT server\'s API',
                      hintText: "For example http://192.168.0.1:3000/api",
                    ),
                  ),
                  SizedBox(height: 16),
                  // API Key
                  TextFormField(
                    controller: _apiKeyController,
                    onChanged: (text) {
                      setState(() {
                        _testOk = false;
                        _connectionModified = true;
                      });
                    },

                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return "The API key cannot be empty";
                      }
                      return null;
                    },
                    obscureText: !_apiKeyVisible,
                    decoration: InputDecoration(
                      border: UnderlineInputBorder(),
                      labelText: 'API key',
                      suffixIcon: IconButton(
                        icon: Icon(
                          _apiKeyVisible
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: () {
                          setState(() {
                            _apiKeyVisible = !_apiKeyVisible;
                          });
                        },
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                  // Theme selector
                  DropdownButtonFormField<String>(
                    value: _selectedTheme,
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
                      if (value != null) {
                        setState(() {
                          _selectedTheme = value;
                        });
                      }
                    },
                  ),
                  SizedBox(height: 16),
                  // Button row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // Test button
                      ElevatedButton.icon(
                        onPressed: () async {
                          if (_formKey.currentState!.validate()) {
                            String? testResult = await BackendAPI.test(
                              _baseUrlController.text,
                              _apiKeyController.text,
                            );

                            setState(() {
                              _testOk = testResult == null;
                              if (testResult == null)
                                _connectionModified = false;
                            });

                            if (testResult == null) {
                              UISnackbars.showSuccess(context, 'It works!');
                            } else {
                              UISnackbars.showError(context, testResult);
                            }
                          }
                        },
                        label: Text('Test'),
                        icon: _testOk
                            ? Icon(Icons.check)
                            : Icon(Icons.play_arrow),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _testOk
                              ? Theme.of(
                                  context,
                                ).extension<AppColorExtension>()!.success
                              : Theme.of(context).colorScheme.secondary,
                          foregroundColor: _testOk
                              ? Theme.of(
                                  context,
                                ).extension<AppColorExtension>()!.onSuccess
                              : Theme.of(context).colorScheme.onSecondary,
                        ),
                      ),
                      SizedBox(width: 8),

                      // Save button
                      ElevatedButton.icon(
                        onPressed:
                            ((_connectionModified && !_testOk) || _isSaving)
                            ? null
                            : () async {
                                if (_formKey.currentState!.validate()) {
                                  setState(() {
                                    _isSaving = true;
                                  });
                                  _saveData();
                                  context.read<AppState>().setTheme(
                                    _selectedTheme,
                                  );

                                  setState(() {
                                    _isSaving = false;
                                  });
                                  UISnackbars.showSuccess(
                                    context,
                                    'Settings saved successfully',
                                  );
                                }
                              },
                        label: Text(_isSaving ? 'Saving...' : 'Save'),

                        icon: _isSaving ? null : Icon(Icons.save),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primary,
                          foregroundColor: Theme.of(
                            context,
                          ).colorScheme.onPrimary,
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

import 'package:encrypter/encrypter/xor.dart';
import 'package:flutter/material.dart';
import '../utils/oott_api.dart';
import '../utils/pref_utils.dart';

class Settings extends StatefulWidget {
  @override
  _SettingsState createState() => _SettingsState();
}

class _SettingsState extends State<Settings> {
  bool _isLoading = true;
  final _baseUrlController = TextEditingController();
  final _apiKeyController = TextEditingController();
  bool _apiKeyVisible = false;
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
    _isLoading = false;
    setState(() {});
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
                  TextFormField(
                    controller: _baseUrlController,
                    decoration: const InputDecoration(
                      border: UnderlineInputBorder(),
                      labelText: 'Base URL of your OOTT server\'s API',
                      hintText: "For example http://192.168.0.1:3000/api",
                    ),
                  ),
                  SizedBox(height: 16),
                  TextFormField(
                    controller: _apiKeyController,
                    obscureText: !_apiKeyVisible,
                    decoration: InputDecoration(
                      border: UnderlineInputBorder(),
                      labelText: 'API Key',
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
                  ElevatedButton.icon(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) {
                          return AlertDialog(
                            content: Text(
                              _baseUrlController.text +
                                  ' - ' +
                                  _apiKeyController.text,
                            ),
                          );
                        },
                      );
                    },
                    label: Text('Test'),
                    icon: const Icon(Icons.check),
                  ),
                ],
              ),
            ),
    );
  }
}

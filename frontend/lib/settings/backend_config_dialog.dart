import 'package:encrypter/encrypter/xor.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/dimens.dart';
import '../utils/oott_api.dart';
import '../utils/pref_utils.dart';
import '../utils/ui_snackbars.dart';

/// Shows the backend connection dialog (URL + API key) with a Test + Save flow.
///
/// Prefills from the stored configuration so reconfiguring starts from the
/// current values. Returns `true` when the user saved a new configuration and
/// `false` when dismissed.
///
/// On first run the backend is not configured yet; pass [dismissible] as
/// `false` so the user cannot close the dialog (no Cancel, no barrier or
/// back-gesture dismiss) until a configuration is saved.
Future<bool> showBackendConfigDialog(
  BuildContext context, {
  bool dismissible = true,
}) async {
  final saved = await showDialog<bool>(
    context: context,
    barrierDismissible: dismissible,
    builder: (_) => _BackendConfigDialog(dismissible: dismissible),
  );

  if (saved == true && context.mounted) {
    UISnackbars.showSuccess(context, 'Settings saved successfully');
  }
  return saved ?? false;
}

class _BackendConfigDialog extends StatefulWidget {
  const _BackendConfigDialog({required this.dismissible});

  final bool dismissible;

  @override
  State<_BackendConfigDialog> createState() => _BackendConfigDialogState();
}

class _BackendConfigDialogState extends State<_BackendConfigDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _baseUrlController;
  late final TextEditingController _apiKeyController;
  bool _apiKeyVisible = false;
  bool _testOk = false;
  // Whether the connection details changed since the last successful test. The
  // prefilled config starts unmodified so it can be re-saved without retesting,
  // but any edit re-gates Save behind a fresh Test.
  bool _connectionModified = false;

  @override
  void initState() {
    super.initState();
    _baseUrlController = TextEditingController(
      text: PrefUtil.getValue('base_url', '') as String,
    );
    _apiKeyController = TextEditingController(
      text: XOR().xorDecode(PrefUtil.getValue('api_key', '') as String),
    );
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
    bool ok;
    try {
      final urlOk = await PrefUtil.setValue(
        'base_url',
        _baseUrlController.text,
      );
      final keyOk = await PrefUtil.setValue(
        'api_key',
        XOR().xorEncode(_apiKeyController.text),
      );
      ok = urlOk && keyOk;
    } catch (e) {
      debugPrint('Failed to save backend configuration: $e');
      ok = false;
    }
    if (!mounted) return;
    if (ok) {
      BackendAPI.instance.reconfigureFromPrefs();
      Navigator.of(context).pop(true);
    } else {
      UISnackbars.showError(context, 'Failed to save settings');
    }
  }

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColorExtension>()!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final saveDisabled = _connectionModified && !_testOk;

    return PopScope(
      canPop: widget.dismissible,
      child: AlertDialog(
        title: const Text('Backend configuration'),
        content: SizedBox(
          width: 420,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                        _apiKeyVisible
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () =>
                          setState(() => _apiKeyVisible = !_apiKeyVisible),
                    ),
                  ),
                ),
                if (saveDisabled) ...[
                  const SizedBox(height: Insets.sm),
                  Text(
                    'Test the connection before saving your changes.',
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        // Test is a neutral utility action, so per Material 3 it sits on the
        // left, separated from the dismiss/confirm pair (Cancel, Save) which
        // stays grouped at the trailing edge with the confirming action last.
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          FilledButton.icon(
            onPressed: _testConnection,
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
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.dismissible) ...[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: Insets.sm),
              ],
              FilledButton.icon(
                onPressed: saveDisabled ? null : _save,
                label: const Text('Save'),
                icon: const Icon(Icons.save),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

import 'dart:async';

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
  // Briefly true after a failed test so the Test button flashes red as a clear,
  // glanceable failure cue (the error snackbar can be missed). Cleared by the
  // timer below, by editing a field, or by a successful test.
  bool _testFailed = false;
  Timer? _failFlashTimer;
  static const _failFlashDuration = Duration(milliseconds: 1500);
  // Reference width for the dialog body and the actions row. The actions row is
  // measured at this width so the FittedBox can scale the whole row down on
  // narrower screens.
  static const _dialogContentWidth = 420.0;

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
    _failFlashTimer?.cancel();
    _baseUrlController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  void _onConnectionChanged(String _) {
    _failFlashTimer?.cancel();
    setState(() {
      _testOk = false;
      _testFailed = false;
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
    final ok = result == null;
    _failFlashTimer?.cancel();
    setState(() {
      _testOk = ok;
      _testFailed = !ok;
      if (ok) _connectionModified = false;
    });
    if (ok) {
      UISnackbars.showSuccess(context, 'It works!');
    } else {
      // Revert the red flash after a visible beat; the button returns to its
      // default look so the user can retry.
      _failFlashTimer = Timer(_failFlashDuration, () {
        if (mounted) setState(() => _testFailed = false);
      });
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
          width: _dialogContentWidth,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // First run: the connection isn't configured yet, so greet the
                // user and make clear OOTT relies on a backend running in their
                // network.
                if (!widget.dismissible) ...[
                  Card(
                    color: colorScheme.secondaryContainer,
                    margin: EdgeInsets.zero,
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
                              'Welcome to OOTT! Point the app at your server’s '
                              'API to get started. OOTT cannot function without '
                              'a backend installed in your network.',
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
        // It is a filled-tonal (medium emphasis) button so Save remains the
        // single high-emphasis (filled) action in the dialog; once the test
        // succeeds it recolours to the success accent.
        //
        // Handing the dialog's default OverflowBar three icon buttons makes it
        // stack them onto two lines on narrow phones once their combined width
        // exceeds the dialog width. Instead we lay them out in a single Row at
        // the dialog's content width and wrap it in a FittedBox(scaleDown): on
        // wider screens it renders at full size with the spread intact, and on
        // a too-narrow phone the whole row scales down uniformly to fit rather
        // than wrapping or overflowing.
        actions: [
          SizedBox(
            width: double.infinity,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: SizedBox(
                width: _dialogContentWidth,
                child: Row(
                  children: [
                    FilledButton.tonalIcon(
                      onPressed: _testConnection,
                      label: const Text('Test'),
                      icon: Icon(
                        _testOk
                            ? Icons.check
                            : _testFailed
                            ? Icons.error_outline
                            : Icons.play_arrow,
                      ),
                      style: _testOk
                          ? FilledButton.styleFrom(
                              backgroundColor: appColors.success,
                              foregroundColor: appColors.onSuccess,
                            )
                          : _testFailed
                          ? FilledButton.styleFrom(
                              backgroundColor: colorScheme.error,
                              foregroundColor: colorScheme.onError,
                            )
                          : null,
                    ),
                    const Spacer(),
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
              ),
            ),
          ),
        ],
      ),
    );
  }
}

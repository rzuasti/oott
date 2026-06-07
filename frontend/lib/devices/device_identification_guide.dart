import 'package:flutter/material.dart';

import '../model/device.dart';
import '../model/device_type.dart';
import '../theme/dimens.dart';

/// Opens a dialog that helps the user work out which physical device on their
/// network an unregistered entry corresponds to.
Future<void> showDeviceIdentificationDialog(
  BuildContext context,
  Device device,
) {
  return showDialog<void>(
    context: context,
    builder: (context) => _IdentificationDialog(device: device),
  );
}

class _IdentificationDialog extends StatelessWidget {
  final Device device;

  const _IdentificationDialog({required this.device});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final steps = _buildSteps();

    return AlertDialog(
      title: const Text('Identify this device'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_intro(), style: theme.textTheme.bodyMedium),
              const SizedBox(height: Insets.lg),
              for (var i = 0; i < steps.length; i++) ...[
                _GuideStep(step: steps[i]),
                if (i < steps.length - 1) const SizedBox(height: Insets.lg),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }

  /// A short, personalised sentence framing whatever clues OOTT already has.
  String _intro() {
    final hasVendor = device.vendor.isNotEmpty;
    final hasType = device.deviceType != DeviceType.unknown;

    if (hasVendor && hasType) {
      return 'OOTT thinks this is a ${device.deviceType.label} with networking '
          'hardware from ${device.vendor}. Use that as a starting clue, then '
          'narrow it down with the steps below.';
    }
    if (hasVendor) {
      return 'OOTT detected networking hardware from ${device.vendor}. Use '
          'that as a starting clue, then narrow it down with the steps below.';
    }
    if (hasType) {
      return 'OOTT thinks this is a ${device.deviceType.label}. Use that as a '
          'starting clue, then narrow it down with the steps below.';
    }
    return "OOTT couldn't infer the vendor or type for this device, but the "
        'steps below can still help you track it down.';
  }

  List<_Step> _buildSteps() {
    return [
      if (device.vendor.isNotEmpty)
        _Step(
          icon: Icons.memory,
          title: 'Check the manufacturer',
          body:
              'The vendor (${device.vendor}) comes from the MAC address and '
              'identifies who made the network chip — often a different company '
              'than the brand on the product. Searching for their products can '
              'hint at what this is.',
        ),
      const _Step(
        icon: Icons.power_settings_new,
        title: 'Try the unplug test',
        body:
            'Power off or unplug a device you suspect, wait a minute, then '
            'reopen this page. If its "Last Seen" time stops updating, you have '
            'found it.',
      ),
      _Step(
        icon: Icons.router,
        title: 'Check your router',
        body:
            'Sign in to your router (often http://192.168.1.1) and open its '
            'list of connected devices. Match this MAC address '
            '(${device.macAddress}) or IP address (${device.ipv4Address}) to '
            'see the name your router has for it.',
      ),
      _Step(
        icon: Icons.travel_explore,
        title: 'Scan its open ports (advanced)',
        body:
            'From a computer on the same network, run a port scan such as '
            '"nmap ${device.ipv4Address}". The services it exposes can reveal '
            'its role — for example a web page often means a camera, NAS or '
            'printer.',
      ),
    ];
  }
}

/// One identification method: an icon, a heading and an explanation.
class _Step {
  final IconData icon;
  final String title;
  final String body;

  const _Step({required this.icon, required this.title, required this.body});
}

class _GuideStep extends StatelessWidget {
  final _Step step;

  const _GuideStep({required this.step});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(step.icon, color: theme.colorScheme.primary),
        const SizedBox(width: Insets.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(step.title, style: theme.textTheme.titleSmall),
              const SizedBox(height: Insets.xs),
              // Selectable so users can copy the MAC/IP straight out of a step.
              SelectableText(step.body, style: theme.textTheme.bodyMedium),
            ],
          ),
        ),
      ],
    );
  }
}

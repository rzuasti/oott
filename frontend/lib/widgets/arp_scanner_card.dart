import 'package:flutter/material.dart';

import '../model/arp_scanner_status.dart';
import '../theme/app_colors.dart';
import '../utils/duration_formatter.dart';
import '../utils/oott_api.dart';
import 'scanner_status_card.dart';

class ArpScannerCard extends StatelessWidget {
  const ArpScannerCard({super.key});

  @override
  Widget build(BuildContext context) {
    return ScannerStatusCard<ArpScannerStatus>(
      title: 'ARP Scanner',
      fetch: ({cancelToken}) =>
          BackendAPI.instance.getArpScannerStatus(cancelToken: cancelToken),
      resolver: _resolve,
    );
  }

  static ScannerStatus _resolve(
    BuildContext context,
    ArpScannerStatus status,
    double elapsed,
  ) {
    final successColor = Theme.of(
      context,
    ).extension<AppColorExtension>()!.success;
    final neutralColor = Theme.of(context).colorScheme.outline;
    final lastScan = status.lastScanDevicesSeen != null
        ? '${status.lastScanDevicesSeen} devices on last scan'
        : null;
    if (status.isRunning) {
      final sublabels = <String>[
        if (status.runningForSeconds != null)
          'Running for ${formatSeconds(status.runningForSeconds! + elapsed)}',
        ?lastScan,
      ];
      return (color: successColor, label: 'Running', sublabels: sublabels);
    }
    if (status.nextRunInSeconds != null) {
      final remaining = (status.nextRunInSeconds! - elapsed).clamp(
        0.0,
        double.infinity,
      );
      return (
        color: neutralColor,
        label: 'Waiting for next run',
        sublabels: ['Next run in ${formatSeconds(remaining)}', ?lastScan],
      );
    }
    return (color: neutralColor, label: 'Not started', sublabels: []);
  }
}

import 'package:flutter/material.dart';

import '../model/snmp_scanner_status.dart';
import '../theme/app_colors.dart';
import '../utils/duration_formatter.dart';
import '../utils/oott_api.dart';
import 'scanner_status_card.dart';

class SnmpScannerCard extends StatelessWidget {
  const SnmpScannerCard({super.key});

  @override
  Widget build(BuildContext context) {
    return ScannerStatusCard<SnmpScannerStatus>(
      title: 'SNMP Scanner',
      fetch: ({cancelToken}) =>
          BackendAPI.instance.getSnmpScannerStatus(cancelToken: cancelToken),
      resolver: _resolve,
    );
  }

  static ScannerStatus _resolve(
    BuildContext context,
    SnmpScannerStatus status,
    double elapsed,
  ) {
    final successColor = Theme.of(
      context,
    ).extension<AppColorExtension>()!.success;
    final neutralColor = Theme.of(context).colorScheme.outline;
    if (status.isRunning) {
      final sub = status.runningForSeconds != null
          ? ['Running for ${formatSeconds(status.runningForSeconds! + elapsed)}']
          : <String>[];
      return (color: successColor, label: 'Running', sublabels: sub);
    }
    if (status.nextRunInSeconds != null) {
      final remaining = (status.nextRunInSeconds! - elapsed).clamp(
        0.0,
        double.infinity,
      );
      return (
        color: neutralColor,
        label: 'Waiting for next run',
        sublabels: ['Next run in ${formatSeconds(remaining)}'],
      );
    }
    return (color: neutralColor, label: 'Not started', sublabels: []);
  }
}

import 'package:flutter/material.dart';

import '../model/dhcp_scanner_status.dart';
import '../theme/app_colors.dart';
import '../utils/duration_formatter.dart';
import '../utils/oott_api.dart';
import 'scanner_status_card.dart';

class DhcpScannerCard extends StatelessWidget {
  const DhcpScannerCard({super.key});

  @override
  Widget build(BuildContext context) {
    return ScannerStatusCard<DhcpScannerStatus>(
      title: 'DHCP Scanner',
      fetch: ({cancelToken}) =>
          BackendAPI.instance.getDhcpScannerStatus(cancelToken: cancelToken),
      resolver: _resolve,
    );
  }

  static ScannerStatus _resolve(
    BuildContext context,
    DhcpScannerStatus status,
    double elapsed,
  ) {
    if (!status.isListening) {
      return (
        color: Theme.of(context).colorScheme.outline,
        label: 'Not started',
        sublabels: [],
      );
    }
    final sublabels = <String>[
      status.listeningForSeconds != null
          ? 'Listening for ${formatSeconds(status.listeningForSeconds! + elapsed)} · ${status.devicesSeen} devices in the last hour'
          : '${status.devicesSeen} devices in the last hour',
      if (status.lastDeviceSeenSecondsAgo != null)
        'Last device ${formatSeconds(status.lastDeviceSeenSecondsAgo! + elapsed)} ago',
    ];
    return (
      color: Theme.of(context).extension<AppColorExtension>()!.success,
      label: 'Listening',
      sublabels: sublabels,
    );
  }
}

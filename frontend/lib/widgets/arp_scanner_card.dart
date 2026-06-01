import 'package:flutter/material.dart';

import '../model/arp_scanner_status.dart';
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

  static ScannerStatus _resolve(ArpScannerStatus status, double elapsed) {
    if (status.isRunning) {
      final sub = status.runningForSeconds != null
          ? ['Running for ${formatSeconds(status.runningForSeconds! + elapsed)}']
          : <String>[];
      return (color: Colors.green, label: 'Running', sublabels: sub);
    }
    if (status.nextRunInSeconds != null) {
      final remaining = (status.nextRunInSeconds! - elapsed).clamp(
        0.0,
        double.infinity,
      );
      return (
        color: Colors.amber,
        label: 'Waiting for next run',
        sublabels: ['Next run in ${formatSeconds(remaining)}'],
      );
    }
    return (color: Colors.grey, label: 'Not yet started', sublabels: []);
  }
}

import 'package:flutter/material.dart';

import '../model/mdns_scanner_status.dart';
import '../utils/duration_formatter.dart';
import '../utils/oott_api.dart';
import 'scanner_status_card.dart';

class MdnsScannerCard extends StatelessWidget {
  const MdnsScannerCard({super.key});

  @override
  Widget build(BuildContext context) {
    return ScannerStatusCard<MdnsScannerStatus>(
      title: 'mDNS Scanner',
      fetch: ({cancelToken}) =>
          BackendAPI.instance.getMdnsScannerStatus(cancelToken: cancelToken),
      resolver: _resolve,
    );
  }

  static ScannerStatus _resolve(MdnsScannerStatus status, double elapsed) {
    if (!status.isListening) {
      return (color: Colors.grey, label: 'Not yet started', sublabels: []);
    }
    final sublabels = <String>[
      status.listeningForSeconds != null
          ? 'Listening for ${formatSeconds(status.listeningForSeconds! + elapsed)} · ${status.devicesSeen} devices seen'
          : '${status.devicesSeen} devices seen',
      if (status.lastDeviceSeenSecondsAgo != null)
        'Last device ${formatSeconds(status.lastDeviceSeenSecondsAgo! + elapsed)} ago',
    ];
    return (color: Colors.green, label: 'Listening', sublabels: sublabels);
  }
}

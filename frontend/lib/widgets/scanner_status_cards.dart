import 'package:flutter/material.dart';

import '../model/active_scanner_status.dart';
import '../model/passive_scanner_status.dart';
import '../theme/app_colors.dart';
import '../utils/duration_formatter.dart';
import '../utils/oott_api.dart';
import 'scanner_status_card.dart';

/// Resolves the display status for an active (interval) scanner — ARP, SNMP.
ScannerStatus resolveActiveScanner(
  BuildContext context,
  ActiveScannerStatus status,
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

/// Resolves the display status for a passive (listening) scanner — mDNS, SSDP,
/// DHCP.
ScannerStatus resolvePassiveScanner(
  BuildContext context,
  PassiveScannerStatus status,
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

/// The scanner status detail cards, in display order. Each is a thin
/// configuration over the generic [ScannerStatusCard]: a title, the endpoint to
/// poll, and the resolver for its shape.
List<Widget> scannerStatusCards() => [
  ScannerStatusCard<ActiveScannerStatus>(
    title: 'ARP Scanner',
    fetch: ({cancelToken}) =>
        BackendAPI.instance.getArpScannerStatus(cancelToken: cancelToken),
    resolver: resolveActiveScanner,
  ),
  ScannerStatusCard<PassiveScannerStatus>(
    title: 'mDNS Scanner',
    fetch: ({cancelToken}) =>
        BackendAPI.instance.getMdnsScannerStatus(cancelToken: cancelToken),
    resolver: resolvePassiveScanner,
  ),
  ScannerStatusCard<PassiveScannerStatus>(
    title: 'SSDP/UPnP Scanner',
    fetch: ({cancelToken}) =>
        BackendAPI.instance.getSsdpScannerStatus(cancelToken: cancelToken),
    resolver: resolvePassiveScanner,
  ),
  ScannerStatusCard<PassiveScannerStatus>(
    title: 'DHCP Scanner',
    fetch: ({cancelToken}) =>
        BackendAPI.instance.getDhcpScannerStatus(cancelToken: cancelToken),
    resolver: resolvePassiveScanner,
  ),
  ScannerStatusCard<ActiveScannerStatus>(
    title: 'SNMP Scanner',
    fetch: ({cancelToken}) =>
        BackendAPI.instance.getSnmpScannerStatus(cancelToken: cancelToken),
    resolver: resolveActiveScanner,
  ),
];

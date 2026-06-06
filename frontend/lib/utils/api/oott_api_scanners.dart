part of '../oott_api.dart';

/// Per-scanner status endpoints. Active scanners (ARP, SNMP) share the
/// [ActiveScannerStatus] shape; passive scanners (mDNS, SSDP, DHCP) share the
/// [PassiveScannerStatus] shape. Each getter just decodes its model.
extension ScannerApi on BackendAPI {
  Future<ActiveScannerStatus> getArpScannerStatus({CancelToken? cancelToken}) =>
      _getModel(
        '/arp_scanner/status',
        ActiveScannerStatus.fromJson,
        cancelToken: cancelToken,
      );

  Future<PassiveScannerStatus> getMdnsScannerStatus({
    CancelToken? cancelToken,
  }) => _getModel(
    '/mdns_scanner/status',
    PassiveScannerStatus.fromJson,
    cancelToken: cancelToken,
  );

  Future<PassiveScannerStatus> getSsdpScannerStatus({
    CancelToken? cancelToken,
  }) => _getModel(
    '/ssdp_scanner/status',
    PassiveScannerStatus.fromJson,
    cancelToken: cancelToken,
  );

  Future<PassiveScannerStatus> getDhcpScannerStatus({
    CancelToken? cancelToken,
  }) => _getModel(
    '/dhcp_scanner/status',
    PassiveScannerStatus.fromJson,
    cancelToken: cancelToken,
  );

  Future<ActiveScannerStatus> getSnmpScannerStatus({
    CancelToken? cancelToken,
  }) => _getModel(
    '/snmp_scanner/status',
    ActiveScannerStatus.fromJson,
    cancelToken: cancelToken,
  );
}

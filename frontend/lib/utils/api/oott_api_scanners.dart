part of '../oott_api.dart';

/// Per-scanner status endpoints. Every scanner exposes the same
/// `/<scanner>_scanner/status` shape, so each getter just decodes its model.
extension ScannerApi on BackendAPI {
  Future<ArpScannerStatus> getArpScannerStatus({CancelToken? cancelToken}) =>
      _getModel(
        '/arp_scanner/status',
        ArpScannerStatus.fromJson,
        cancelToken: cancelToken,
      );

  Future<MdnsScannerStatus> getMdnsScannerStatus({CancelToken? cancelToken}) =>
      _getModel(
        '/mdns_scanner/status',
        MdnsScannerStatus.fromJson,
        cancelToken: cancelToken,
      );

  Future<SsdpScannerStatus> getSsdpScannerStatus({CancelToken? cancelToken}) =>
      _getModel(
        '/ssdp_scanner/status',
        SsdpScannerStatus.fromJson,
        cancelToken: cancelToken,
      );

  Future<DhcpScannerStatus> getDhcpScannerStatus({CancelToken? cancelToken}) =>
      _getModel(
        '/dhcp_scanner/status',
        DhcpScannerStatus.fromJson,
        cancelToken: cancelToken,
      );

  Future<SnmpScannerStatus> getSnmpScannerStatus({CancelToken? cancelToken}) =>
      _getModel(
        '/snmp_scanner/status',
        SnmpScannerStatus.fromJson,
        cancelToken: cancelToken,
      );
}

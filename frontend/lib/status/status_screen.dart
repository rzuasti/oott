import 'package:flutter/material.dart';

import '../theme/dimens.dart';
import '../widgets/arp_scanner_card.dart';
import '../widgets/dhcp_scanner_card.dart';
import '../widgets/mdns_scanner_card.dart';
import '../widgets/snmp_scanner_card.dart';
import '../widgets/ssdp_scanner_card.dart';

class StatusScreen extends StatelessWidget {
  const StatusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ArpScannerCard(),
          const SizedBox(height: Insets.sm),
          const MdnsScannerCard(),
          const SizedBox(height: Insets.sm),
          const SsdpScannerCard(),
          const SizedBox(height: Insets.sm),
          const DhcpScannerCard(),
          const SizedBox(height: Insets.sm),
          const SnmpScannerCard(),
        ],
      ),
    );
  }
}

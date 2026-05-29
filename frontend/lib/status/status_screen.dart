import 'package:flutter/material.dart';

import '../widgets/arp_scanner_card.dart';
import '../widgets/mdns_scanner_card.dart';

class StatusScreen extends StatelessWidget {
  const StatusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Status', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 20),
        const ArpScannerCard(),
        const SizedBox(height: 8),
        const MdnsScannerCard(),
      ],
    );
  }
}

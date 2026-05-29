import 'package:flutter/material.dart';

import '../widgets/arp_scanner_card.dart';
import '../widgets/device_summary_card.dart';
import 'notifications_list.dart';

const _twoColumnBreakpoint = 700.0;

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isTwoColumn = constraints.maxWidth >= _twoColumnBreakpoint;
        return isTwoColumn ? _buildTwoColumn() : _buildSingleColumn();
      },
    );
  }

  Widget _buildTwoColumn() {
    return const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 3, child: NotificationsList()),
        VerticalDivider(width: 32),
        SizedBox(
          width: 300,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DeviceSummaryCard(),
                SizedBox(height: 16),
                ArpScannerCard(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSingleColumn() {
    return const NotificationsList(
      trailingSlivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.only(top: 24),
            child: DeviceSummaryCard(),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.only(top: 16, bottom: 20),
            child: ArpScannerCard(),
          ),
        ),
      ],
    );
  }
}

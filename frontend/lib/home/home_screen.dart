import 'package:flutter/material.dart';

import '../theme/dimens.dart';
import '../widgets/device_summary_card.dart';
import '../widgets/scanners_status_card.dart';
import 'notifications_list.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isTwoColumn = constraints.maxWidth >= Breakpoints.twoColumn;
        return isTwoColumn ? _buildTwoColumn() : _buildSingleColumn();
      },
    );
  }

  Widget _buildTwoColumn() {
    return const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 3, child: NotificationsList()),
        VerticalDivider(width: Insets.xxxl),
        SizedBox(
          width: 300,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DeviceSummaryCard(),
                SizedBox(height: Insets.lg),
                ScannersStatusCard(),
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
            padding: EdgeInsets.only(top: Insets.xxl),
            child: DeviceSummaryCard(),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.only(top: Insets.lg, bottom: Insets.xl),
            child: ScannersStatusCard(),
          ),
        ),
      ],
    );
  }
}

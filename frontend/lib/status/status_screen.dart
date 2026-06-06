import 'package:flutter/material.dart';

import '../theme/dimens.dart';
import '../widgets/scanner_status_cards.dart';

class StatusScreen extends StatelessWidget {
  const StatusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cards = scannerStatusCards();
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < cards.length; i++) ...[
            if (i > 0) const SizedBox(height: Insets.sm),
            cards[i],
          ],
        ],
      ),
    );
  }
}

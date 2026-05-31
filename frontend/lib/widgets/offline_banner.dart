import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../utils/backend_reachability.dart';

class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final reachability = BackendReachability.instance;
    return ListenableBuilder(
      listenable: reachability,
      builder: (context, _) {
        if (reachability.isOnline) return const SizedBox.shrink();
        final theme = Theme.of(context);
        final message = !reachability.deviceHasNetwork
            ? 'No network connection.'
            : reachability.isProbing
            ? 'Reconnecting to backend…'
            : reachability.lastErrorMessage ?? 'Cannot reach backend.';
        return Material(
          color: theme.colorScheme.errorContainer,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Icon(
                  Icons.cloud_off,
                  size: 18,
                  color: theme.colorScheme.onErrorContainer,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    message,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onErrorContainer,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: reachability.isProbing
                      ? null
                      : () => reachability.probe(),
                  style: TextButton.styleFrom(
                    foregroundColor: theme.colorScheme.onErrorContainer,
                  ),
                  child: const Text('Retry'),
                ),
                TextButton(
                  onPressed: () => context.go('/settings'),
                  style: TextButton.styleFrom(
                    foregroundColor: theme.colorScheme.onErrorContainer,
                  ),
                  child: const Text('Settings'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

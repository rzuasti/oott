import 'package:flutter/material.dart';

class PaginationBar extends StatelessWidget {
  const PaginationBar({
    super.key,
    required this.currentPage,
    required this.hasNextPage,
    required this.isLoading,
    required this.onPageChanged,
  });

  final int currentPage;
  final bool hasNextPage;
  final bool isLoading;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    final canGoBack = currentPage > 0 && !isLoading;
    final canGoForward = hasNextPage && !isLoading;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton.outlined(
            onPressed: canGoBack ? () => onPageChanged(0) : null,
            icon: const Icon(Icons.first_page),
            tooltip: 'First page',
          ),
          const SizedBox(width: 8),
          IconButton.outlined(
            onPressed: canGoBack ? () => onPageChanged(currentPage - 1) : null,
            icon: const Icon(Icons.chevron_left),
            tooltip: 'Previous page',
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Page ${currentPage + 1}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          IconButton.outlined(
            onPressed: canGoForward
                ? () => onPageChanged(currentPage + 1)
                : null,
            icon: const Icon(Icons.chevron_right),
            tooltip: 'Next page',
          ),
        ],
      ),
    );
  }
}

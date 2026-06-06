import 'package:flutter/material.dart';

import '../theme/dimens.dart';

class PaginationBar extends StatelessWidget {
  const PaginationBar({
    super.key,
    required this.currentPage,
    required this.totalPages,
    required this.isLoading,
    required this.onPageChanged,
  });

  final int currentPage;
  final int totalPages;
  final bool isLoading;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    final lastPage = totalPages - 1;
    final canGoBack = currentPage > 0 && !isLoading;
    final canGoForward = currentPage < lastPage && !isLoading;
    // Phones don't have room for the verbose label, so they get the compact
    // "X / Y" form; wider layouts spell it out.
    final isWide = MediaQuery.sizeOf(context).width >= Breakpoints.medium;
    final label = isWide
        ? 'Page ${currentPage + 1} of $totalPages'
        : '${currentPage + 1} / $totalPages';
    // While a page change is in flight the buttons disable so the tap reads as
    // registered and double-taps are blocked; the progress cue itself is drawn
    // by the app shell at the bottom of the page body.
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
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          IconButton.outlined(
            onPressed: canGoForward
                ? () => onPageChanged(currentPage + 1)
                : null,
            icon: const Icon(Icons.chevron_right),
            tooltip: 'Next page',
          ),
          const SizedBox(width: 8),
          IconButton.outlined(
            onPressed: canGoForward ? () => onPageChanged(lastPage) : null,
            icon: const Icon(Icons.last_page),
            tooltip: 'Last page',
          ),
        ],
      ),
    );
  }
}

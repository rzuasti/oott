import 'package:flutter/material.dart';

/// Shared flag that drives the page-level pagination progress bar. The lists set
/// it while fetching a new page; the app shell renders the bar flush against the
/// bottom of the page body (above the navigation bar on phones, the screen
/// bottom on wider layouts) so the cue sits outside the page's content padding.
final ValueNotifier<bool> paginationLoading = ValueNotifier<bool>(false);

/// Overlays [child] with an indeterminate progress bar pinned to the bottom of
/// the available space, shown whenever [paginationLoading] is set. The bar is
/// full width and flush with the bottom edge, so it reads as a page-level cue
/// rather than part of the scrolling content.
class PaginationProgressOverlay extends StatelessWidget {
  const PaginationProgressOverlay({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: ValueListenableBuilder<bool>(
            valueListenable: paginationLoading,
            builder: (context, loading, _) => loading
                ? const LinearProgressIndicator(minHeight: 4)
                : const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }
}

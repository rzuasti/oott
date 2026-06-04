import 'package:flutter/material.dart';

import '../theme/dimens.dart';

/// A single gently pulsing placeholder block, used to build skeleton loaders.
class Skeleton extends StatefulWidget {
  const Skeleton({
    this.width,
    this.height = Insets.md,
    this.borderRadius,
    super.key,
  });

  final double? width;
  final double height;
  final BorderRadius? borderRadius;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.surfaceContainerHighest;
    return FadeTransition(
      opacity: Tween<double>(begin: 0.4, end: 1.0).animate(_controller),
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: base,
          borderRadius: widget.borderRadius ?? BorderRadius.circular(Insets.xs),
        ),
      ),
    );
  }
}

/// A skeleton placeholder approximating a list of rows (avatar + two text
/// lines), shown while list data is loading to avoid a bare spinner and layout
/// shift.
class ListSkeleton extends StatelessWidget {
  const ListSkeleton({this.rows = 6, super.key});

  final int rows;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Column(
        children: List.generate(
          rows,
          (_) => Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Insets.sm,
              vertical: Insets.md,
            ),
            child: Row(
              children: const [
                Skeleton(
                  width: 36,
                  height: 36,
                  borderRadius: BorderRadius.all(Radius.circular(18)),
                ),
                SizedBox(width: Insets.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Skeleton(width: 160),
                      SizedBox(height: Insets.sm),
                      Skeleton(width: 100),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

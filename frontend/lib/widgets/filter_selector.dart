import 'package:flutter/material.dart';

import '../theme/dimens.dart';

/// A single-select control that adapts to the available width.
///
/// On wide (tablet/desktop) layouts the options are laid out as a
/// [SegmentedButton] of pills. On narrow (phone) layouts, where a full row of
/// pills competes for horizontal space with neighbouring actions, it collapses
/// to a compact dropdown button showing the current selection.
class FilterSelector<T> extends StatelessWidget {
  const FilterSelector({
    super.key,
    required this.values,
    required this.selected,
    required this.labelOf,
    required this.onSelected,
  });

  /// The selectable options, in display order.
  final List<T> values;

  /// The currently selected option.
  final T selected;

  /// Builds the human-readable label for an option.
  final String Function(T value) labelOf;

  /// Called with the option the user picked.
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= Breakpoints.medium;
    return isWide ? _buildSegmented(context) : _buildDropdown(context);
  }

  Widget _buildSegmented(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(
        horizontal: Insets.sm,
        vertical: Insets.xs,
      ),
      child: SegmentedButton<T>(
        showSelectedIcon: false,
        segments: values
            .map(
              (value) =>
                  ButtonSegment<T>(value: value, label: Text(labelOf(value))),
            )
            .toList(),
        selected: {selected},
        onSelectionChanged: (selection) => onSelected(selection.first),
      ),
    );
  }

  Widget _buildDropdown(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Insets.sm,
          vertical: Insets.xs,
        ),
        child: PopupMenuButton<T>(
          initialValue: selected,
          tooltip: 'Change filter',
          onSelected: onSelected,
          itemBuilder: (context) => values
              .map(
                (value) => PopupMenuItem<T>(
                  value: value,
                  child: Text(labelOf(value)),
                ),
              )
              .toList(),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: Insets.md,
              vertical: Insets.sm,
            ),
            decoration: BoxDecoration(
              border: Border.all(color: theme.colorScheme.outline),
              borderRadius: BorderRadius.circular(Insets.sm),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(labelOf(selected), style: theme.textTheme.labelLarge),
                const SizedBox(width: Insets.xs),
                Icon(
                  Icons.arrow_drop_down,
                  size: 20,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

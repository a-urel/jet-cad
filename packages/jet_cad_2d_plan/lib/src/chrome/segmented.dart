// A few mutually exclusive choices side by side (spec "Choices"): toggled
// shadcn buttons, the chosen one drawn secondary.
import 'package:flutter/widgets.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'words_carrier.dart';

/// One segment of a [PlanSegmented]: a [value], its [label], an optional
/// [icon]. [key] is put on the segment's button.
class PlanSegment<T> {
  const PlanSegment(this.value, this.label, {this.icon, this.key});

  final T value;
  final String label;
  final IconData? icon;
  final Key? key;
}

/// A row of segments. [value] is the authority: the selected segment is
/// always the one [value] names, whatever was tapped.
class PlanSegmented<T> extends StatelessWidget implements PlanWordsCarrier {
  const PlanSegmented({
    super.key,
    required this.value,
    required this.segments,
    required this.onChanged,
    this.enabled = true,
  });

  final T value;
  final List<PlanSegment<T>> segments;
  final ValueChanged<T> onChanged;
  final bool enabled;

  @override
  Iterable<String> get visibleWords => [for (final s in segments) s.label];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        for (final segment in segments)
          _button(segment, segment.value == value),
      ],
    );
  }

  Widget _button(PlanSegment<T> segment, bool selected) {
    final icon = segment.icon;
    final leading = icon == null ? null : Icon(icon);
    final onPressed = enabled ? () => onChanged(segment.value) : null;
    final child = Text(segment.label);
    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      label: segment.label,
      onTap: onPressed,
      excludeSemantics: true,
      child: selected
          ? ShadButton.secondary(
              key: segment.key,
              leading: leading,
              onPressed: onPressed,
              child: child)
          : ShadButton.ghost(
              key: segment.key,
              leading: leading,
              onPressed: onPressed,
              child: child),
    );
  }
}

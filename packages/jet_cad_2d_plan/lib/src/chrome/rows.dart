// The rows of the panels (spec "Choices", "Semantics"): a checkbox row, a
// switch row and a selectable list row. Each is focusable, activates on
// Enter and Space, and says what it is to assistive technology.
import 'package:flutter/widgets.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'words_carrier.dart';

/// A labelled checkbox. Disabled when [onChanged] is null.
class PlanCheckRow extends StatelessWidget implements PlanWordsCarrier {
  const PlanCheckRow({
    super.key,
    required this.label,
    required this.value,
    this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Iterable<String> get visibleWords => [label];

  @override
  Widget build(BuildContext context) => ShadCheckbox(
        value: value,
        enabled: onChanged != null,
        onChanged: onChanged == null ? null : (v) => onChanged!(v),
        label: Text(label),
      );
}

/// A labelled switch. Disabled when [onChanged] is null.
class PlanSwitchRow extends StatelessWidget implements PlanWordsCarrier {
  const PlanSwitchRow({
    super.key,
    required this.label,
    required this.value,
    this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Iterable<String> get visibleWords => [label];

  @override
  Widget build(BuildContext context) => ShadSwitch(
        value: value,
        enabled: onChanged != null,
        onChanged: onChanged == null ? null : (v) => onChanged!(v),
        label: Text(label),
      );
}

/// A row of a list (a layer, a page, a symbol): [leading] and [title], drawn
/// secondary while [selected].
class PlanListRow extends StatelessWidget implements PlanWordsCarrier {
  const PlanListRow({
    super.key,
    required this.title,
    this.leading,
    this.selected = false,
    this.onTap,
  });

  final Widget title;
  final Widget? leading;
  final bool selected;
  final VoidCallback? onTap;

  /// The title is a widget: its words are its owner's to report.
  @override
  Iterable<String> get visibleWords => const [];

  @override
  Widget build(BuildContext context) {
    final content =
        Align(alignment: AlignmentDirectional.centerStart, child: title);
    return Semantics(
      button: true,
      selected: selected,
      enabled: onTap != null,
      onTap: onTap,
      child: selected
          ? ShadButton.secondary(
              width: double.infinity,
              mainAxisAlignment: MainAxisAlignment.start,
              leading: leading,
              onPressed: onTap,
              child: content)
          : ShadButton.ghost(
              width: double.infinity,
              mainAxisAlignment: MainAxisAlignment.start,
              leading: leading,
              onPressed: onTap,
              child: content),
    );
  }
}

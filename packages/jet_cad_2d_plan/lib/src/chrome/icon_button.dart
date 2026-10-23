// The icon button of the bars and rows (spec "Menus", "Semantics"): a ghost
// shadcn icon button with a tooltip and the semantics the Material
// `IconButton` gave (a button, labelled, selected or not, enabled or not).
import 'package:flutter/widgets.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'words_carrier.dart';

/// Tells the [PlanIconButton]s below it not to show a tooltip: a menu that
/// opens under its button would be covered by the button's own tooltip.
class PlanTooltipSuppressor extends InheritedWidget {
  const PlanTooltipSuppressor({
    super.key,
    required this.suppressed,
    required super.child,
  });

  final bool suppressed;

  static bool of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<PlanTooltipSuppressor>()
          ?.suppressed ??
      false;

  @override
  bool updateShouldNotify(PlanTooltipSuppressor oldWidget) =>
      suppressed != oldWidget.suppressed;
}

/// A ghost icon button; the secondary variant when [selected] is true.
///
/// [label] is the accessible name and the tooltip unless [tooltip] says
/// otherwise. [selected] null means the button has no selected state (a
/// command); true or false means it is a toggle.
class PlanIconButton extends StatefulWidget implements PlanWordsCarrier {
  const PlanIconButton({
    super.key,
    required this.icon,
    required this.label,
    this.onPressed,
    this.selected,
    this.tooltip,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool? selected;
  final String? tooltip;

  @override
  Iterable<String> get visibleWords {
    final tip = tooltip;
    return {label, if (tip != null) tip};
  }

  @override
  State<PlanIconButton> createState() => _PlanIconButtonState();
}

class _PlanIconButtonState extends State<PlanIconButton> {
  /// Keeps the button's state (its focus, its hover) when the tooltip around
  /// it comes and goes.
  final GlobalKey _button = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final glyph = Icon(widget.icon);
    final onPressed = widget.onPressed;
    final button = KeyedSubtree(
      key: _button,
      child: widget.selected == true
          ? ShadIconButton.secondary(icon: glyph, onPressed: onPressed)
          : ShadIconButton.ghost(icon: glyph, onPressed: onPressed),
    );
    return Semantics(
      button: true,
      label: widget.label,
      selected: widget.selected,
      enabled: onPressed != null,
      focusable: onPressed != null,
      onTap: onPressed,
      excludeSemantics: true,
      child: PlanTooltipSuppressor.of(context)
          ? button
          : ShadTooltip(
              builder: (context) => Text(widget.tooltip ?? widget.label),
              child: button,
            ),
    );
  }
}

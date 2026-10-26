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

/// The one tooltip of the chrome: a `ShadTooltip` showing [message], with
/// [message] also as the semantics label of [child]. It reports its word to
/// the leak collectors (a closed tooltip shows no text).
class PlanTooltip extends StatelessWidget implements PlanWordsCarrier {
  const PlanTooltip({super.key, required this.message, required this.child});

  final String message;
  final Widget child;

  @override
  Iterable<String> get visibleWords => [message];

  @override
  Widget build(BuildContext context) => Semantics(
        container: true,
        label: message,
        child: ShadTooltip(
            hoverStrategies: kPlanTooltipTouch,
            builder: (_) => Text(message),
            child: child),
      );
}

/// A tooltip on a touch screen shows while a long press holds, as a
/// Material tooltip does. shadcn's default shows it on a tap's down, so a tap
/// on a button left its tooltip over what the button opened (a phone's
/// drawer). A mouse is unaffected: it hovers.
const ShadHoverStrategies kPlanTooltipTouch = ShadHoverStrategies(
  hover: {ShadHoverStrategy.onLongPressStart},
  unhover: {
    ShadHoverStrategy.onLongPressUp,
    ShadHoverStrategy.onLongPressEnd,
    ShadHoverStrategy.onLongPressCancel,
    ShadHoverStrategy.onTapUp,
    ShadHoverStrategy.onTapCancel,
    ShadHoverStrategy.onTapOutside,
  },
);

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
    this.compact = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool? selected;
  final String? tooltip;

  /// A 28 px square with a 16 px glyph, for the rows of a list (a layer's
  /// eye and lock), instead of the toolbar's size.
  final bool compact;

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

  /// A long press does nothing but is recognized, so the tooltip's touch
  /// strategy ([kPlanTooltipTouch]) hears it: shadcn's detector has no
  /// long-press recognizer without a long-press callback.
  static void _holdForTooltip() {}

  @override
  Widget build(BuildContext context) {
    final glyph = Icon(widget.icon);
    final onPressed = widget.onPressed;
    final size = widget.compact ? 28.0 : null;
    final padding = widget.compact ? EdgeInsets.zero : null;
    final button = KeyedSubtree(
      key: _button,
      child: widget.selected == true
          ? ShadIconButton.secondary(
              icon: glyph,
              width: size,
              height: size,
              padding: padding,
              onPressed: onPressed,
              onLongPress: _holdForTooltip)
          : ShadIconButton.ghost(
              icon: glyph,
              width: size,
              height: size,
              padding: padding,
              onPressed: onPressed,
              onLongPress: _holdForTooltip),
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
          : PlanTooltip(message: widget.tooltip ?? widget.label, child: button),
    );
  }
}

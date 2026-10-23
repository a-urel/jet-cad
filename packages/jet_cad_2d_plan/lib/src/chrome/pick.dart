// The two chrome parts that are not a shadcn component: a swatch (a colour or
// a paper to pick) and a row of a list that holds buttons of its own (a
// layer). Each is focusable, activates on Enter and Space, shows the
// theme's hover, selection and focus ring, and says what it is to assistive
// technology (spec "Semantics", "Choices").
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'icon_button.dart' show PlanTooltip;
import 'shad_scope.dart';
import 'words_carrier.dart';

const Map<ShortcutActivator, Intent> _activate = {
  SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
  SingleActivator(LogicalKeyboardKey.numpadEnter): ActivateIntent(),
  SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
};

/// A swatch button: [child] (the swatch itself) that picks something on a
/// tap, Enter or Space.
///
/// [label] is the accessible name; [tooltip], if given, is the tooltip and
/// the label stays the name (a swatch blocked for a reason names its colour
/// and tells the reason). [selected] marks the picked swatch. A null [onTap]
/// is a disabled swatch: it cannot take the focus. A [circle] swatch draws
/// its focus ring round.
class PlanSwatchButton extends StatefulWidget implements PlanWordsCarrier {
  const PlanSwatchButton({
    super.key,
    required this.child,
    required this.onTap,
    this.selected = false,
    this.label,
    this.tooltip,
    this.circle = false,
  });

  final Widget child;
  final VoidCallback? onTap;
  final bool selected;
  final String? label;
  final String? tooltip;
  final bool circle;

  @override
  Iterable<String> get visibleWords => [
        if (label != null) label!,
        if (tooltip != null) tooltip!,
      ];

  @override
  State<PlanSwatchButton> createState() => _PlanSwatchButtonState();
}

class _PlanSwatchButtonState extends State<PlanSwatchButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final theme = planShadThemeOf(context);
    final onTap = widget.onTap;
    final enabled = onTap != null;
    final ring = _focused && enabled
        ? Positioned(
            left: -3,
            top: -3,
            right: -3,
            bottom: -3,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: widget.circle ? BoxShape.circle : BoxShape.rectangle,
                  border: Border.all(color: theme.colorScheme.ring, width: 2),
                ),
              ),
            ),
          )
        : null;
    Widget body = FocusableActionDetector(
      enabled: enabled,
      mouseCursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
      shortcuts: _activate,
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) {
          onTap?.call();
          return null;
        }),
      },
      onShowFocusHighlight: (focused) => setState(() => _focused = focused),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Stack(
          clipBehavior: Clip.none,
          children: [widget.child, if (ring != null) ring],
        ),
      ),
    );
    final tooltip = widget.tooltip;
    if (tooltip != null) body = PlanTooltip(message: tooltip, child: body);
    return Semantics(
      button: true,
      selected: widget.selected,
      enabled: enabled,
      focusable: enabled,
      label: widget.label,
      onTap: onTap,
      excludeSemantics: widget.label != null,
      child: body,
    );
  }
}

/// A row of a list whose content holds buttons of its own (a layer: its
/// eye, its lock, its colour, its name). The row's surface is drawn
/// secondary while [selected] and in the theme's accent under the pointer or
/// the focus; a tap on it, or Enter or Space while it has the focus, calls
/// [onTap]. The surface is its own focus stop beside the content's, not
/// above it, so a key typed in a field of the content never reaches it.
class PlanHoverRow extends StatefulWidget {
  const PlanHoverRow({
    super.key,
    required this.child,
    required this.onTap,
    this.selected = false,
    this.minHeight = 0,
  });

  final Widget child;
  final VoidCallback? onTap;
  final bool selected;
  final double minHeight;

  @override
  State<PlanHoverRow> createState() => _PlanHoverRowState();
}

class _PlanHoverRowState extends State<PlanHoverRow> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final theme = planShadThemeOf(context);
    final colours = theme.colorScheme;
    final onTap = widget.onTap;
    final fill = widget.selected
        ? colours.secondary
        : _hovered || _focused
            ? colours.accent
            : null;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Semantics(
        container: true,
        selected: widget.selected,
        onTap: onTap,
        child: Stack(
          children: [
            Positioned.fill(
              child: FocusableActionDetector(
                enabled: onTap != null,
                shortcuts: _activate,
                actions: {
                  ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) {
                    onTap?.call();
                    return null;
                  }),
                },
                onShowFocusHighlight: (v) => setState(() => _focused = v),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onTap,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: fill,
                      borderRadius: BorderRadius.circular(6),
                      border: _focused
                          ? Border.all(color: colours.ring, width: 1)
                          : null,
                    ),
                  ),
                ),
              ),
            ),
            ConstrainedBox(
              constraints: BoxConstraints(minHeight: widget.minHeight),
              child: widget.child,
            ),
          ],
        ),
      ),
    );
  }
}

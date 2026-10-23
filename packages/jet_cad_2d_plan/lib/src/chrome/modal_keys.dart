// The keyboard policy of an open select or menu (spec G5): a Material
// dropdown or popup menu is a modal route, so while one is open no editor or
// host chord acts. The shadcn popovers are not routes; their content is an
// overlay portal whose focus ancestors are the widgets around the select or
// menu. So the part wraps itself in a [PlanModalKeys], which, while its
// popover is open, consumes every key event that is not the popover's own
// navigation, before it can reach an outer shortcut. (A hardware keyboard
// handler cannot do this: its result does not stop the focus dispatch.)
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// The keys an open popover navigates with, and the modifiers a chord is
/// made of (consuming a modifier would change nothing but hide a chord's
/// second key from the popover's own handling).
final Set<LogicalKeyboardKey> _allowed = {
  LogicalKeyboardKey.arrowUp,
  LogicalKeyboardKey.arrowDown,
  LogicalKeyboardKey.arrowLeft,
  LogicalKeyboardKey.arrowRight,
  LogicalKeyboardKey.home,
  LogicalKeyboardKey.end,
  LogicalKeyboardKey.enter,
  LogicalKeyboardKey.numpadEnter,
  LogicalKeyboardKey.space,
  LogicalKeyboardKey.escape,
  LogicalKeyboardKey.tab,
  LogicalKeyboardKey.shiftLeft,
  LogicalKeyboardKey.shiftRight,
  LogicalKeyboardKey.controlLeft,
  LogicalKeyboardKey.controlRight,
  LogicalKeyboardKey.metaLeft,
  LogicalKeyboardKey.metaRight,
  LogicalKeyboardKey.altLeft,
  LogicalKeyboardKey.altRight,
};

/// Consumes, while [isOpen], every key event that is not popover navigation.
class PlanModalKeys extends StatelessWidget {
  const PlanModalKeys({super.key, required this.isOpen, required this.child});

  /// Asked at every key event.
  final bool Function() isOpen;
  final Widget child;

  @override
  Widget build(BuildContext context) => Focus(
        canRequestFocus: false,
        skipTraversal: true,
        onKeyEvent: (node, event) =>
            isOpen() && !_allowed.contains(event.logicalKey)
                ? KeyEventResult.handled
                : KeyEventResult.ignored,
        child: child,
      );
}

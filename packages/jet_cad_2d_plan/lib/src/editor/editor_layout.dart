// POS-host spec D1-D5: how PlanEditor lays its design mode out for a phone,
// a tablet and a desktop, and the drawer host the first two use. Desktop is
// the editor's own docked tree and does not pass through here.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show HardwareKeyboard, KeyDownEvent, KeyEvent, LogicalKeyboardKey;

/// The shapes of the editor's design mode (spec D1-D3).
///
/// - [phone]: no docked column; the bar's left button opens the tools and
///   symbols over the plan, its right button the properties, layers and page.
/// - [tablet]: the tool strip docked on the left, icons only, with a symbols
///   icon at its foot; the bar's right button opens the right panel.
/// - [desktop]: both columns docked.
enum PlanEditorLayout { phone, tablet, desktop }

/// The widths, in logical pixels of the editor's own width, at which the
/// layout changes (spec D4): below [tablet] is a phone, from [tablet] to
/// below [desktop] a tablet, from [desktop] a desktop.
@immutable
final class PlanLayoutBreakpoints {
  const PlanLayoutBreakpoints({this.tablet = 600, this.desktop = 1000})
      : assert(tablet <= desktop, 'tablet must not exceed desktop');

  final double tablet;
  final double desktop;

  /// The layout for an editor [width] pixels wide.
  PlanEditorLayout layoutFor(double width) {
    if (width < tablet) return PlanEditorLayout.phone;
    if (width < desktop) return PlanEditorLayout.tablet;
    return PlanEditorLayout.desktop;
  }

  @override
  bool operator ==(Object other) =>
      other is PlanLayoutBreakpoints &&
      other.tablet == tablet &&
      other.desktop == desktop;

  @override
  int get hashCode => Object.hash(tablet, desktop);

  @override
  String toString() =>
      'PlanLayoutBreakpoints(tablet: $tablet, desktop: $desktop)';
}

/// The side a drawer opens from.
enum PlanDrawerSide { left, right }

/// The canvas with at most one drawer over it (spec D5). The drawers are an
/// overlay in a [Stack], so opening one never changes the canvas's size and
/// so never moves the camera. Both drawers' content stays mounted while
/// closed (offstage), so a panel keeps its state. A tap on the translucent
/// barrier, or Escape while focus is inside, calls [onClose].
class PlanDrawerHost extends StatefulWidget {
  const PlanDrawerHost({
    super.key,
    required this.canvas,
    required this.open,
    required this.onClose,
    this.left,
    this.right,
    this.leftWidth = 280,
    this.rightWidth = 300,
  });

  final Widget canvas;
  final PlanDrawerSide? open;
  final VoidCallback onClose;

  /// The drawer contents; null: no such drawer.
  final Widget? left;
  final Widget? right;
  final double leftWidth;
  final double rightWidth;

  @override
  State<PlanDrawerHost> createState() => _PlanDrawerHostState();
}

class _PlanDrawerHostState extends State<PlanDrawerHost> {
  // Escape is taken from the hardware keyboard while a drawer is open, ahead
  // of the focus tree: the canvas's select tool would otherwise take it to
  // clear the selection, and the drawer would stay.
  bool _listening = false;

  bool _onKey(KeyEvent event) {
    if (event.logicalKey != LogicalKeyboardKey.escape) return false;
    // A text field in a drawer keeps its Escape.
    final focus = FocusManager.instance.primaryFocus?.context;
    if (focus != null &&
        (focus.widget is EditableText ||
            focus.findAncestorWidgetOfExactType<EditableText>() != null)) {
      return false;
    }
    if (event is KeyDownEvent) widget.onClose();
    return true;
  }

  void _sync() {
    final want = widget.open != null;
    if (want == _listening) return;
    _listening = want;
    if (want) {
      HardwareKeyboard.instance.addHandler(_onKey);
    } else {
      HardwareKeyboard.instance.removeHandler(_onKey);
    }
  }

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(PlanDrawerHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  @override
  void dispose() {
    if (_listening) HardwareKeyboard.instance.removeHandler(_onKey);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final open = widget.open, left = widget.left, right = widget.right;
    return LayoutBuilder(builder: (context, constraints) {
      final cap = constraints.maxWidth * 0.85;
      Widget drawer(PlanDrawerSide side, Widget? child, double width) {
        if (child == null) return const SizedBox.shrink();
        final shown = open == side;
        return Positioned(
          top: 0,
          bottom: 0,
          left: side == PlanDrawerSide.left ? 0 : null,
          right: side == PlanDrawerSide.right ? 0 : null,
          width: width < cap ? width : cap,
          child: Visibility(
            visible: shown,
            maintainState: true,
            child: Material(
              key: Key(side == PlanDrawerSide.left
                  ? 'chrome-left-drawer'
                  : 'chrome-right-drawer'),
              elevation: 8,
              color: scheme.surfaceContainerLow,
              child: child,
            ),
          ),
        );
      }

      return Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(child: widget.canvas),
          // Always one child here, so the drawers below keep their place
          // in the list (and their state) as the barrier comes and goes.
          open == null
              ? const SizedBox.shrink()
              : Positioned.fill(
                  child: GestureDetector(
                    key: const Key('chrome-drawer-barrier'),
                    behavior: HitTestBehavior.opaque,
                    onTap: widget.onClose,
                    child:
                        ColoredBox(color: scheme.scrim.withValues(alpha: 0.32)),
                  ),
                ),
          drawer(PlanDrawerSide.left, left, widget.leftWidth),
          drawer(PlanDrawerSide.right, right, widget.rightWidth),
        ],
      );
    });
  }
}

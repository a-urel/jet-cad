import 'package:flutter/widgets.dart';

/// The focus node of a text field in the shell's right-hand panels: the
/// Selection panel's fields and the Page panel's scale.
///
/// A panel field is a detour: the user types a value, then goes on working
/// on the canvas, where the shell's letters and Escape live. So every panel
/// field leaves by [handBack] -- on Enter and on a tap outside it.
final class PanelFieldFocusNode extends FocusNode {
  PanelFieldFocusNode({super.debugLabel});

  /// Hands the focus back to the node that had it before the panel fields
  /// -- the canvas.
  ///
  /// One `UnfocusDisposition.previouslyFocusedChild` focuses the scope's
  /// most recent focused child other than this node. After Width then
  /// Height, or a Selection panel field then the page scale, that child is
  /// the earlier panel field, still in the scope's focus history
  /// (fix/post-07 F3). So the walk goes on while it lands on a panel field,
  /// in either panel: each step drops that field from the history, until
  /// the most recent child is not a panel field, or the history is empty
  /// and the scope itself takes the focus. Every step removes a node, and
  /// `seen` bounds the walk by the number of panel fields anyway.
  ///
  /// A canvas click that has just requested the focus is already the
  /// scope's most recent child when its tap-outside arrives, so the walk
  /// stops at it at once. A plain `unfocus()` would not do: it clears the
  /// scope's history and takes the focus to the scope itself, even from
  /// that click, and with the focus on the route's scope no key reaches the
  /// shell's shortcuts.
  void handBack() {
    if (!hasFocus) return;
    final seen = <FocusNode>{};
    FocusNode? node = this;
    while (node is PanelFieldFocusNode && seen.add(node)) {
      node.unfocus(disposition: UnfocusDisposition.previouslyFocusedChild);
      node = node.enclosingScope?.focusedChild;
    }
  }
}

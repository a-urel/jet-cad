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
  /// A canvas click requests the focus itself, and the walk leaves that
  /// request alone: if it came first, the canvas is the scope's most recent
  /// child and the walk stops at it at once; if not, it lands after the
  /// walk. A plain `unfocus()` would not do: it clears the scope's history
  /// and takes the focus to the scope itself, even from that click, and
  /// with the focus on the route's scope no key reaches the shell's
  /// shortcuts.
  ///
  /// The walk starts from the node that has the focus, which is not always
  /// this one. Enter comes from the focused field, but `onTapOutside` is
  /// armed from the field's focus at its *last build*: within one frame it
  /// can fire for a field that has since lost the focus -- tap Width, then
  /// tap the scale, then click the Page title before a frame (fix/post-07
  /// F2F3b m1). Walking from this node there would find it unfocused, go on
  /// from the scale, step back to Width, and stop on Width, which `seen`
  /// already holds. From the focused node the walk passes both. And when
  /// the focused node is not a panel field, there is nothing to hand back.
  void handBack() {
    final seen = <FocusNode>{};
    FocusNode? node = hasFocus ? this : FocusManager.instance.primaryFocus;
    while (node is PanelFieldFocusNode && seen.add(node)) {
      node.unfocus(disposition: UnfocusDisposition.previouslyFocusedChild);
      node = node.enclosingScope?.focusedChild;
    }
  }
}

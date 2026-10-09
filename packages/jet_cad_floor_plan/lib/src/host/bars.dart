// Host embedding API spec C-1 and C-2 (Slice 4 plan, Task 2; S-2, S-19,
// S-20): the two bars a host may keep, reorder, cut down, extend or hide.
// The actions are declared in today's left-to-right order, so the default
// bars are today's, pixel for pixel.
import 'package:flutter/foundation.dart' show immutable, listEquals;
import 'package:flutter/widgets.dart' show Widget;

/// The selection mode's bar buttons (spec C-1), in today's left-to-right
/// order: the history (Undo, Redo), the groups (Merge, Split), the page
/// (Export, Print).
enum FloorPlanServiceAction { undo, redo, merge, split, export, print }

/// The editor's top bar items (spec C-2, S-2), in today's left-to-right
/// order: the buttons Export, Print, Undo and Redo at the left; the
/// read-outs at the right, the object snap's (`snap`, which F3 toggles) and
/// the zoom's (`zoom`). The status line keeps the flexible middle.
enum FloorPlanEditorAction { export, print, undo, redo, snap, zoom }

/// The selection mode's bar (host embedding API spec C-1).
///
/// - [visible]: false removes the bar; the canvas takes its height.
/// - [actions]: the buttons shown, in this order. Today's rules stay inside
///   the subset: Merge shows only with `FloorPlanView.onMergeRequested`,
///   Split only with `onSplitRequested`, Export only with `onExport`. Two
///   shown buttons of different groups (Undo and Redo; Merge and Split;
///   Export and Print) stand 8 logical pixels apart, as today. An action
///   listed twice is an [ArgumentError] when the view builds.
/// - [leading], [trailing]: the host's widgets before and after the
///   buttons, laid out in the bar's row at its height (each needs a
///   bounded width). A host text field there takes the focus and its
///   keystrokes; the bar's chords do not reach the plan from it.
///
/// [actions] shapes the bar only: the chords (Ctrl+Z, Ctrl+E, ...) stay
/// bound whatever it lists (spec S-20).
@immutable
final class FloorPlanServiceBar {
  const FloorPlanServiceBar({
    this.visible = true,
    this.actions = FloorPlanServiceAction.values,
    this.leading = const <Widget>[],
    this.trailing = const <Widget>[],
  });

  final bool visible;
  final List<FloorPlanServiceAction> actions;
  final List<Widget> leading;
  final List<Widget> trailing;

  @override
  bool operator ==(Object other) =>
      other is FloorPlanServiceBar &&
      other.visible == visible &&
      listEquals(other.actions, actions) &&
      listEquals(other.leading, leading) &&
      listEquals(other.trailing, trailing);

  @override
  int get hashCode => Object.hash(visible, Object.hashAll(actions),
      Object.hashAll(leading), Object.hashAll(trailing));

  @override
  String toString() => 'FloorPlanServiceBar(${_differences(
        visible: visible,
        actions: actions,
        defaults: FloorPlanServiceAction.values,
        leading: leading,
        trailing: trailing,
      )})';
}

/// The editor's top bar (host embedding API spec C-2, S-2).
///
/// - [visible]: false removes the bar; the canvas takes its height and the
///   tools stay in the left panel.
/// - [actions]: the items shown, in this order. The buttons (Export,
///   Print, Undo, Redo) lie at the left, after a bare shell's other file
///   commands, with 12 logical pixels between a file button and an edit
///   button; the status line keeps the flexible middle; the read-outs
///   (`snap`, `zoom`) lie at the right, 16 pixels apart. Export shows only
///   with `FloorPlanView.onExport`. An action listed twice is an
///   [ArgumentError] when the view builds.
/// - [leading], [trailing]: the host's widgets at the bar's two ends, laid
///   out in its row at its height (each needs a bounded width). A host
///   text field there takes the focus and its keystrokes: the tool letters
///   and Undo do not reach the plan from it.
///
/// [actions] shapes the bar only: the chords and keys (Ctrl+Z, Ctrl+E,
/// F3, ...) stay bound whatever it lists (spec S-20).
@immutable
final class FloorPlanEditorBar {
  const FloorPlanEditorBar({
    this.visible = true,
    this.actions = FloorPlanEditorAction.values,
    this.leading = const <Widget>[],
    this.trailing = const <Widget>[],
  });

  final bool visible;
  final List<FloorPlanEditorAction> actions;
  final List<Widget> leading;
  final List<Widget> trailing;

  @override
  bool operator ==(Object other) =>
      other is FloorPlanEditorBar &&
      other.visible == visible &&
      listEquals(other.actions, actions) &&
      listEquals(other.leading, leading) &&
      listEquals(other.trailing, trailing);

  @override
  int get hashCode => Object.hash(visible, Object.hashAll(actions),
      Object.hashAll(leading), Object.hashAll(trailing));

  @override
  String toString() => 'FloorPlanEditorBar(${_differences(
        visible: visible,
        actions: actions,
        defaults: FloorPlanEditorAction.values,
        leading: leading,
        trailing: trailing,
      )})';
}

/// The fields of a bar that differ from the default, as `name: value`.
String _differences<T extends Enum>(
        {required bool visible,
        required List<T> actions,
        required List<T> defaults,
        required List<Widget> leading,
        required List<Widget> trailing}) =>
    [
      if (!visible) 'visible: false',
      if (!listEquals(actions, defaults))
        'actions: [${actions.map((a) => a.name).join(', ')}]',
      if (leading.isNotEmpty)
        'leading: [${leading.map((w) => w.toStringShort()).join(', ')}]',
      if (trailing.isNotEmpty)
        'trailing: [${trailing.map((w) => w.toStringShort()).join(', ')}]',
    ].join(', ');

/// Throws an [ArgumentError] naming `actions` for a bar that lists an
/// action twice (spec C-1, C-2); called when the view builds, as
/// `validateOverlayLayout` is.
void validateBars(FloorPlanServiceBar service, FloorPlanEditorBar editor) {
  void unique<T>(List<T> actions) {
    if (actions.toSet().length != actions.length) {
      throw ArgumentError.value(
          actions, 'actions', 'must not list an action twice');
    }
  }

  unique(service.actions);
  unique(editor.actions);
}

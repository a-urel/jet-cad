// 2a spec P2 (`PlanEditor(bar:)`, today's `editorBar`): the editor's top
// bar a host may keep, reorder, cut down, extend or hide. Ported from
// jet_cad_floor_plan/lib/src/host/bars.dart (the editor half, :13-17,
// :73-159; the service bar is 2b's).
import 'package:flutter/foundation.dart' show immutable, listEquals;
import 'package:flutter/widgets.dart' show Widget;

/// The editor's top bar items, in today's left-to-right order: the buttons
/// Export, Print, Undo and Redo at the left; the read-outs at the right,
/// the object snap's (`snap`, which F3 toggles) and the zoom's (`zoom`).
/// The status line keeps the flexible middle.
enum PlanEditorAction { export, print, undo, redo, snap, zoom }

/// The editor's top bar.
///
/// - [visible]: false removes the bar; the canvas takes its height and the
///   tools stay in the left panel.
/// - [actions]: the items shown, in this order. The buttons lie at the
///   left, after the host's file commands, with 12 logical pixels between
///   a file button and an edit button; the read-outs lie at the right, 16
///   pixels apart. Export shows only with `PlanEditor.onExport`. An action
///   listed twice is an [ArgumentError] when the editor builds.
/// - [leading], [trailing]: the host's widgets at the bar's two ends, laid
///   out in its row at its height (each needs a bounded width). A host
///   text field there takes the focus and its keystrokes: the tool
///   letters, Undo, Redo and Escape stay in the field; the file chords and
///   F3 still act on the plan from it.
///
/// [actions] shapes the bar only: the chords and keys stay bound whatever
/// it lists.
@immutable
final class PlanEditorBar {
  const PlanEditorBar({
    this.visible = true,
    this.actions = PlanEditorAction.values,
    this.leading = const <Widget>[],
    this.trailing = const <Widget>[],
  });

  final bool visible;
  final List<PlanEditorAction> actions;
  final List<Widget> leading;
  final List<Widget> trailing;

  @override
  bool operator ==(Object other) =>
      other is PlanEditorBar &&
      other.visible == visible &&
      listEquals(other.actions, actions) &&
      listEquals(other.leading, leading) &&
      listEquals(other.trailing, trailing);

  @override
  int get hashCode => Object.hash(visible, Object.hashAll(actions),
      Object.hashAll(leading), Object.hashAll(trailing));

  @override
  String toString() => 'PlanEditorBar(${[
        if (!visible) 'visible: false',
        if (!listEquals(actions, PlanEditorAction.values))
          'actions: [${actions.map((a) => a.name).join(', ')}]',
        if (leading.isNotEmpty)
          'leading: [${leading.map((w) => w.toStringShort()).join(', ')}]',
        if (trailing.isNotEmpty)
          'trailing: [${trailing.map((w) => w.toStringShort()).join(', ')}]',
      ].join(', ')})';
}

/// Throws an [ArgumentError] naming `actions` for a bar that lists an
/// action twice; called when the editor builds (bars.dart:146-159).
void validatePlanEditorBar(PlanEditorBar bar) {
  if (bar.actions.toSet().length != bar.actions.length) {
    throw ArgumentError.value(
        bar.actions, 'actions', 'must not list an action twice');
  }
}

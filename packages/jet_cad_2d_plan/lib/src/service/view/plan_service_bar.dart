// 2b spec S4 ("The service bar") and S5 (`serviceBar` → PlanServiceBar):
// the service mode's bar a host may keep, reorder, cut down, extend or
// hide. Ported from jet_cad_floor_plan/lib/src/host/bars.dart (the service
// half, :8-11, :19-71, :129-159).
import 'package:flutter/foundation.dart' show immutable, listEquals;
import 'package:flutter/widgets.dart' show Widget;

/// The bar's height with no theme, in logical pixels (today's
/// `kServiceBarHeight`, service_view.dart:120); `PlanTheme.serviceBarHeight`
/// overrides it.
const double kServiceBarHeight = 44;

/// The service bar's buttons, in today's left-to-right order: the history
/// (Undo, Redo, and the alignment guides' toggle), the groups (Merge, Split), the page (Export, Print).
enum PlanServiceAction { undo, redo, guides, merge, split, export, print }

/// The service mode's bar.
///
/// - [visible]: false removes the bar; the canvas takes its height.
/// - [actions]: the buttons shown, in this order. Today's rules stay inside
///   the subset: Merge shows only with `PlanServiceView.onMergeRequested`
///   and Split only with `onSplitRequested`, both only while
///   `PlanPermissions.serviceMerge`; Export only with `onExport`. Two shown
///   buttons of different groups stand 8 logical pixels apart. An action
///   listed twice is an [ArgumentError] when the view builds.
/// - [leading], [trailing]: the host's widgets before and after the
///   buttons, laid out in the bar's row at its height (each needs a
///   bounded width). A host text field there takes the focus and its
///   keystrokes: Undo and Redo stay in the field; Export's and Print's
///   chords still reach the plan from it.
///
/// [actions] shapes the bar only: the chords stay bound whatever it lists.
@immutable
final class PlanServiceBar {
  const PlanServiceBar({
    this.visible = true,
    this.actions = PlanServiceAction.values,
    this.leading = const <Widget>[],
    this.trailing = const <Widget>[],
  });

  final bool visible;
  final List<PlanServiceAction> actions;
  final List<Widget> leading;
  final List<Widget> trailing;

  @override
  bool operator ==(Object other) =>
      other is PlanServiceBar &&
      other.visible == visible &&
      listEquals(other.actions, actions) &&
      listEquals(other.leading, leading) &&
      listEquals(other.trailing, trailing);

  @override
  int get hashCode => Object.hash(visible, Object.hashAll(actions),
      Object.hashAll(leading), Object.hashAll(trailing));

  @override
  String toString() => 'PlanServiceBar(${[
        if (!visible) 'visible: false',
        if (!listEquals(actions, PlanServiceAction.values))
          'actions: [${actions.map((a) => a.name).join(', ')}]',
        if (leading.isNotEmpty)
          'leading: [${leading.map((w) => w.toStringShort()).join(', ')}]',
        if (trailing.isNotEmpty)
          'trailing: [${trailing.map((w) => w.toStringShort()).join(', ')}]',
      ].join(', ')})';
}

/// Throws an [ArgumentError] naming `actions` for a bar that lists an
/// action twice (bars.dart:146-159); called when the view builds.
void validatePlanServiceBar(PlanServiceBar bar) {
  if (bar.actions.toSet().length != bar.actions.length) {
    throw ArgumentError.value(
        bar.actions, 'actions', 'must not list an action twice');
  }
}

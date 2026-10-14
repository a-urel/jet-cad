// The design composition a host builds from the widgets (spec 2a P2): the
// keyboard around a status line, the palette, the canvas and an optional
// right column, over one controller, under the drawing fixture's rotated,
// zoomed camera (canvas_fixture.dart's pumpDraw). A host's own bindings
// sit above it and count every key that reaches them. The status line is
// the active tool's palette label (today's status text, less the
// selection count, which is Task 20's bar).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart'
    show InteractionLayer;
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:jet_cad_2d_plan/src/editor/plan_tool_palette.dart'
    show planToolLabel;

import 'canvas_fixture.dart';

/// What the host saw: the keys that reached its bindings, by name, and its
/// file callbacks' calls.
final class Design {
  Design(this.c, bool shortcuts) : shortcuts = ValueNotifier(shortcuts);

  final PlanController c;

  /// `PlanShortcuts.shortcuts`, changeable at runtime.
  final ValueNotifier<bool> shortcuts;
  final Map<String, int> reached = {};
  int news = 0, opens = 0, saves = 0, saveAses = 0, exports = 0, prints = 0;
}

/// Pumps the composition over [c]: [hostKeys] are the host's bindings
/// above the plan (by name); [hostField] puts a host text field, guarded
/// as a host guards its own fields, beside the status line; [right] is the
/// right column (Task 17's property panel); [host] wraps the plan in a
/// host's own `Shortcuts`/`Actions`/`Focus`.
Future<Design> pumpDesign(WidgetTester tester, PlanController c,
    {bool shortcuts = true,
    Map<String, SingleActivator> hostKeys = const {},
    bool hostField = false,
    Widget? right,
    Widget Function(Widget plan)? host}) async {
  final d = Design(c, shortcuts);
  addTearDown(d.shortcuts.dispose);
  for (final name in hostKeys.keys) {
    d.reached[name] = 0;
  }
  Widget frame(Widget canvas) {
    final plan = ValueListenableBuilder<bool>(
      valueListenable: d.shortcuts,
      builder: (_, keys, __) => PlanShortcuts(
        controller: c,
        shortcuts: keys,
        onNew: () async => d.news++,
        onOpen: () async => d.opens++,
        onSave: () async => d.saves++,
        onSaveAs: () async => d.saveAses++,
        onExport: () async => d.exports++,
        onPrint: () async => d.prints++,
        child: Column(children: [
          SizedBox(
            height: 40,
            child: Row(children: [
              Expanded(child: StatusLine(controller: c)),
              if (hostField)
                SizedBox(
                    width: 160,
                    child: PlanShortcutGuard(
                        controller: c,
                        child: const TextField(key: Key('host-field')))),
            ]),
          ),
          Expanded(
            child: Row(children: [
              SizedBox(width: 240, child: PlanToolPalette(controller: c)),
              Expanded(child: canvas),
              if (right != null)
                SizedBox(
                    width: 280, child: SingleChildScrollView(child: right)),
            ]),
          ),
        ]),
      ),
    );
    final hosted = host?.call(plan) ?? plan;
    return CallbackShortcuts(
      bindings: {
        for (final MapEntry(key: name, value: chord) in hostKeys.entries)
          chord: () => d.reached[name] = d.reached[name]! + 1,
      },
      child: hosted,
    );
  }

  await pumpDraw(tester, c, frame: frame);
  return d;
}

/// The active tool's palette label, keyed `status-text`.
class StatusLine extends StatelessWidget {
  const StatusLine({super.key, required this.controller});

  final PlanController controller;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<String>(
        valueListenable: controller.activeTool,
        builder: (context, id, _) => Text(
            planToolLabel(context, controller, id),
            key: const Key('status-text')),
      );
}

/// `planner_draw_test.dart`'s `status` (`:60-61`).
String status(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const Key('status-text'))).data!;

/// `planner_draw_test.dart`'s `press` (`:63-67`): whether a handler took
/// the key.
Future<bool> press(WidgetTester tester, LogicalKeyboardKey key) async {
  final handled = await tester.sendKeyEvent(key);
  await tester.pump();
  return handled;
}

/// `keyboard_focus_test.dart`'s `sendActivator` (`:242-252`): [a]'s
/// modifiers down around its key.
Future<void> sendActivator(WidgetTester tester, SingleActivator a) async {
  if (a.control) await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  if (a.meta) await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
  if (a.shift) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
  await tester.sendKeyEvent(a.trigger);
  if (a.shift) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
  if (a.meta) await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
  if (a.control) await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await tester.pump();
}

/// The canvas's own focus node: the `Focus` the `InteractionLayer` builds.
FocusNode canvasFocus(WidgetTester tester) => tester
    .widget<Focus>(find
        .descendant(
            of: find.byType(InteractionLayer), matching: find.byType(Focus))
        .first)
    .focusNode!;

/// A click a little inside the canvas's top left (empty paper under the
/// fixture's camera): the canvas takes the focus.
Future<void> focusCanvas(WidgetTester tester) async {
  await tester.tapAt(
      tester.getTopLeft(find.byType(InteractionLayer)) + const Offset(6, 6));
  await tester.pump();
  expect(FocusManager.instance.primaryFocus, same(canvasFocus(tester)),
      reason: 'premise: the canvas focused');
}

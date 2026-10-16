// The demo's own keys, while the plan's are off (`PlanEditor.shortcuts:
// false` gives every key to the host): Undo, Redo, Delete and Escape call
// the controller's commands. A key typed into a text field inside the view
// (the inspector, the editor's panels) never gets here: the view keeps it
// for the field.
import 'package:flutter/services.dart'
    show HardwareKeyboard, KeyEvent, LogicalKeyboardKey;
import 'package:flutter/widgets.dart' show SingleActivator;
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';

/// The keys and what they call; the name is what the log shows.
List<(SingleActivator, String, void Function())> demoKeys(PlanController c) => [
      (
        const SingleActivator(LogicalKeyboardKey.keyZ, control: true),
        'Ctrl+Z',
        c.undo
      ),
      (
        const SingleActivator(LogicalKeyboardKey.keyZ, meta: true),
        'Cmd+Z',
        c.undo
      ),
      (
        const SingleActivator(LogicalKeyboardKey.keyY, control: true),
        'Ctrl+Y',
        c.redo
      ),
      (
        const SingleActivator(LogicalKeyboardKey.keyZ,
            control: true, shift: true),
        'Ctrl+Shift+Z',
        c.redo
      ),
      (
        const SingleActivator(LogicalKeyboardKey.keyZ, meta: true, shift: true),
        'Cmd+Shift+Z',
        c.redo
      ),
      // The planner's Delete has no other path: the command deletes the
      // editor's selection, as the key would.
      (
        const SingleActivator(LogicalKeyboardKey.delete),
        'Delete',
        c.deleteSelection
      ),
      (
        const SingleActivator(LogicalKeyboardKey.backspace),
        'Backspace',
        c.deleteSelection
      ),
      // Escape: back to the Select tool, then no selection.
      (
        const SingleActivator(LogicalKeyboardKey.escape),
        'Escape',
        () {
          final design = c.mode.value == PlanMode.design;
          if (design && c.activeTool.value != PlanToolIds.select) {
            c.selectTool(PlanToolIds.select);
          } else {
            c.select(const {});
          }
        }
      ),
    ];

/// Runs the key [event] stands for on [c], and returns its name; null when
/// it is none of them.
String? runDemoKey(PlanController c, KeyEvent event) {
  for (final (activator, name, command) in demoKeys(c)) {
    if (activator.accepts(event, HardwareKeyboard.instance)) {
      command();
      return name;
    }
  }
  return null;
}

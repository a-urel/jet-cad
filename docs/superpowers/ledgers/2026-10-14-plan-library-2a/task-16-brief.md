### Task 16: `PlanToolPalette` and `PlanShortcuts` (spec P2 "The keyboard", "The widgets", "Permissions")

**Files:**
- Create: `packages/jet_cad_2d_plan/lib/src/shortcuts/tool_letters.dart` (new: `PlanToolEntry`, `planToolEntries`)
- Create: `packages/jet_cad_2d_plan/lib/src/shortcuts/plan_shortcuts.dart` (new, with the binding rules ported from `planner_shell.dart:1444-1469`)
- Create: `packages/jet_cad_2d_plan/lib/src/editor/plan_tool_palette.dart` (port of `tool_palette.dart`, plus `planToolLabel`)
- Modify: `packages/jet_cad_2d_plan/lib/src/shortcuts/plan_shortcut_guard.dart` (Task 15: `planLetterKeys` becomes the letters in use)
- Modify: `packages/jet_cad_2d_plan/lib/src/controller/plan_controller.dart` (the letters at construction)
- Modify: `packages/jet_cad_2d_plan/lib/jet_cad_2d_plan.dart` (export `PlanToolPalette`, `PlanShortcuts`, `PlanShortcutGuard`)
- Test support: `packages/jet_cad_2d_plan/test/support/stamp_kit.dart`, `test/support/design_harness.dart` (Task 17 reuses both)
- Test (new): `packages/jet_cad_2d_plan/test/shortcuts/plan_shortcuts_test.dart` (KB-1 … KB-6, KB-10), `test/editor/plan_tool_palette_test.dart` (KB-7 … KB-9)
- Test (ported): `packages/jet_cad_2d_plan/test/editor/palette_draw_test.dart`, `test/shortcuts/host_text_keys_test.dart`

(All paths below are under `packages/jet_cad_2d_plan/` unless they start at the repository root. "`floor_plan/`" abbreviates `packages/jet_cad_floor_plan/`.)

**Interfaces:**
- Consumes:
  - `PlanKit.tools`, `PlanTool` (`id`, `icon`, `letter`, `needs`), `KitNames.word`, `kitOfKey`, `KitDiagnostic`, `KitDiagnosticCode.letterTaken` from `package:jet_cad_2d_kit/jet_cad_2d_kit.dart` (Task 4 and sub-project 1).
  - Task 15: `PlanCanvas`, `PlanShortcutGuard`, `PlanTextKeys`, `letterKey`, the chords (`lib/src/shortcuts/plan_shortcut_guard.dart`, which re-exports `chords.dart`), and the test fixture `test/support/canvas_fixture.dart` (`drawController`, `pumpDraw`, `globalOf`, `bytes`, `withoutSeed`, `ofKind`, `entryEditable`, `activeTool`).
  - Task 12: `PlanToolIds`, `genericTools` (`GenericTool`: `id`, `icon`, `letter`, `needs`, `fills`), `PlanPermissions` (`allowsTool`, `undo`, `export`, `print`), and on `PlanController`: `permissions` (get, set; a set notifies), `fill`, `selectGates` (`PlanSelectGates.idleKeys`), `needsOf(String)`.
  - Tasks 8, 9: see "Assumed from earlier tasks".
- Produces:
  - Exported from the barrel:
    - `class PlanToolPalette extends StatefulWidget` — `const PlanToolPalette({Key? key, required PlanController controller})`.
    - `class PlanShortcuts extends StatefulWidget` — `const PlanShortcuts({Key? key, required PlanController controller, required Widget child, bool shortcuts = true, Future<void> Function()? onNew, Future<void> Function()? onOpen, Future<void> Function()? onSave, Future<void> Function()? onSaveAs, Future<void> Function()? onExport, Future<void> Function()? onPrint})`.
    - `PlanShortcutGuard` (Task 15's), so a host that composes its own layout guards its own text fields.
  - Internal: `final class PlanToolEntry` (`id`, `kitId`, `icon`, `needs`, `letter`, `key`); `List<PlanToolEntry> planToolEntries(PlanController controller)`; `const String kPlanKitId = 'plan'`; `String planToolLabel(BuildContext context, PlanController controller, String toolId)` (Task 20's status line reuses it); `bool fillOffered(PlanController controller)`; `planLetterKeys` now returns the letters in use.

Plan decision (**the letters are the controller's**): which tool has which letter depends only on the kit set, which a controller fixes at construction. `planToolEntries(controller)` computes the entries once per controller (an `Expando`), and the controller's constructor calls it, so a `letterTaken` diagnostic (spec P2, A3) is in `controller.diagnostics` before any widget is built. The palette, `PlanShortcuts` and every guard read the same list.

Plan decision (**which letters**): the generic tools keep V L P R C A T (Task 12's `genericTools`); F is reserved for Fill whether or not Fill is offered; a kit tool's `letter` is upper-cased, and must then be one Latin letter A-Z. A kit tool asking for a letter already given (to a generic tool or an earlier kit's tool), for F, or for something that is no letter, gets none and one `letterTaken` diagnostic (subject: the tool id; the message names the owner). Keys a tool handles itself while active (Enter, Delete, R and M of `plan.symbol`) are not letters and never conflict (spec P2).

Plan decision (**the binding rules**, today's, `planner_shell.dart:1444-1469`, with the capabilities read from `PlanPermissions`):
- `shortcuts: false` binds nothing and closes the select tool's idle keys (`PlanSelectGates.idleKeys`, Task 12), so every key reaches the host (host embedding spec C-7, S-16). The setting is re-applied after every document swap, since the gates are per document.
- File chords (New, Open, Save, Save As) are bound when the host gave the callback; Export and Print also need their flag. A bound chord whose command cannot act now (a shape part-way, or no page for Export and Print) consumes the key and does nothing (S-26).
- Undo and Redo are bound while `permissions.undo`; they call `controller.undo()` / `redo()`, which do nothing mid-shape (Task 8).
- F3 is bound while `controller.snappingAllowed` (Task 8's flag, written by Task 15's canvas); F while a fill tool is offered (`polyline`, `rectangle`, `circle`), toggling only while geometry is allowed; Escape always, arming `plan.select` from an idle tool.
- A letter is bound while its tool is allowed by `permissions.allowsTool`; `controller.selectTool` still refuses a tool whose needs the document's permissions refuse (Task 12), as today's `_activate` refused it under `runtime`.

Plan decision (**the palette's rows**): the generic tools, then each kit's tools in load order, a `Divider` keyed `tool-group-<kit id>` before each kit's group; each row keyed `tool-<tool id>`, with the tool's icon, its label (`planToolLabel`: `PlanStrings` for the generic ids, the kit's `tool:<id>` word in `controller.locale` with English fallback, the id as the last resort), its letter, selected while it is the active tool, enabled exactly when `selectTool` would arm it (allowed by the permissions, and every need allowed by the document's engine permissions, Task 12's `_allowsTool` rule over `needsOf`). The Fill row follows (`tool-fill`), shown while a fill tool is offered. The palette never takes focus (`ExcludeFocus`, Ruling 05-6) and pushes the locale (Task 9's `PlanLocaleScope`).

Ported tests and where the others go: `floor_plan/test/planner_draw_test.dart`'s palette and keyboard cases come here (Step 13); its page-panel cases (`A9`, `A14`, `A15`, `A18`, `A19`, `A23`-`A26`) need the Page panel and go to Task 18; `A16` and `A27` read the bar's OSNAP and zoom read-outs (Task 20); `A7`, `A17`, `A20`-`A22` are Task 15's. `floor_plan/test/host/keyboard_focus_test.dart` drives tables, `tablesOnly`, the Wall tool and `FloorPlanView`'s two modes: its generic behaviours are pinned here by new tests modelled on it (KB-3 on T6-b, KB-4 on "a gesture's keys stay", KB-10 on T6-a), with their own named mutations; its table and service cases are 2b's. `floor_plan/test/host/host_text_keys_test.dart`: the host-field cases are ported (Step 13); its panel-field cases go with their panels (Tasks 13, 17, 18); "the canvas focused: Delete, Backspace, W, K, 1, Space and Enter each fire the host's intent" asserts a table selection and is covered by KB-3. `floor_plan/test/planner_palette_test.dart` (the canvas's colour palettes) is Task 15's.

- [ ] **Step 1: The kits.** Create `test/support/stamp_kit.dart`:

```dart
// Kits of tools only, for the keyboard and the palette (2a Task 16).
// stamp.star asks for B (free); stamp.clash for L (plan.line's); stamp.fill
// for "f" (F is Fill's: asked in lower case, so the check runs on the upper
// case); stamp.none for no letter. late.star, in a later kit, asks for B,
// which stamp.star already has. Turkish names one tool; German names none
// (the English fallback).
import 'package:flutter/material.dart' show Icons;
import 'package:jet_cad_2d/jet_cad_2d.dart' show Capability;
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart' show LineTool;
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';

const Set<Capability> _draws = {Capability.geometry};

final PlanKit stampKit = PlanKit(
  id: 'stamp',
  version: '1.0.0',
  tools: [
    PlanTool(
        id: 'stamp.star',
        icon: Icons.star,
        letter: 'B',
        needs: _draws,
        create: (_) => LineTool()),
    PlanTool(
        id: 'stamp.clash',
        icon: Icons.warning_amber,
        letter: 'L',
        needs: _draws,
        create: (_) => LineTool()),
    PlanTool(
        id: 'stamp.fill',
        icon: Icons.format_color_fill,
        letter: 'f',
        needs: _draws,
        create: (_) => LineTool()),
    PlanTool(
        id: 'stamp.none',
        icon: Icons.circle_outlined,
        needs: _draws,
        create: (_) => LineTool()),
  ],
  names: const KitNames({
    'en': {
      'tool:stamp.star': 'Star',
      'tool:stamp.clash': 'Clash',
      'tool:stamp.fill': 'Filler',
      'tool:stamp.none': 'Plain',
    },
    'tr': {'tool:stamp.star': 'Yıldız'},
  }),
);

final PlanKit lateKit = PlanKit(
  id: 'late',
  version: '1.0.0',
  tools: [
    PlanTool(
        id: 'late.star',
        icon: Icons.star_border,
        letter: 'B',
        needs: _draws,
        create: (_) => LineTool()),
  ],
  names: const KitNames({
    'en': {'tool:late.star': 'Late star'},
  }),
);
```

- [ ] **Step 2: The harness.** Create `test/support/design_harness.dart`:

```dart
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
  await tester
      .tapAt(tester.getTopLeft(find.byType(InteractionLayer)) + const Offset(6, 6));
  await tester.pump();
  expect(FocusManager.instance.primaryFocus, same(canvasFocus(tester)),
      reason: 'premise: the canvas focused');
}
```

- [ ] **Step 3: The keyboard tests.** Create `test/shortcuts/plan_shortcuts_test.dart`:

```dart
// Spec 2a P2, "The keyboard": the generic letters, then the kits' in load
// order, F reserved, a taken letter a diagnostic (A3); the guard built
// from the letters in use; shortcuts: false; Escape; Undo and Redo under
// the permissions; the host's file callbacks; autofocus. Over the drawing
// fixture (a 1:20 page at (7000, 3000), one line, a rotated, zoomed camera)
// with the stamp kits (stamp_kit.dart).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart' show SelectionKey;
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:jet_cad_2d_plan/src/shortcuts/plan_shortcut_guard.dart';
import 'package:jet_cad_2d_plan/src/shortcuts/tool_letters.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/canvas_fixture.dart';
import '../support/design_harness.dart';
import '../support/stamp_kit.dart';

/// The host's keys, by name.
const Map<String, SingleActivator> kHostKeys = {
  'l': SingleActivator(LogicalKeyboardKey.keyL),
  'b': SingleActivator(LogicalKeyboardKey.keyB),
  'f': SingleActivator(LogicalKeyboardKey.keyF),
  'f3': SingleActivator(LogicalKeyboardKey.f3),
  'escape': SingleActivator(LogicalKeyboardKey.escape),
  'delete': SingleActivator(LogicalKeyboardKey.delete),
  'ctrl+z': SingleActivator(LogicalKeyboardKey.keyZ, control: true),
  'ctrl+y': SingleActivator(LogicalKeyboardKey.keyY, control: true),
  'ctrl+n': SingleActivator(LogicalKeyboardKey.keyN, control: true),
  'ctrl+s': SingleActivator(LogicalKeyboardKey.keyS, control: true),
  'ctrl+e': SingleActivator(LogicalKeyboardKey.keyE, control: true),
  'ctrl+p': SingleActivator(LogicalKeyboardKey.keyP, control: true),
};

/// One more line on [c]'s plan, off the fixture's, one undo step.
void drawALine(PlanController c) => c.document.commands.execute(addDrafted(
    c.document,
    EntityKind.line,
    linePayload(Vector2(7020.5, 3030.25), Vector2(7080.5, 3061.75)),
    layer: ReservedHandles.layerZero));

void main() {
  testWidgets(
      'KB-1 the generic letters, then the kits\' in load order; a taken '
      'letter, F and a later kit\'s B go to no tool, each a letterTaken '
      'diagnostic at construction (M-KB-1a, M-KB-1b, M-KB-1c)',
      (tester) async {
    final c = PlanController(kits: [stampKit, lateKit]);
    addTearDown(c.dispose);
    // Before any widget is built.
    expect(
        {
          for (final d in c.diagnostics.value)
            if (d.code == KitDiagnosticCode.letterTaken) d.subject
        },
        {'stamp.clash', 'stamp.fill', 'late.star'});
    final entries = planToolEntries(c);
    expect([for (final e in entries) e.id], [
      'plan.select',
      'plan.line',
      'plan.polyline',
      'plan.rectangle',
      'plan.circle',
      'plan.arc',
      'plan.text',
      'stamp.star',
      'stamp.clash',
      'stamp.fill',
      'stamp.none',
      'late.star',
    ]);
    expect([for (final e in entries) e.letter],
        ['V', 'L', 'P', 'R', 'C', 'A', 'T', 'B', null, null, null, null]);
    expect(planLetterKeys(c), [
      for (final l in 'VLPRCATB'.split('')) letterKey(l),
      LogicalKeyboardKey.keyF,
    ]);
    expect(identical(planToolEntries(c), entries), isTrue,
        reason: 'once per controller');
  });

  testWidgets(
      'KB-2 a kit\'s letter typed into a guarded field reaches the text input '
      'and arms nothing; on the canvas it arms the kit\'s tool (M-KB-2)',
      (tester) async {
    final c = PlanController(kits: [stampKit]);
    addTearDown(c.dispose);
    await pumpDesign(tester, c, hostField: true);
    await tester.tap(find.byKey(const Key('host-field')));
    await tester.pump();
    expect(await press(tester, LogicalKeyboardKey.keyB), isFalse,
        reason: 'B goes to the platform as text');
    expect(c.activeTool.value, 'plan.select');
    await focusCanvas(tester);
    expect(await press(tester, LogicalKeyboardKey.keyB), isTrue);
    expect(c.activeTool.value, 'stamp.star');
    expect(status(tester), 'Star');
  });

  testWidgets(
      'KB-3 shortcuts: false, the canvas focused: a letter, F3, F, Escape, '
      'Delete, Undo and the file chords reach the host; the tool, OSNAP, '
      'Fill, the selection and the history are kept. With shortcuts the '
      'plan takes each (M-KB-3a, M-KB-3b)', (tester) async {
    final f = drawController();
    final c = f.c;
    final d =
        await pumpDesign(tester, c, shortcuts: false, hostKeys: kHostKeys);
    await focusCanvas(tester);
    drawALine(c);
    c.selection.replace([SelectionKey.root(f.line)]);
    await tester.pump();
    final before = bytes(c);
    final osnap = c.snap.objectSnap;
    final fill = c.fill.value;
    const sent = ['l', 'f3', 'f', 'escape', 'delete', 'ctrl+z', 'ctrl+s'];
    for (final k in sent) {
      await sendActivator(tester, kHostKeys[k]!);
      expect(d.reached[k], 1, reason: k);
    }
    expect(bytes(c), before, reason: 'nothing deleted, nothing undone');
    expect(c.activeTool.value, 'plan.select');
    expect(c.snap.objectSnap, osnap);
    expect(c.fill.value, fill);
    expect(c.selection.keys, [SelectionKey.root(f.line)],
        reason: 'the idle Escape bubbled');
    expect(d.saves, 0);

    // The control: the plan binds them all.
    d.shortcuts.value = true;
    await tester.pump();
    await sendActivator(tester, kHostKeys['f3']!);
    expect(c.snap.objectSnap, isNot(osnap));
    await sendActivator(tester, kHostKeys['f']!);
    expect(c.fill.value, isNot(fill));
    await sendActivator(tester, kHostKeys['ctrl+z']!);
    expect(bytes(c), isNot(before), reason: 'undone');
    await sendActivator(tester, kHostKeys['ctrl+s']!);
    expect(d.saves, 1);
    await sendActivator(tester, kHostKeys['l']!);
    expect(c.activeTool.value, 'plan.line');
    await sendActivator(tester, kHostKeys['escape']!);
    expect(c.activeTool.value, 'plan.select');
    for (final k in sent) {
      expect(d.reached[k], 1, reason: '$k: the host heard nothing more');
    }
  });

  testWidgets(
      'KB-4 an idle drawing tool\'s Escape arms plan.select; part-way, the '
      'Escape is the tool\'s and a host\'s undo() waits (M-KB-4)',
      (tester) async {
    final c = drawController().c;
    await pumpDesign(tester, c);
    await focusCanvas(tester);
    drawALine(c);
    final depth = c.document.commands.undoDepth;
    await press(tester, LogicalKeyboardKey.keyP);
    await tester.tapAt(globalOf(tester, c, 7010, 3020));
    await tester.tapAt(globalOf(tester, c, 7060, 3090));
    await tester.pump();
    expect(activeTool(c).isMidShape, isTrue, reason: 'premise: part-way');
    c.undo();
    expect(c.document.commands.undoDepth, depth, reason: 'mid-shape: no undo');
    await press(tester, LogicalKeyboardKey.escape);
    expect(activeTool(c).isMidShape, isFalse, reason: 'the shape dropped');
    expect(c.activeTool.value, 'plan.polyline', reason: 'the tool stays');
    await press(tester, LogicalKeyboardKey.escape);
    expect(c.activeTool.value, 'plan.select');
    c.undo();
    expect(c.document.commands.undoDepth, depth - 1, reason: 'idle: undo acts');
  });

  testWidgets(
      'KB-5 undo: false unbinds Undo and Redo: the chord reaches the host and '
      'the step stays; a host\'s undo() still undoes; undo: true binds them '
      'again (M-KB-5)', (tester) async {
    final c = drawController().c;
    final d = await pumpDesign(tester, c, hostKeys: kHostKeys);
    await focusCanvas(tester);
    drawALine(c);
    final depth = c.document.commands.undoDepth;
    c.permissions = PlanPermissions.full.copyWith(undo: false);
    await tester.pump();
    await sendActivator(tester, kHostKeys['ctrl+z']!);
    expect(d.reached['ctrl+z'], 1);
    expect(c.document.commands.undoDepth, depth);
    c.undo();
    expect(c.document.commands.undoDepth, depth - 1,
        reason: 'host calls are not gated (spec P2)');
    c.redo();
    c.permissions = PlanPermissions.full;
    await tester.pump();
    await sendActivator(tester, kHostKeys['ctrl+z']!);
    expect(c.document.commands.undoDepth, depth - 1);
    await sendActivator(tester, kHostKeys['ctrl+y']!);
    expect(c.document.commands.undoDepth, depth);
    expect(d.reached['ctrl+z'], 1);
    expect(d.reached['ctrl+y'], 0);
  });

  testWidgets(
      'KB-6 the file chords call the host\'s callbacks; Export and Print are '
      'refused with no page but keep their key; export: false lets Ctrl+E '
      'reach the host (M-KB-6a, M-KB-6b)', (tester) async {
    final c = drawController().c;
    final d = await pumpDesign(tester, c, hostKeys: kHostKeys);
    await focusCanvas(tester);
    for (final k in ['ctrl+n', 'ctrl+s', 'ctrl+e', 'ctrl+p']) {
      await sendActivator(tester, kHostKeys[k]!);
    }
    await sendActivator(tester,
        const SingleActivator(LogicalKeyboardKey.keyO, control: true));
    await sendActivator(
        tester,
        const SingleActivator(LogicalKeyboardKey.keyS,
            control: true, shift: true));
    expect([d.news, d.opens, d.saves, d.saveAses, d.exports, d.prints],
        [1, 1, 1, 1, 1, 1]);
    expect(d.reached['ctrl+e'], 0);

    // No page: the commands cannot act, their keys stay the plan's (S-26).
    c.document.commands.execute(
        SetComponentCommand<PageComponent>(c.document.rootHandle, null));
    await tester.pump();
    expect(c.page.value, isNull, reason: 'premise: no page');
    await sendActivator(tester, kHostKeys['ctrl+e']!);
    await sendActivator(tester, kHostKeys['ctrl+p']!);
    expect([d.exports, d.prints], [1, 1]);
    expect([d.reached['ctrl+e'], d.reached['ctrl+p']], [0, 0]);

    c.permissions = PlanPermissions.full.copyWith(export: false);
    await tester.pump();
    await sendActivator(tester, kHostKeys['ctrl+e']!);
    expect(d.reached['ctrl+e'], 1);
    expect(d.reached['ctrl+p'], 0);
  });

  testWidgets(
      'KB-10 autofocus: with it the canvas takes the focus from a host field '
      'mounted in the same frame; without it the field keeps it and a click '
      'on the canvas takes it (T6-a) (M-KB-10)', (tester) async {
    final c = drawController().c;
    Future<FocusNode> sameFrame({required bool autofocus}) async {
      final field = FocusNode(debugLabel: 'host-field');
      addTearDown(field.dispose);
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: Column(children: [
        Expanded(child: PlanCanvas(controller: c, autofocus: autofocus)),
        SizedBox(
            height: 48,
            child: TextField(
                key: const Key('host-field'),
                onTapOutside: (_) {},
                focusNode: field,
                autofocus: true)),
      ]))));
      await tester.pump();
      await tester.pump();
      return field;
    }

    final control = await sameFrame(autofocus: true);
    expect(FocusManager.instance.primaryFocus, isNot(same(control)),
        reason: 'the control: the canvas');
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    final field = await sameFrame(autofocus: false);
    expect(FocusManager.instance.primaryFocus, same(field));
    await focusCanvas(tester);
  });
}
```

- [ ] **Step 4: The palette tests.** Create `test/editor/plan_tool_palette_test.dart`:

```dart
// Spec 2a P2, "The widgets": PlanToolPalette alone, with only a
// controller: the generic tools, then each kit's in load order, grouped;
// labels from tool:<id> in the controller's locale, English where the kit
// has no word; rows disabled by the permissions, letters unbound with
// them; the Fill row while a fill tool is offered.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';

import '../support/canvas_fixture.dart';
import '../support/design_harness.dart';
import '../support/stamp_kit.dart';

/// The palette's tool rows' keys, in order (the Fill toggle's inner
/// ListTile carries no key).
List<String> rowKeys(WidgetTester tester) => [
      for (final t in tester.widgetList<ListTile>(find.descendant(
          of: find.byType(PlanToolPalette), matching: find.byType(ListTile))))
        if (t.key case final ValueKey<String> k) k.value,
    ];

bool enabled(WidgetTester tester, String key) =>
    tester.widget<ListTile>(find.byKey(Key(key))).enabled;

void main() {
  testWidgets(
      'KB-7 the generic tools, then each kit\'s in load order, a divider '
      'before each kit; a kit row reads tool:<id> in the locale, English '
      'without a word; the letter is the trailing text (M-KB-7a, M-KB-7b)',
      (tester) async {
    final c = PlanController(kits: [stampKit, lateKit]);
    addTearDown(c.dispose);
    Future<void> pumpIn(Locale locale) async {
      await tester.pumpWidget(MaterialApp(
          locale: locale,
          supportedLocales: const [Locale('en'), Locale('de'), Locale('tr')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: Scaffold(
              body: SizedBox(
                  width: 240,
                  height: 900,
                  child: PlanToolPalette(controller: c)))));
      await tester.pump();
      await tester.pump();
    }

    await pumpIn(const Locale('tr'));
    expect(rowKeys(tester), [
      'tool-plan.select',
      'tool-plan.line',
      'tool-plan.polyline',
      'tool-plan.rectangle',
      'tool-plan.circle',
      'tool-plan.arc',
      'tool-plan.text',
      'tool-stamp.star',
      'tool-stamp.clash',
      'tool-stamp.fill',
      'tool-stamp.none',
      'tool-late.star',
    ]);
    expect(find.byKey(const Key('tool-group-stamp')), findsOneWidget);
    expect(find.byKey(const Key('tool-group-late')), findsOneWidget);
    expect(
        tester.getTopLeft(find.byKey(const Key('tool-group-stamp'))).dy,
        greaterThan(
            tester.getTopLeft(find.byKey(const Key('tool-plan.text'))).dy));
    Text title(String key) => tester.widget<Text>(find.descendant(
        of: find.byKey(Key(key)), matching: find.byType(Text)).first);
    expect(title('tool-stamp.star').data, 'Yıldız');
    expect(title('tool-stamp.clash').data, 'Clash', reason: 'no tr word');
    expect(
        find.descendant(
            of: find.byKey(const Key('tool-stamp.star')),
            matching: find.text('B')),
        findsOneWidget);
    expect(
        find.descendant(
            of: find.byKey(const Key('tool-stamp.clash')),
            matching: find.text('L')),
        findsNothing,
        reason: 'L is plan.line\'s');
    await pumpIn(const Locale('de'));
    expect(title('tool-stamp.star').data, 'Star', reason: 'no de word');
  });

  testWidgets(
      'KB-8 a tool the permissions leave out: its row disabled and its letter '
      'unbound (the key reaches the host); a runtime change rebuilds the '
      'palette and binds it again (M-KB-8a, M-KB-8b)', (tester) async {
    final c = drawController().c;
    final d = await pumpDesign(tester, c, hostKeys: const {
      'l': SingleActivator(LogicalKeyboardKey.keyL),
    });
    c.permissions =
        const PlanPermissions(tools: {'plan.select', 'plan.rectangle'});
    await tester.pump();
    expect(enabled(tester, 'tool-plan.line'), isFalse);
    expect(enabled(tester, 'tool-plan.rectangle'), isTrue);
    await focusCanvas(tester);
    await press(tester, LogicalKeyboardKey.keyL);
    expect(d.reached['l'], 1);
    expect(c.activeTool.value, 'plan.select');
    c.permissions = PlanPermissions.full;
    await tester.pump();
    expect(enabled(tester, 'tool-plan.line'), isTrue);
    await press(tester, LogicalKeyboardKey.keyL);
    expect(c.activeTool.value, 'plan.line');
    expect(d.reached['l'], 1);
  });

  testWidgets(
      'KB-9 F toggles Fill while a fill tool is offered; with none offered '
      'there is no Fill row and F reaches the host (M-KB-9)', (tester) async {
    final c = drawController().c;
    final d = await pumpDesign(tester, c, hostKeys: const {
      'f': SingleActivator(LogicalKeyboardKey.keyF),
    });
    await focusCanvas(tester);
    await press(tester, LogicalKeyboardKey.keyF);
    expect(c.fill.value, isTrue);
    expect(
        tester.widget<CheckboxListTile>(find.byKey(const Key('tool-fill'))).value,
        isTrue);
    c.permissions = const PlanPermissions(tools: {'plan.select', 'plan.line'});
    await tester.pump();
    expect(find.byKey(const Key('tool-fill')), findsNothing);
    await press(tester, LogicalKeyboardKey.keyF);
    expect(d.reached['f'], 1);
    expect(c.fill.value, isTrue, reason: 'unchanged');
  });
}
```

- [ ] **Step 5: Run the new tests to see them fail.** Run: `cd packages/jet_cad_2d_plan && flutter test test/shortcuts/plan_shortcuts_test.dart test/editor/plan_tool_palette_test.dart`. Expected: compilation errors naming `PlanShortcuts`, `PlanToolPalette`, `planToolEntries`, `planToolLabel`; no test runs.

- [ ] **Step 6: The controller.** In `lib/src/controller/plan_controller.dart`:
  Task 8 already exposes the validated kits as `KitSet get kits` and the log as `@internal DiagnosticsLog get diagnosticsLog` (`report`, deduplicated by Task 11); nothing is added for them.
  1. At the end of the constructor body (after the kit set is validated and the first document is built), add `planToolEntries(this);` with `import '../shortcuts/tool_letters.dart';`.

- [ ] **Step 7: The entries and the letters.** Create `lib/src/shortcuts/tool_letters.dart`:

```dart
// The palette's rows and the tool letters (spec 2a P2, "The keyboard" and
// "The widgets"): the generic tools first, with today's letters (V L P R C
// A T), then each kit's tools in load order. F is reserved for Fill. A
// kit's letter goes to the first tool that asks for it; a later tool that
// asks for a taken letter, for F, or for something that is no letter A-Z
// gets none and a letterTaken diagnostic (A3). plan.symbol has no row and
// no letter: the gallery arms it.
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter/widgets.dart' show IconData;
import 'package:jet_cad_2d/jet_cad_2d.dart' show Capability;
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:meta/meta.dart' show immutable;

import '../controller/plan_controller.dart';
import '../tools/generic_tools.dart';
import 'plan_shortcut_guard.dart' show letterKey;

/// The kit id the plan library's own tools stand under (a reserved id).
const String kPlanKitId = 'plan';

/// One palette row and its letter.
@immutable
final class PlanToolEntry {
  const PlanToolEntry({
    required this.id,
    required this.kitId,
    required this.icon,
    required this.needs,
    this.letter,
  });

  final String id;

  /// [kPlanKitId] for a generic tool, else its kit's id.
  final String kitId;
  final IconData icon;

  /// What the tool's commits need (`PlanTool.needs`' meaning).
  final Set<Capability> needs;

  /// The letter given, upper case, or null.
  final String? letter;

  /// [letter]'s key, or null.
  LogicalKeyboardKey? get key => switch (letter) {
        final l? => letterKey(l),
        null => null,
      };
}

final Expando<List<PlanToolEntry>> _entriesOf =
    Expando<List<PlanToolEntry>>('planToolEntries');

/// [controller]'s rows in palette order, computed once per controller: its
/// kit set is fixed at construction. The first call reports the refused
/// letters.
List<PlanToolEntry> planToolEntries(PlanController controller) =>
    _entriesOf[controller] ??= _assign(controller);

final RegExp _aLetter = RegExp(r'^[A-Z]$');

List<PlanToolEntry> _assign(PlanController c) {
  // The letter → the tool (or Fill) that has it.
  final taken = <String, String>{'F': 'Fill'};
  final out = <PlanToolEntry>[];
  for (final g in genericTools) {
    taken[g.letter] = g.id;
    out.add(PlanToolEntry(
        id: g.id,
        kitId: kPlanKitId,
        icon: g.icon,
        needs: g.needs,
        letter: g.letter));
  }
  for (final kit in c.kits.kits) {
    for (final t in kit.tools) {
      final asked = t.letter?.toUpperCase();
      String? letter;
      if (asked != null) {
        final owner = taken[asked];
        if (!_aLetter.hasMatch(asked)) {
          _refuse(c, kit, t, '"${t.letter}" is not a letter A-Z');
        } else if (owner != null) {
          _refuse(c, kit, t, 'the letter $asked is taken by $owner');
        } else {
          taken[asked] = t.id;
          letter = asked;
        }
      }
      out.add(PlanToolEntry(
          id: t.id,
          kitId: kit.id,
          icon: t.icon,
          needs: t.needs,
          letter: letter));
    }
  }
  return List<PlanToolEntry>.unmodifiable(out);
}

void _refuse(PlanController c, PlanKit kit, PlanTool tool, String why) =>
    c.diagnosticsLog.report(KitDiagnostic(
        kitId: kit.id,
        subject: tool.id,
        code: KitDiagnosticCode.letterTaken,
        message: '${tool.id} gets no letter: $why'));
```

- [ ] **Step 8: The guard's letters.** In `lib/src/shortcuts/plan_shortcut_guard.dart` (Task 15), replace `planLetterKeys` and its doc comment with:

```dart
/// The letters [controller]'s keyboard binds, F included (spec 2a P2: the
/// guard is built from the letters actually in use; F is reserved for
/// Fill): the generic tools' and the kits' given letters, in palette order.
List<LogicalKeyboardKey> planLetterKeys(PlanController controller) => [
      for (final e in planToolEntries(controller))
        if (e.key case final key?) key,
      LogicalKeyboardKey.keyF,
    ];
```

  and the import `'../tools/generic_tools.dart'` becomes `'tool_letters.dart'` (the two files import each other; Dart allows it).

- [ ] **Step 9: The palette.** Create `lib/src/editor/plan_tool_palette.dart`. The widget's shape is `floor_plan/lib/src/tool_palette.dart:30-104` (`ExcludeFocus`, a transparent `Material`, a `ListenableBuilder`, a `ListView` of dense `ListTile`s, then a `Divider` and the `CheckboxListTile` keyed `tool-fill` with the secondary `F`), its inputs read from the controller:

```dart
// Spec 2a P2, "The widgets": the generic tools, then each kit's, grouped in
// load order, labelled by tool:<id>; the Fill toggle. Ported from
// jet_cad_floor_plan/lib/src/tool_palette.dart (spec 05 D5, D13): the rows
// come from the controller (planToolEntries) instead of the shell's list.
//
// It never takes focus (ExcludeFocus, Ruling 05-6), so the canvas keeps it
// and the shortcuts keep working after a click here.
import 'package:flutter/material.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart' show Capability;
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart' show kitOfKey;

import '../controller/plan_controller.dart';
import '../l10n/locale_scope.dart';
import '../l10n/strings.dart';
import '../shortcuts/tool_letters.dart';
import '../tools/generic_tools.dart';

/// Whether a fill-capable tool is offered (host embedding spec S-9 f): the
/// Fill row and F only then.
bool fillOffered(PlanController controller) => genericTools
    .any((t) => t.fills && controller.permissions.allowsTool(t.id));

/// [toolId]'s label: the plan library's word for a generic tool, else the
/// kit's `tool:<id>` word in the controller's locale (English where the
/// kit has none), else the id itself.
String planToolLabel(
    BuildContext context, PlanController controller, String toolId) {
  final s = PlanStrings.of(context);
  return switch (toolId) {
    PlanToolIds.select => s.toolSelect,
    PlanToolIds.line => s.toolLine,
    PlanToolIds.polyline => s.toolPolyline,
    PlanToolIds.rectangle => s.toolRectangle,
    PlanToolIds.circle => s.toolCircle,
    PlanToolIds.arc => s.toolArc,
    PlanToolIds.text => s.toolText,
    PlanToolIds.symbol => s.toolSymbol,
    _ => controller.kits
            .kitOf(kitOfKey(toolId))
            ?.names
            .word(controller.locale.value.languageCode, 'tool:$toolId') ??
        toolId,
  };
}

/// The tools of [controller] and the Fill toggle.
class PlanToolPalette extends StatefulWidget {
  const PlanToolPalette({super.key, required this.controller});

  final PlanController controller;

  @override
  State<PlanToolPalette> createState() => _PlanToolPaletteState();
}

class _PlanToolPaletteState extends State<PlanToolPalette> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    PlanLocaleScope.push(context, widget.controller);
  }

  @override
  void didUpdateWidget(PlanToolPalette oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      PlanLocaleScope.push(context, widget.controller);
    }
  }

  /// Whether `selectTool(id)` would arm the tool now (Task 12's rule):
  /// offered by the permissions, and every need allowed by the document's
  /// engine permissions.
  static bool _enabled(PlanController c, PlanToolEntry e) {
    if (!c.permissions.allowsTool(e.id)) return false;
    final needs = c.needsOf(e.id);
    if (needs == null) return false;
    final engine = c.document.commands.permissions;
    return needs.every(engine.allows);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    return ExcludeFocus(
      // The left slot paints its own background, so the tiles need a
      // Material of their own to paint their ink on.
      child: Material(
        color: Colors.transparent,
        child: ListenableBuilder(
          // The controller notifies on a permissions change and a document
          // swap (Tasks 8, 12).
          listenable:
              Listenable.merge([c, c.activeTool, c.fill, c.locale]),
          builder: (context, _) {
            final strings = PlanStrings.of(context);
            final geometry =
                c.document.commands.permissions.allows(Capability.geometry);
            final active = c.activeTool.value;
            final rows = <Widget>[];
            String? group;
            for (final e in planToolEntries(c)) {
              if (group != null && e.kitId != group) {
                rows.add(Divider(key: Key('tool-group-${e.kitId}')));
              }
              group = e.kitId;
              rows.add(ListTile(
                key: Key('tool-${e.id}'),
                dense: true,
                leading: Icon(e.icon, size: 18),
                selected: active == e.id,
                enabled: _enabled(c, e),
                title: Text(planToolLabel(context, c, e.id)),
                trailing: e.letter == null ? null : Text(e.letter!),
                onTap: () => c.selectTool(e.id),
              ));
            }
            if (fillOffered(c)) {
              rows
                ..add(const Divider())
                ..add(CheckboxListTile(
                  key: const Key('tool-fill'),
                  dense: true,
                  title: Text(strings.fill),
                  secondary: const Text('F'),
                  value: c.fill.value,
                  onChanged:
                      geometry ? (v) => c.fill.value = v ?? false : null,
                ));
            }
            return ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: rows);
          },
        ),
      ),
    );
  }
}
```

- [ ] **Step 10: The keyboard.** Create `lib/src/shortcuts/plan_shortcuts.dart`:

```dart
// Spec 2a P2, "The keyboard": the file commands call the host's callbacks;
// Undo and Redo; F3 for snapping; F for Fill; Escape back to plan.select;
// the tool letters in use. Ported from the shell's bindings
// (jet_cad_floor_plan/lib/src/planner_shell.dart:1444-1469, spec 05 D5,
// 12a D6, host embedding C-5, C-7, S-16, S-26), the capabilities read from
// PlanPermissions. Text fields keep their keys: PlanTextKeys around
// everything (Slice 4 Task 7 finding 1), and PlanShortcutGuard around each
// of the plan's fields (built from planLetterKeys).
import 'dart:async';

import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter/widgets.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart' show Capability;

import '../controller/plan_controller.dart';
import '../editor/plan_tool_palette.dart' show fillOffered;
import '../tools/generic_tools.dart';
import 'plan_shortcut_guard.dart';
import 'tool_letters.dart';

/// The plan's keys around [child] (a host's layout of the plan's widgets).
///
/// - [shortcuts] false binds none of them and closes the select tool's
///   idle keys (Delete, Backspace, Escape), so every key reaches the host;
///   a gesture's own keys stay (a drag's Escape, a drawing tool's Escape
///   and Enter, plan.symbol's R and M). The controller's commands stay
///   callable.
/// - The file chords are bound for the callbacks given; a chord whose
///   command cannot act now (a shape part-way, or no page for Export and
///   Print) consumes the key and does nothing (S-26).
class PlanShortcuts extends StatefulWidget {
  const PlanShortcuts({
    super.key,
    required this.controller,
    required this.child,
    this.shortcuts = true,
    this.onNew,
    this.onOpen,
    this.onSave,
    this.onSaveAs,
    this.onExport,
    this.onPrint,
  });

  final PlanController controller;
  final Widget child;
  final bool shortcuts;
  final Future<void> Function()? onNew;
  final Future<void> Function()? onOpen;
  final Future<void> Function()? onSave;
  final Future<void> Function()? onSaveAs;
  final Future<void> Function()? onExport;
  final Future<void> Function()? onPrint;

  @override
  State<PlanShortcuts> createState() => _PlanShortcutsState();
}

class _PlanShortcutsState extends State<PlanShortcuts> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_applyIdleKeys);
    _applyIdleKeys();
  }

  @override
  void didUpdateWidget(PlanShortcuts oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      oldWidget.controller.removeListener(_applyIdleKeys);
      widget.controller.addListener(_applyIdleKeys);
    }
    _applyIdleKeys();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_applyIdleKeys);
    super.dispose();
  }

  /// The select tool's idle keys are the shortcuts (S-16). The gates are
  /// per document, so this runs again after a swap (the controller
  /// notifies).
  void _applyIdleKeys() =>
      widget.controller.selectGates.idleKeys = widget.shortcuts;

  /// Runs a file command when it can act: no shape part-way (spec 12a D6),
  /// and a page for Export and Print (spec 13 D8, D9).
  void _run(Future<void> Function() run, {required bool needsPage}) {
    final c = widget.controller;
    if (c.toolController.active.isMidShape) return;
    if (needsPage && c.page.value == null) return;
    unawaited(run());
  }

  Map<ShortcutActivator, VoidCallback> _bindings(PlanController c) {
    if (!widget.shortcuts) return const {};
    final p = c.permissions;
    final m = <ShortcutActivator, VoidCallback>{};
    void file(List<SingleActivator> chords, Future<void> Function()? run,
        {bool needsPage = false}) {
      if (run == null) return;
      for (final chord in chords) {
        m[chord] = () => _run(run, needsPage: needsPage);
      }
    }

    file(kNewChords, widget.onNew);
    file(kOpenChords, widget.onOpen);
    file(kSaveChords, widget.onSave);
    file(kSaveAsChords, widget.onSaveAs);
    if (p.export) file(kExportChords, widget.onExport, needsPage: true);
    if (p.print) file(kPrintChords, widget.onPrint, needsPage: true);
    // Spec P2: widget-facing commands consult the flags; the controller's
    // undo() and redo() do nothing mid-shape.
    if (p.undo) {
      for (final chord in kUndoChords) {
        m[chord] = c.undo;
      }
      for (final chord in kRedoChords) {
        m[chord] = c.redo;
      }
    }
    // Spec 03 D10: one toggle per press, never per key repeat; only while
    // snapping is allowed (S-14).
    if (c.snappingAllowed) {
      m[const SingleActivator(LogicalKeyboardKey.f3, includeRepeats: false)] =
          c.snap.toggleObjectSnap;
    }
    // Spec 05 D5: the letters, then Fill, then Escape. Only the allowed
    // letters are bound; a refused one bubbles (C-5).
    for (final e in planToolEntries(c)) {
      final key = e.key;
      if (key != null && p.allowsTool(e.id)) {
        m[SingleActivator(key, includeRepeats: false)] =
            () => c.selectTool(e.id);
      }
    }
    if (fillOffered(c)) {
      m[const SingleActivator(LogicalKeyboardKey.keyF,
          includeRepeats: false)] = () {
        if (c.document.commands.permissions.allows(Capability.geometry)) {
          c.fill.value = !c.fill.value;
        }
      };
    }
    // An idle drawing tool leaves Escape unhandled; it arrives here.
    m[const SingleActivator(LogicalKeyboardKey.escape)] = () {
      if (c.activeTool.value != PlanToolIds.select) {
        c.selectTool(PlanToolIds.select);
      }
    };
    return m;
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    return PlanTextKeys(
      child: ListenableBuilder(
        // A permissions change or a document swap rebinds.
        listenable: c,
        builder: (context, child) =>
            CallbackShortcuts(bindings: _bindings(c), child: child!),
        child: widget.child,
      ),
    );
  }
}
```

- [ ] **Step 11: The barrel.** In `lib/jet_cad_2d_plan.dart` add, in sorted position: `export 'src/editor/plan_tool_palette.dart' show PlanToolPalette;`, `export 'src/shortcuts/plan_shortcut_guard.dart' show PlanShortcutGuard;`, `export 'src/shortcuts/plan_shortcuts.dart';`.

- [ ] **Step 12: Run the new tests.** Run: `cd packages/jet_cad_2d_plan && flutter test test/shortcuts/plan_shortcuts_test.dart test/editor/plan_tool_palette_test.dart`. Expected: `All tests passed!` (ten tests). Then `flutter test test/canvas` (Task 15's guard change must keep them green). Expected: `All tests passed!`.

- [ ] **Step 13: Port the palette and keyboard tests.** Assertions unchanged in every ported test; only the fixture, the pump, the key names and the imports change, as listed. Each file starts with `// Ported from jet_cad_floor_plan/test/<file>; assertions unchanged.`
  1. **`test/editor/palette_draw_test.dart`** from `floor_plan/test/planner_draw_test.dart`: `A1` (`:89-104`), `A2` (`:106-130`), `A3` (`:132-141`), `A4` (`:143-148`), `A5` (`:150-172`), `A6` (`:174-207`), `A8` (`:238-256`), `A10` (`:278-296`), `A11` (`:298-314`), `A12` (`:316-328`), `A12b` (`:330-379`), `A13` (`:381-412`). Imports: drop the four `package:jet_cad_floor_plan/...` imports (`:3-6`); add `package:jet_cad_2d_plan/jet_cad_2d_plan.dart`, `../support/canvas_fixture.dart`, `../support/design_harness.dart`. The local helpers `drawDoc`, `pumpDraw`, `globalOf`, `status`, `press`, `bytes`, `withoutSeed`, `entryEditable`, `ofKind` (`:16-87`) are deleted: the fixture and the harness carry them. Adaptations:
     - `await pumpDraw(tester, drawDoc(FlutterTextMeasurer()).doc)` and `final view = await pumpDraw(…)` become `final f = drawController(); final c = f.c; await pumpDesign(tester, c);` (`A3` reads `f.line` for `d.line`).
     - `globalOf(tester, view, …)` → `globalOf(tester, c, …)`; `bytes(view)` → `bytes(c)`; `withoutSeed(view)` → `withoutSeed(c)`; `view.selection` → `c.selection`; `view.document` → `c.document`.
     - `view.tools.active as TextTool` (`:392`) → `c.textTool`; `view.tools.active as PolylineTool` (`:291`) → `activeTool(c) as PolylineTool`.
     - The palette keys: `'tool-<name>'` → `'tool-plan.<name>'` (`'tool-line'` → `'tool-plan.line'`, …, `'tool-select'` → `'tool-plan.select'`); `'tool-fill'` stays.
     - `A12`: `d.doc.commands.permissions = DraftPermissions.runtime;` (`:318`) runs on `c.document` before `pumpDesign`.
     - `A12b`: the `drawing` map (`:337-353`) keeps the generic seven rows with their values (`'tool-plan.select': false`, `'tool-plan.line'`, `'tool-plan.polyline'`, `'tool-plan.rectangle'`, `'tool-plan.circle'`, `'tool-plan.arc'`, `'tool-plan.text'`: `true`); the planner's box, wall, door, window, gap, room, separator and dimension rows are sub-project 3's tools and leave with them. `find.byType(ToolPalette)` → `find.byType(PlanToolPalette)`; the second `pumpDraw(tester, d.doc)` (`:372`) → `pumpDesign(tester, c)` after `c.document.commands.permissions = DraftPermissions.runtime;`.
  2. **`test/shortcuts/host_text_keys_test.dart`** from `floor_plan/test/host/host_text_keys_test.dart`: the helpers `PosIntent`, `kPosKeys`, `kPosChord`, `PosHost`, `focusedText`, `inField`, `fill`, `typeInto` (`:22-179`) and the tests `selection, shortcuts: $shortcuts: a host field in the service bar keeps its keys from the host's own bindings (a chord reaches it)` (`:244-253`, renamed "a host field beside the plan keeps its keys …") and `(final review F-6, mutant S25): a held key typed in a field, its repeats included, never fires the host's intent` (`:276-301`, its `host-bar-field` branch, run once). Adaptations: `PosHost(c, shortcuts, caps)` loses `caps`; `mountPos` (`:83-129`) becomes:

```dart
Future<PosHost> mountPos(WidgetTester tester, {bool shortcuts = false}) async {
  final c = drawController().c;
  final h = PosHost(c, shortcuts);
  addTearDown(h.shortcuts.dispose);
  await pumpDesign(tester, c,
      shortcuts: shortcuts,
      hostField: true,
      host: (plan) => Shortcuts(
            shortcuts: {
              for (final MapEntry(:key, :value) in kPosKeys.entries)
                value.$1: PosIntent(key),
              kPosChord: const PosIntent('chord'),
            },
            child: Actions(
              actions: {
                PosIntent: CallbackAction<PosIntent>(
                    onInvoke: (i) => i.name == 'chord'
                        ? h.chords++
                        : h.fired[i.name] = h.fired[i.name]! + 1),
              },
              child: Focus(child: plan),
            ),
          ));
  return h;
}
```

     the field key `'host-bar-field'` → `'host-field'`; `t.press` → the harness's `press`.

- [ ] **Step 14: Run the ported tests.** Run: `cd packages/jet_cad_2d_plan && flutter test test/editor test/shortcuts`. Expected: `All tests passed!`. A ported test that fails on an assertion is a finding: stop and report it; never change the assertion.

- [ ] **Step 15: Format and the gate.** `cd packages/jet_cad_2d_plan && dart format . && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .` — each exits 0. `git status --short` lists only this task's files.

- [ ] **Step 16: Commit.**

```bash
git add packages/jet_cad_2d_plan/lib/src/shortcuts/tool_letters.dart packages/jet_cad_2d_plan/lib/src/shortcuts/plan_shortcuts.dart packages/jet_cad_2d_plan/lib/src/shortcuts/plan_shortcut_guard.dart packages/jet_cad_2d_plan/lib/src/editor/plan_tool_palette.dart packages/jet_cad_2d_plan/lib/src/controller/plan_controller.dart packages/jet_cad_2d_plan/lib/jet_cad_2d_plan.dart packages/jet_cad_2d_plan/test/support/stamp_kit.dart packages/jet_cad_2d_plan/test/support/design_harness.dart packages/jet_cad_2d_plan/test/shortcuts/plan_shortcuts_test.dart packages/jet_cad_2d_plan/test/editor/plan_tool_palette_test.dart packages/jet_cad_2d_plan/test/editor/palette_draw_test.dart packages/jet_cad_2d_plan/test/shortcuts/host_text_keys_test.dart
git commit -m "$(cat <<'EOF'
feat(plan): PlanToolPalette and PlanShortcuts (P2)

The palette lists the generic tools, then each kit's in load order,
grouped and labelled by tool:<id>, disabled as selectTool would refuse
them, with the Fill toggle. The keyboard binds the host's file
callbacks, Undo and Redo under the undo flag, F3, F, Escape and the tool
letters in use: V L P R C A T, F reserved, then the kits' in load order,
a taken letter a letterTaken diagnostic at construction. shortcuts:
false lets every key reach the host, and the guard keeps the letters in
use out of text fields.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 17: Mutation check** (on the committed files; after each: run the named test, quote its red line, `git checkout -- <file>`, `git diff --quiet -- <file>` exits 0):
  - M-KB-1a `lib/src/shortcuts/tool_letters.dart`: `} else if (owner != null) {` → `} else if (false) {` → KB-1 red (`stamp.clash` gets L).
  - M-KB-1b `tool_letters.dart`: `<String, String>{'F': 'Fill'}` → `<String, String>{}` → KB-1 red (`stamp.fill` gets F).
  - M-KB-1c `lib/src/controller/plan_controller.dart`: delete the constructor's `planToolEntries(this);` → KB-1 red (no diagnostic before a widget).
  - M-KB-2 `lib/src/shortcuts/plan_shortcut_guard.dart`: `planLetterKeys` returns `[for (final t in genericTools) letterKey(t.letter), LogicalKeyboardKey.keyF]` (Task 15's body) → KB-2 red (B arms the star from the field).
  - M-KB-3a `lib/src/shortcuts/plan_shortcuts.dart`: delete `if (!widget.shortcuts) return const {};` → KB-3 red.
  - M-KB-3b `plan_shortcuts.dart`: `_applyIdleKeys` body → `{}` → KB-3 red (the select tool's Escape clears the selection).
  - M-KB-4 `plan_shortcuts.dart`: delete the Escape binding → KB-4 red (the tool stays polyline).
  - M-KB-5 `plan_shortcuts.dart`: `if (p.undo) {` → `if (true) {` → KB-5 red.
  - M-KB-6a `plan_shortcuts.dart`: delete `if (needsPage && c.page.value == null) return;` → KB-6 red (an export with no page).
  - M-KB-6b `plan_shortcuts.dart`: `if (p.export) file(…)` → `file(kExportChords, widget.onExport, needsPage: true);` → KB-6 red.
  - M-KB-7a `tool_letters.dart`: `for (final kit in c.kits.kits)` → `for (final kit in c.kits.kits.reversed)` → KB-7 red (and KB-1).
  - M-KB-7b `lib/src/editor/plan_tool_palette.dart`: `controller.locale.value.languageCode` → `'en'` → KB-7 red.
  - M-KB-8a `plan_tool_palette.dart`: `enabled: _enabled(c, e),` → `enabled: true,` → KB-8 red.
  - M-KB-8b `plan_shortcuts.dart`: `if (key != null && p.allowsTool(e.id))` → `if (key != null)` → KB-8 red.
  - M-KB-9 `plan_tool_palette.dart`: `fillOffered` returns `true` → KB-9 red.
  - M-KB-10 `lib/src/canvas/plan_canvas.dart`: `autofocus: widget.autofocus,` → `autofocus: true,` → KB-10 red.
  - M-05m (the ported `A4`'s) `plan_shortcuts.dart`: the Escape binding's body → `{}` → `palette_draw_test.dart` `A4` red.
  - M-05v (the ported `A8`'s) `lib/src/canvas/text_entry_overlay.dart`: `PlanShortcutGuard(controller: widget.controller, child: …)` → its child alone → `A8` red.

#### Assumed from earlier tasks

Each name below is used as written; where the earlier task named it otherwise, the implementer uses that task's name and reports the difference.
- Task 4: `PlanTool` exposes `id`, `icon`, `letter` (`String?`), `needs` (`Set<Capability>`) as fields; `PlanKit.tools`; `KitDiagnostic({required String kitId, String? subject, required KitDiagnosticCode code, required String message, Object? error})` with getters of the same names.
- Task 6: `KitSet` (`lib/src/kits/kit_set.dart`) with `List<PlanKit> get kits` in load order and `PlanKit? kitOf(String id)`.
- Task 8 (`PlanController`): `ValueListenable<String> get activeTool`; `bool selectTool(String id)` that clears the selection when it arms a drawing tool (today's `_activate`, `planner_shell.dart:926-933`; the ported `A3` pins it); `void undo()`, `void redo()` (nothing mid-shape); `ValueListenable<List<KitDiagnostic>> get diagnostics`; `ValueListenable<Locale> get locale`; `SnapSettings get snap`; `PageNotifier get page`; `SelectionController get selection`; a `ChangeNotifier` that notifies on a document swap. `KitSet get kits` (load order, `kitOf`) and `@internal DiagnosticsLog get diagnosticsLog` (`report`); `@internal bool snappingAllowed`.
- Task 9: `PlanStrings.of` with `toolSelect`, `toolLine`, `toolPolyline`, `toolRectangle`, `toolCircle`, `toolArc`, `toolText`, `toolSymbol`, `fill` (today's English words: 'Select', 'Line', 'Polyline', 'Rectangle', 'Circle', 'Arc', 'Text', 'Symbol', 'Fill'); `PlanLocaleScope.push`.
- Task 11: `GuardedTool` forwards `isMidShape` (the shortcuts read `toolController.active.isMidShape`).
- Task 12: `PlanController.permissions` (a set notifies), `fill`, `selectGates` with a settable `bool idleKeys` read by the select tool, `needsOf(String)`, `toolController`; `PlanPermissions.allowsTool`, `undo`, `export`, `print`, `copyWith`, `full`; `genericTools`, `GenericTool.fills`, `PlanToolIds`.
- Task 15: `PlanCanvas`, `PlanShortcutGuard`, `PlanTextKeys`, `letterKey`, the chords; `PlanController.textTool`; `test/support/canvas_fixture.dart`.

#### Interface problem

Resolved, no interface change: 1 by controller ruling R-l (the guard lands in Task 15; Task 13's gallery field, which lands before it, stops typed keys itself, as its plan decision states); 2 needs none: Task 4's `PlanKit.validate()` does not check `letter`, so this task's `_aLetter` rule is the one check (a non-letter gets none and `letterTaken`).

---


### Task 12: Permissions and the generic tools (spec P2 "Permissions", P1 reserved ids)

**Files:**
- Create: `packages/jet_cad_2d_plan/lib/src/controller/permissions.dart` (`PlanPermissions`)
- Create: `packages/jet_cad_2d_plan/lib/src/tools/plan_select_gates.dart` (`PlanSelectGates`, not exported)
- Create: `packages/jet_cad_2d_plan/lib/src/tools/generic_tools.dart` (`PlanToolIds`, `GenericTool`, `genericTools`, `GenericToolSet`, `buildGenericTools`; not exported)
- Modify: `packages/jet_cad_2d_plan/lib/src/controller/plan_controller.dart` and `packages/jet_cad_2d_plan/lib/src/controller/session.dart` (Task 8 keeps the per-document build and teardown in `DocumentSession`) (the `permissions` constructor parameter, permissions at runtime, the tool gate, the generic tools, the gates on the select tool and the grip cache, host undo and redo, `deleteSelection`, the Fill toggle)
- Modify: `packages/jet_cad_2d_plan/lib/jet_cad_2d_plan.dart` (export `permissions.dart`)
- Test: `packages/jet_cad_2d_plan/test/controller/permissions_test.dart`, `test/tools/plan_select_gates_test.dart`, `test/tools/generic_tools_test.dart`, `test/controller/permissions_controller_test.dart`
- Test support: `packages/jet_cad_2d_plan/test/support/tool_events.dart` (new; Task 13 and Task 14 reuse it)

(Paths below are under `packages/jet_cad_2d_plan/` unless they start at the repository root.)

**Interfaces:**
- Consumes:
  - `PlanGate` (Task 3), `PlanTool.needs` (Task 4) from `package:jet_cad_2d_kit/jet_cad_2d_kit.dart`.
  - `DraftPermissions`, `Capability`, `Handle`, `PermissionDeniedError` from `package:jet_cad_2d/jet_cad_2d.dart`.
  - `SelectGates`, `SelectTool`, `MoveResolver`, `LineTool`, `PolylineTool`, `RectangleTool`, `CircleTool`, `ArcTool`, `TextTool`, `Tool`, `ToolController`, `ToolPhase`, `SelectionController`, `SelectionKey`, `GripCache`, `DragKind`, `ToolPointerEvent`, `ViewportTransform`, `kPickRadiusPixels` from `package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart`.
  - From Task 8: `PlanController` and the members listed under "Assumed from earlier tasks".
  - From Task 10: `PlanController.locked` (`ValueListenable<Set<Handle>>`).
- Produces:
  - Exported from the barrel: `final class PlanPermissions` —
    `const PlanPermissions({Set<String>? tools, bool move = true, bool rotate = true, bool mirror = true, bool reshape = true, bool delete = true, bool changeLayer = true, bool recolor = true, bool editLayers = true, bool editPage = true, bool undo = true, bool export = true, bool print = true})`;
    `static const PlanPermissions full`, `static const PlanPermissions readOnly`;
    `bool allowsTool(String id)`; `bool allows(PlanGate gate)`; `bool get edits`; `DraftPermissions get draft`;
    `PlanPermissions copyWith({...every field...})`; `==`, `hashCode`, `toString`.
  - On `PlanController` (public): `PlanPermissions get permissions`, `set permissions(PlanPermissions value)`.
  - On `PlanController` (`@internal`, for Tasks 14-17): `PlanSelectGates get selectGates`, `ValueNotifier<bool> get fill`, `SelectTool get planSelect`, `Set<Capability>? needsOf(String toolId)`, `void registerToolNeeds(String id, Set<Capability> needs)`.
  - Internal (`lib/src/tools/`): `abstract final class PlanToolIds` (the eight reserved ids), `final class GenericTool`, `const List<GenericTool> genericTools`, `final class GenericToolSet`, `GenericToolSet buildGenericTools({required SelectGates gates, required ValueListenable<bool> fill, MoveResolver? moveResolver})`, `final class PlanSelectGates extends SelectGates`.

Plan decision (the engine groups): `PlanPermissions.draft` is `DraftPermissions.readOnly` when no edit flag is on and no tool but `plan.select` is allowed (`edits == false`), else `DraftPermissions.all`. Each engine group maps onto several flags (spec Facts: the engine cannot tell a rotation from a move; `AddEntityCommand` is `geometry`, `commands.dart:42`, and a delete is `geometry` and `structure`), so a group can be closed only when every flag that may need it is closed; the one profile where that is known without a per-command table is "no edit at all", today's `readOnly`. Every finer refusal stays a UI gate (spec P2: "`DraftPermissions` gets a group only where a flag maps onto one").

Plan decision (host calls): `controller.undo()` and `controller.redo()` run with the document's permissions lifted to `DraftPermissions.all` for that one call, then restored. The dispatcher checks permissions on undo and redo too (`jet_cad_2d/lib/src/document/undo.dart:213`, `:244`, `_require` at `:286-292`), so without the lift a host's `undo()` under `readOnly` (whose `draft` is `DraftPermissions.readOnly`) would throw `PermissionDeniedError`, against spec P2 "a host calling `controller.undo()` under `undo: false` still undoes". `undo` and `redo` skip the expander, so the lock layer is unaffected (spec P4).

Plan decision (`deleteSelection`): it keeps today's refusals (`floor_plan_controller.dart:695-714`: nothing selected, the editor's `delete` refused, mid-gesture), because it is the select tool's own delete through the gates (`select_tool.dart:748-753`); the "from a widget" of spec P2 is the flag, which today's controller call honours too. A locked selection is refused by the same gates (Task 10's set, read by `PlanSelectGates`).

Plan decision (`plan.select`): it is always allowed, whatever `tools` says, so `PlanPermissions` needs no validation (today's `validateEditorCapabilities`, `editor_capabilities.dart:355-360`, refused a `tools` set without select; here select is implied).

Plan decision (Fill): the Fill toggle is one `ValueNotifier<bool>` owned by the controller and kept across document swaps (today the shell's, `planner_shell.dart:421`, reset when a new shell was built). Task 16's palette and `F` key flip it.

Plan decision (the gates' cost): `SelectGates` getters are read at every hover, key and frame and must allocate nothing (`select_gates.dart:14-21`). `PlanSelectGates` extends Task 10's `LockGates`, which caches "the selection holds a locked object" as a `bool`, recomputed on a selection notification and on a `locked` notification; the getters read the permissions and that boolean.

Ported tests: none verbatim. Today's capability tests drive `FloorPlanEditorCapabilities` and `FloorPlanTool` through `FloorPlanView` (`test/host/editor_capabilities_test.dart`, `editor_tools_test.dart`, `editor_select_test.dart`); `PlanPermissions` is a new type (its panel, gallery and drafting-aid fields moved to widget options, P7; `selectTablesOnly` and `renumber` to 2b). The table below maps each controller-level case to its new test. The palette, letters and bar cases (EC "letters", T4-e, T4-j, M-H41) move with their widgets to Tasks 16 and 20.

| Today | New test |
|---|---|
| EC2 the profiles field by field | PM-1 |
| EC3 copyWith | PM-2 |
| EC4 `==` / `hashCode` | PM-3 |
| EC5 `toString` | PM-7 |
| T4-b `selectTool` refused / allowed | PM-11 |
| `_activate` refusing a drawing tool while geometry is denied (`planner_shell.dart:926-933`) | PM-12 |
| M-H47 a runtime change cancels the pending shape | PM-13 |
| S-9 h a drag whose gate closes is cancelled | PM-14 |
| T5-c Delete under readOnly | PM-16 |

- [ ] **Step 1: The test support for pointer events.** Create `test/support/tool_events.dart`:

```dart
// Pointer events for the plan's tools without a canvas (Task 12; reused by
// Tasks 13 and 14). Every event goes to the controller's active tool
// through its own ToolContext, resolved through the controller's camera,
// which a test first sets to a rotated, flipped, off-origin view
// ([useTestCamera]) so no fixture sits at the identity transform.
import 'dart:ui' show Offset;

import 'package:flutter/gestures.dart' show kPrimaryButton;
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

/// The test camera's pixels per millimetre.
const double kTestScale = 0.25;

/// Turned by 0.3 rad, y flipped, 0.25 px/mm, the world point
/// (4200, -1300) at the screen point (400, 300).
ViewportTransform testCamera() => ViewportTransform(
    worldToScreenMatrix: Transform2.translation(400, 300)
        .multiply(Transform2.rotation(0.3))
        .multiply(Transform2.scale(kTestScale, -kTestScale))
        .multiply(Transform2.translation(-4200, 1300)));

void useTestCamera(PlanController c) =>
    c.toolController.context.camera.value = testCamera();

/// An event at world [world] as the interaction layer would build it.
ToolPointerEvent eventAt(PlanController c, Vector2 world,
    {int buttons = 0, int pointer = 7}) {
  final cam = c.toolController.context.camera.value;
  final s = cam.worldToScreen(world);
  return ToolPointerEvent(
      screen: Offset(s.x, s.y),
      world: world,
      pointer: pointer,
      buttons: buttons,
      shift: false,
      control: false,
      meta: false,
      alt: false,
      pickRadiusWorld: kPickRadiusPixels / cam.scale);
}

/// A hover, a primary press and a release at [world], to the active tool.
void tapAt(PlanController c, Vector2 world) {
  final tools = c.toolController;
  tools.active.onPointerMove(eventAt(c, world), tools.context);
  tools.active
      .onPointerDown(eventAt(c, world, buttons: kPrimaryButton), tools.context);
  tools.active.onPointerUp(eventAt(c, world), tools.context);
}

/// A primary press at [from], eight moves to [to], [beforeUp], a release.
void dragFrom(PlanController c, Vector2 from, Vector2 to,
    {void Function()? beforeUp}) {
  final tools = c.toolController;
  tools.active.onPointerMove(eventAt(c, from), tools.context);
  tools.active
      .onPointerDown(eventAt(c, from, buttons: kPrimaryButton), tools.context);
  for (var i = 1; i <= 8; i++) {
    final p = from + (to - from) * (i / 8);
    tools.active
        .onPointerMove(eventAt(c, p, buttons: kPrimaryButton), tools.context);
  }
  beforeUp?.call();
  tools.active.onPointerUp(eventAt(c, to), tools.context);
}

/// The root-level lines of [d], ascending by handle.
List<Handle> linesOf(DraftDocument d) {
  final e = d.entities;
  return [
    for (final s in e.liveSlots)
      if (e.kindAt(s) == EntityKind.line && e.ownerAt(s) == d.rootHandle)
        e.handleAt(s),
  ]..sort((a, b) => a.value.compareTo(b.value));
}

/// Draws one line from [a] to [b] with `plan.line`, then arms `plan.select`
/// (which ends the line tool's chain). Returns the line's handle.
Handle drawLine(PlanController c, Vector2 a, Vector2 b) {
  final before = linesOf(c.document).toSet();
  if (!c.selectTool('plan.line')) throw StateError('plan.line refused');
  tapAt(c, a);
  tapAt(c, b);
  c.selectTool('plan.select');
  return linesOf(c.document).singleWhere((h) => !before.contains(h));
}
```

- [ ] **Step 2: Write the failing tests for `PlanPermissions`.** Create `test/controller/permissions_test.dart`:

```dart
// Spec P2 "Permissions" (Task 12): PlanPermissions, read field by field
// against the spec's list, written out here and never read from the code
// under test. Modelled on jet_cad_floor_plan's editor_capabilities_test
// EC2-EC5; the type is new (P7 moves the panels, the gallery and the
// drafting aids to the widgets' options, and the tables-only fields to 2b).
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart' show DraftPermissions;
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart' show PlanGate;
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';

typedef P = PlanPermissions;

/// Every flag, in declaration order.
const List<String> kFlagNames = [
  'move',
  'rotate',
  'mirror',
  'reshape',
  'delete',
  'changeLayer',
  'recolor',
  'editLayers',
  'editPage',
  'undo',
  'export',
  'print',
];

Map<String, bool> flagsOf(P p) => {
      'move': p.move,
      'rotate': p.rotate,
      'mirror': p.mirror,
      'reshape': p.reshape,
      'delete': p.delete,
      'changeLayer': p.changeLayer,
      'recolor': p.recolor,
      'editLayers': p.editLayers,
      'editPage': p.editPage,
      'undo': p.undo,
      'export': p.export,
      'print': p.print,
    };

P copyFlag(P p, String name, bool v) => switch (name) {
      'move' => p.copyWith(move: v),
      'rotate' => p.copyWith(rotate: v),
      'mirror' => p.copyWith(mirror: v),
      'reshape' => p.copyWith(reshape: v),
      'delete' => p.copyWith(delete: v),
      'changeLayer' => p.copyWith(changeLayer: v),
      'recolor' => p.copyWith(recolor: v),
      'editLayers' => p.copyWith(editLayers: v),
      'editPage' => p.copyWith(editPage: v),
      'undo' => p.copyWith(undo: v),
      'export' => p.copyWith(export: v),
      'print' => p.copyWith(print: v),
      _ => throw ArgumentError(name),
    };

/// The flag each gate reads (spec P3: a gate names a PlanPermissions flag).
const Map<PlanGate, String> kGateFlag = {
  PlanGate.move: 'move',
  PlanGate.rotate: 'rotate',
  PlanGate.mirror: 'mirror',
  PlanGate.reshape: 'reshape',
  PlanGate.delete: 'delete',
  PlanGate.changeLayer: 'changeLayer',
  PlanGate.recolor: 'recolor',
  PlanGate.editLayers: 'editLayers',
  PlanGate.editPage: 'editPage',
};

/// readOnly's flags, as spec P2 and today's S-12 list them.
const Map<String, bool> kReadOnly = {
  'move': false,
  'rotate': false,
  'mirror': false,
  'reshape': false,
  'delete': false,
  'changeLayer': false,
  'recolor': false,
  'editLayers': false,
  'editPage': false,
  'undo': false,
  'export': true,
  'print': true,
};

void main() {
  test('PM-1 full and readOnly, field by field', () {
    expect(P.full.tools, isNull, reason: 'every tool');
    expect(flagsOf(P.full), {for (final n in kFlagNames) n: true});
    expect(const P(), P.full);
    // M-PM1: readOnly's `undo: false` dropped.
    expect(P.readOnly.tools, {'plan.select'});
    expect(flagsOf(P.readOnly), kReadOnly);
  });

  test('PM-2 copyWith replaces exactly the field it names; null keeps', () {
    for (final name in kFlagNames) {
      for (final base in [P.full, P.readOnly]) {
        final before = flagsOf(base);
        final after = flagsOf(copyFlag(base, name, !before[name]!));
        // M-PM2: `move: move ?? this.move` written `move: this.move`.
        expect(after, {...before, name: !before[name]!},
            reason: '$name on $base');
        expect(copyFlag(base, name, before[name]!), base, reason: name);
      }
    }
    final some = P.full.copyWith(tools: {'plan.select', 'plan.line'});
    expect(some.tools, {'plan.select', 'plan.line'});
    expect(flagsOf(some), flagsOf(P.full));
    // A null argument keeps (Flutter's convention): start from full to
    // allow every tool again.
    expect(P.readOnly.copyWith().tools, {'plan.select'});
    expect(P.readOnly.copyWith(tools: null).tools, {'plan.select'});
    // The set given is copied, unmodifiable.
    final given = {'plan.select', 'plan.arc'};
    final copied = P.full.copyWith(tools: given);
    given.add('plan.text');
    expect(copied.tools, {'plan.select', 'plan.arc'});
    expect(() => copied.tools!.add('plan.circle'), throwsUnsupportedError);
  });

  test('PM-3 == and hashCode over every field; the tools as a set', () {
    final a = P.full.copyWith(tools: {'plan.line', 'plan.select', 'acme.x'});
    final b = P.full.copyWith(tools: {'acme.x', 'plan.select', 'plan.line'});
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    // M-PM3: `setEquals(other.tools, tools) &&` dropped from ==.
    expect(a == P.full.copyWith(tools: {'plan.select', 'plan.line'}), isFalse);
    expect(a == P.full, isFalse, reason: 'a set is not "every tool"');
    for (final name in kFlagNames) {
      final changed = copyFlag(P.full, name, false);
      expect(changed == P.full, isFalse, reason: name);
      expect(P.full == changed, isFalse, reason: name);
    }
    expect(P.full == P.readOnly, isFalse);
    expect(identical(P.readOnly, P.readOnly), isTrue);
  });

  test('PM-4 allowsTool: select always; null allows every id; a set its own',
      () {
    for (final id in ['plan.select', 'plan.line', 'acme.wall', 'x.y']) {
      expect(P.full.allowsTool(id), isTrue, reason: id);
    }
    // M-PM4: `id == PlanToolIds.select ||` dropped.
    final none = P.full.copyWith(tools: const <String>{});
    expect(none.allowsTool('plan.select'), isTrue);
    expect(none.allowsTool('plan.line'), isFalse);
    expect(P.readOnly.allowsTool('plan.select'), isTrue);
    expect(P.readOnly.allowsTool('plan.symbol'), isFalse);
    final some = P.full.copyWith(tools: {'acme.wall'});
    expect(some.allowsTool('acme.wall'), isTrue);
    expect(some.allowsTool('acme.door'), isFalse);
    expect(some.allowsTool('plan.select'), isTrue);
  });

  test("PM-5 allows(gate) reads that gate's own flag, and only it", () {
    for (final MapEntry(key: gate, value: flag) in kGateFlag.entries) {
      final off = copyFlag(P.full, flag, false);
      for (final other in PlanGate.values) {
        // M-PM5: the `move` and `rotate` arms of `allows` swapped.
        expect(off.allows(other), other != gate,
            reason: '$flag off, asking $other');
      }
    }
    expect(kGateFlag.keys.toSet(), PlanGate.values.toSet(),
        reason: 'premise: every gate is listed');
  });

  test(
      'PM-6 draft: no edit flag and no tool but select is the engine\'s '
      'readOnly; any edit flag or any other tool opens every group', () {
    // M-PM6a: `draft` always DraftPermissions.all.
    expect(P.readOnly.draft, same(DraftPermissions.readOnly));
    expect(P.readOnly.edits, isFalse);
    expect(P.full.draft, same(DraftPermissions.all));
    for (final name in kFlagNames.take(9)) {
      // move .. editPage: each alone is an edit.
      final one = copyFlag(P.readOnly, name, true);
      expect(one.edits, isTrue, reason: name);
      expect(one.draft, same(DraftPermissions.all), reason: name);
    }
    for (final name in ['undo', 'export', 'print']) {
      final one = copyFlag(P.readOnly, name, true);
      expect(one.draft, same(DraftPermissions.readOnly),
          reason: '$name is not an edit');
    }
    // M-PM6b: the tools term dropped from `edits`.
    final drawing = P.readOnly.copyWith(tools: {'plan.select', 'plan.line'});
    expect(drawing.draft, same(DraftPermissions.all));
    final everyTool = const P(
        move: false,
        rotate: false,
        mirror: false,
        reshape: false,
        delete: false,
        changeLayer: false,
        recolor: false,
        editLayers: false,
        editPage: false);
    expect(everyTool.tools, isNull);
    expect(everyTool.draft, same(DraftPermissions.all),
        reason: 'null tools allows the drawing tools');
  });

  test('PM-7 toString names the fields that differ from full', () {
    expect(P.full.toString(), 'PlanPermissions()');
    expect(P.full.copyWith(reshape: false).toString(),
        'PlanPermissions(reshape: false)');
    expect(P.full.copyWith(undo: false, move: false).toString(),
        'PlanPermissions(move: false, undo: false)');
    expect(
        P.readOnly.toString(),
        'PlanPermissions(tools: {plan.select}, move: false, rotate: false, '
        'mirror: false, reshape: false, delete: false, changeLayer: false, '
        'recolor: false, editLayers: false, editPage: false, undo: false)');
    // The tools sorted, so the text is stable whatever the set's order.
    expect(P.full.copyWith(tools: {'plan.text', 'acme.x'}).toString(),
        'PlanPermissions(tools: {acme.x, plan.text})');
  });
}
```

- [ ] **Step 3: Write the failing tests for the gates.** Create `test/tools/plan_select_gates_test.dart`:

```dart
// Spec P2 "Permissions" (select gates: move, rotate, reshape, delete) and
// P4 "Locks" (the select gates refuse a locked object), Task 12. The gates
// read the permissions live, and the selection's lock state from a cache
// recomputed on a selection or a lock notification. Fixtures: lines off the
// origin; a nested key whose chain names a locked group.
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:jet_cad_2d_plan/src/tools/plan_select_gates.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

final class Rig {
  Rig() {
    document = DraftDocument.empty();
    for (final (a, b) in [
      (Vector2(4100.5, -1250.25), Vector2(4700.75, -980.5)),
      (Vector2(5200.25, -1610.75), Vector2(5900.5, -1300.25)),
    ]) {
      final cmd = addDrafted(document, EntityKind.line, linePayload(a, b),
          layer: ReservedHandles.layerZero);
      document.commands.execute(cmd);
      lines.add(cmd.record.handle);
    }
    selection = SelectionController(document);
    gates = PlanSelectGates(
        permissions: () => permissions,
        selection: selection,
        locked: locked);
    addTearDown(() {
      gates.dispose();
      selection.dispose();
      locked.dispose();
    });
  }

  late final DraftDocument document;
  late final SelectionController selection;
  late final PlanSelectGates gates;
  final List<Handle> lines = [];
  final ValueNotifier<Set<Handle>> locked = ValueNotifier(const {});
  PlanPermissions permissions = PlanPermissions.full;

  Map<String, bool> get open => {
        'move': gates.move,
        'rotate': gates.rotate,
        'reshape': gates.reshape,
        'delete': gates.delete,
      };
}

const Map<String, bool> kAllOpen = {
  'move': true,
  'rotate': true,
  'reshape': true,
  'delete': true,
};
const Map<String, bool> kAllShut = {
  'move': false,
  'rotate': false,
  'reshape': false,
  'delete': false,
};

void main() {
  test('PM-8 each gate reads its own flag, live', () {
    final r = Rig();
    expect(r.open, kAllOpen);
    for (final name in kAllOpen.keys) {
      r.permissions = switch (name) {
        'move' => PlanPermissions.full.copyWith(move: false),
        'rotate' => PlanPermissions.full.copyWith(rotate: false),
        'reshape' => PlanPermissions.full.copyWith(reshape: false),
        _ => PlanPermissions.full.copyWith(delete: false),
      };
      // M-PM8: `PlanSelectGates.delete` drops `_permissions().delete &&`.
      expect(r.open, {...kAllOpen, name: false}, reason: name);
    }
    r.permissions = PlanPermissions.readOnly;
    expect(r.open, kAllShut);
    expect(r.gates.idleKeys, isTrue, reason: 'the keys are the shortcuts');
    r.gates.idleKeys = false;
    expect(r.gates.idleKeys, isFalse);
    // The pick and the band are the select tool's own.
    expect(r.gates.restrictsPick, isFalse);
  });

  test(
      'PM-9 a selection holding a locked object shuts every gate; a lock '
      'change or a selection change recomputes it', () {
    final r = Rig();
    r.selection.replace([SelectionKey.root(r.lines[0])]);
    expect(r.open, kAllOpen);
    // M-PM9a: `_locked.addListener(_recompute)` dropped: the lock arrives
    // after the selection.
    r.locked.value = {r.lines[0]};
    expect(r.gates.selectionLocked, isTrue);
    // M-PM9b: `&& super.move` (the lock) dropped from `move`.
    expect(r.open, kAllShut);
    // Another, unlocked object alone: open again.
    r.selection.replace([SelectionKey.root(r.lines[1])]);
    expect(r.open, kAllOpen);
    // Both: one locked object is enough.
    r.selection.replace(
        [SelectionKey.root(r.lines[1]), SelectionKey.root(r.lines[0])]);
    expect(r.open, kAllShut);
    r.locked.value = const {};
    expect(r.open, kAllOpen);
  });

  test('PM-10 a key inside a locked object (its chain) is locked too', () {
    final r = Rig();
    const group = Handle(0x7a31);
    r.locked.value = {group};
    final nested = SelectionKey(
        chain: Uint32List.fromList([group.value, 0x7a40]),
        chainLength: 2,
        target: r.lines[1]);
    r.selection.replace([nested]);
    // M-PM10: the chain loop of `_recompute` dropped.
    expect(r.gates.selectionLocked, isTrue);
    expect(r.open, kAllShut);
  });

  test('PM-11 dispose removes both listeners', () {
    final document = DraftDocument.empty();
    final selection = SelectionController(document);
    final locked = ValueNotifier<Set<Handle>>(const {});
    final gates = PlanSelectGates(
        permissions: () => PlanPermissions.full,
        selection: selection,
        locked: locked);
    gates.dispose();
    // A disposed gates object left as a listener would recompute here; the
    // notifiers report no listener instead.
    // ignore: invalid_use_of_protected_member
    expect(selection.hasListeners, isFalse);
    // ignore: invalid_use_of_protected_member
    expect(locked.hasListeners, isFalse);
    selection.dispose();
    locked.dispose();
  });
}
```

- [ ] **Step 4: Write the failing tests for the generic tools.** Create `test/tools/generic_tools_test.dart`:

```dart
// Spec P1 "Reserved ids", P2 "The keyboard" (Task 12): the plan library's
// own tools, their ids, letters and needs, and what buildGenericTools makes
// of them. The letters are today's (planner_shell.dart:517-623 for the
// generic rows); plan.symbol has none and is not built here (Task 14).
import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_2d_plan/src/tools/generic_tools.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

final class _Resolver implements MoveResolver {
  @override
  ({Transform2 transform, Vector2 marker})? resolveMove(
          ToolContext ctx, Handle node, Transform2 delta) =>
      null;
}

void main() {
  test('PM-12 the generic tools: ids, letters, needs and Fill, in order', () {
    expect([for (final t in genericTools) t.id], [
      'plan.select',
      'plan.line',
      'plan.polyline',
      'plan.rectangle',
      'plan.circle',
      'plan.arc',
      'plan.text',
    ]);
    // M-PM12: the letters of plan.line and plan.polyline swapped.
    expect([for (final t in genericTools) t.letter],
        ['V', 'L', 'P', 'R', 'C', 'A', 'T']);
    expect(genericTools.first.needs, isEmpty, reason: 'select only reads');
    for (final t in genericTools.skip(1)) {
      // Every drawing tool commits an AddEntityCommand (geometry).
      expect(t.needs, {Capability.geometry}, reason: t.id);
    }
    expect([for (final t in genericTools) if (t.fills) t.id],
        ['plan.polyline', 'plan.rectangle', 'plan.circle']);
    expect(PlanToolIds.all, [
      'plan.select',
      'plan.line',
      'plan.polyline',
      'plan.rectangle',
      'plan.circle',
      'plan.arc',
      'plan.text',
      'plan.symbol',
    ]);
    expect(PlanToolIds.symbolNeeds,
        {Capability.structure, Capability.geometry, Capability.components});
  });

  test(
      'PM-13 buildGenericTools: one tool per id, select with the gates and '
      'the resolver, the fill tools on the one toggle', () {
    final fill = ValueNotifier<bool>(false);
    final gates = SelectGates.all;
    final resolver = _Resolver();
    final set =
        buildGenericTools(gates: gates, fill: fill, moveResolver: resolver);
    addTearDown(() {
      set.dispose();
      fill.dispose();
    });
    expect(set.byId.keys, [for (final t in genericTools) t.id]);
    expect(set.byId['plan.select'], same(set.select));
    expect(set.select.gates, same(gates));
    expect(set.select.moveResolver, same(resolver));
    expect(set.byId['plan.line'], isA<LineTool>());
    expect(set.byId['plan.arc'], isA<ArcTool>());
    expect(set.byId['plan.text'], isA<TextTool>());
    // M-PM13: PolylineTool built without `fill`.
    expect((set.byId['plan.polyline']! as PolylineTool).fill, same(fill));
    expect((set.byId['plan.rectangle']! as RectangleTool).fill, same(fill));
    expect((set.byId['plan.circle']! as CircleTool).fill, same(fill));
    expect((set.byId['plan.line']! as LineTool).fill, isNull);
    final bare = buildGenericTools(gates: gates, fill: fill);
    addTearDown(bare.dispose);
    expect(bare.select.moveResolver, isNull, reason: 'Task 14 injects it');
  });
}
```

- [ ] **Step 5: Write the failing controller tests.** Create `test/controller/permissions_controller_test.dart`:

```dart
// Spec P2 "Permissions" at the controller (Task 12): the tool gate
// (ids and needs), a change at runtime, host calls not gated, deleteSelection
// and the document's engine permissions. Through the controller alone, its
// tools driven with ToolPointerEvents under a turned, flipped, off-origin
// camera (test/support/tool_events.dart). The kit-free controller: these are
// the plan library's own tools.
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/tool_events.dart';

final Vector2 a = Vector2(4120.5, -1415.25);
final Vector2 b = Vector2(4730.75, -1102.5);
final Vector2 mid = (a + b) * 0.5;
final Vector2 away = Vector2(5480.25, -1630.75);

PlanController make({PlanPermissions permissions = PlanPermissions.full}) {
  final c = PlanController(kits: const [], permissions: permissions);
  addTearDown(c.dispose);
  useTestCamera(c);
  return c;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the fixtures are not degenerate', () {
    expect(a.x != 0 && a.y != 0, isTrue);
    final c = make();
    expect(c.toolController.context.camera.value.scale,
        closeTo(kTestScale, 1e-12));
    expect(c.toolController.context.camera.value.worldToScreenMatrix.b,
        isNot(0), reason: 'a turned camera');
  });

  group('the tool gate', () {
    test(
        'PM-14 selectTool: select always; a tool the ids refuse is refused '
        'and changes nothing; an unknown id is refused', () {
      final c = make(
          permissions: PlanPermissions.full
              .copyWith(tools: {'plan.select', 'plan.arc'}));
      // M-PM14: `_allowsTool` drops the `_permissions.allowsTool(id)` test.
      expect(c.selectTool('plan.line'), isFalse);
      expect(c.activeTool.value, 'plan.select');
      expect(c.selectTool('plan.arc'), isTrue);
      expect(c.activeTool.value, 'plan.arc');
      expect(c.selectTool('acme.nothing'), isFalse);
      expect(c.activeTool.value, 'plan.arc');
      expect(c.selectTool('plan.select'), isTrue);
      expect(c.activeTool.value, 'plan.select');
      c.permissions = PlanPermissions.full;
      expect(c.selectTool('plan.line'), isTrue);
    });

    test(
        "PM-15 a tool's needs are checked against the document's engine "
        'permissions; select needs nothing', () {
      final c = make();
      c.document.commands.permissions = const DraftPermissions(
          transform: true, components: true, geometry: false, structure: true);
      // M-PM15: `_allowsTool` drops the needs test.
      for (final id in [
        'plan.line',
        'plan.polyline',
        'plan.rectangle',
        'plan.circle',
        'plan.arc',
        'plan.text',
      ]) {
        expect(c.selectTool(id), isFalse, reason: id);
      }
      expect(c.activeTool.value, 'plan.select');
      expect(c.selectTool('plan.select'), isTrue);
      expect(c.needsOf('plan.select'), isEmpty);
      expect(c.needsOf('plan.line'), {Capability.geometry});
      expect(c.needsOf('acme.nothing'), isNull);
    });
  });

  group('a change at runtime', () {
    test(
        'PM-16 plan.line one point in, then readOnly: select is armed, the '
        'pending point is gone, nothing was executed (M-H47)', () {
      final c = make();
      expect(c.selectTool('plan.line'), isTrue);
      tapAt(c, a);
      expect(c.toolController.active.isMidShape, isTrue, reason: 'premise');
      final state = c.document.commands.stateId;
      final depth = c.document.commands.undoDepth;
      var told = 0;
      void listener() => told++;
      c.addListener(listener);
      addTearDown(() => c.removeListener(listener));
      c.permissions = PlanPermissions.readOnly;
      // M-PM16: the setter drops its fallback to plan.select.
      expect(c.activeTool.value, 'plan.select');
      expect(told, isPositive, reason: 'the widgets rebuild');
      tapAt(c, away);
      tapAt(c, b);
      expect(c.document.commands.stateId, state);
      expect(c.document.commands.undoDepth, depth);
      c.permissions = PlanPermissions.full;
      expect(c.activeTool.value, 'plan.select', reason: 'no automatic return');
      expect(c.selectTool('plan.line'), isTrue);
      expect(c.toolController.active.isMidShape, isFalse,
          reason: 'the line starts afresh');
      // The same value again: no notification.
      final before = told;
      c.permissions = PlanPermissions.full;
      expect(told, before);
    });

    test(
        'PM-17 a body drag whose move gate closes before its up is cancelled '
        'at the change and executes nothing; kept open it moves (S-9 h)', () {
      final c = make();
      final line = drawLine(c, a, b);
      c.selection.replace([SelectionKey.root(line)]);
      final state = c.document.commands.stateId;
      dragFrom(c, mid, mid + Vector2(800, 0), beforeUp: () {
        expect(c.toolController.active.phase, ToolPhase.dragging,
            reason: 'premise: a drag under way');
        c.permissions = PlanPermissions.full.copyWith(move: false);
        // M-PM17: the setter drops its stale-drag cancel.
        expect(c.toolController.active.phase, ToolPhase.idle);
      });
      expect(c.document.commands.stateId, state);
      c.permissions = PlanPermissions.full;
      c.selection.replace([SelectionKey.root(line)]);
      dragFrom(c, mid, mid + Vector2(800, 0));
      expect(c.document.commands.stateId, isNot(state));
      expect(c.canUndo.value, isTrue);
    });

    test(
        "PM-18 the document's engine permissions follow the profile, and a "
        'new plan gets them too', () {
      final c = make();
      expect(c.document.commands.permissions, same(DraftPermissions.all));
      c.permissions = PlanPermissions.readOnly;
      expect(c.document.commands.permissions, same(DraftPermissions.readOnly));
      c.newPlan();
      // M-PM18: the per-document `commands.permissions = _permissions.draft`
      // dropped.
      expect(c.document.commands.permissions, same(DraftPermissions.readOnly));
      c.permissions = PlanPermissions.full;
      expect(c.document.commands.permissions, same(DraftPermissions.all));
    });
  });

  group('host calls and deleteSelection', () {
    test(
        "PM-19 a host's undo and redo under readOnly still work, and the "
        'profile is back afterwards', () {
      final c = make();
      final line = drawLine(c, a, b);
      expect(c.canUndo.value, isTrue);
      c.permissions = PlanPermissions.readOnly;
      // M-PM19: undo() without the permission lift (PermissionDeniedError).
      c.undo();
      expect(linesOf(c.document), isNot(contains(line)));
      expect(c.document.commands.permissions, same(DraftPermissions.readOnly));
      c.redo();
      expect(linesOf(c.document), contains(line));
      expect(c.document.commands.permissions, same(DraftPermissions.readOnly));
    });

    test(
        'PM-20 deleteSelection: false with nothing selected and under '
        'delete: false; true under full, one undo step (T5-c)', () {
      final c = make();
      final line = drawLine(c, a, b);
      expect(c.deleteSelection(), isFalse, reason: 'nothing selected');
      c.selection.replace([SelectionKey.root(line)]);
      c.permissions = PlanPermissions.full.copyWith(delete: false);
      final state = c.document.commands.stateId;
      // M-PM8 turns this red too (the gate's delete ignores the flag).
      expect(c.deleteSelection(), isFalse);
      expect(c.document.commands.stateId, state);
      expect(linesOf(c.document), contains(line));
      c.permissions = PlanPermissions.full;
      expect(c.deleteSelection(), isTrue);
      expect(linesOf(c.document), isNot(contains(line)));
      c.undo();
      expect(linesOf(c.document), contains(line));
    });
  });
}
```

- [ ] **Step 6: Run the tests and see them fail.** Run: `cd packages/jet_cad_2d_plan && flutter test test/controller/permissions_test.dart test/tools test/controller/permissions_controller_test.dart`. Expected: compilation errors naming `PlanPermissions`, `PlanSelectGates`, `genericTools`, `buildGenericTools`, `PlanToolIds`, `needsOf`, `selectGates` (no test runs). Quote the first error.

- [ ] **Step 7: `PlanPermissions`.** Create `lib/src/controller/permissions.dart`:

```dart
// Spec P2 "Permissions": what the plan's widgets let their user do. The
// select gates, the palette and selectTool, the panels and the controller's
// widget-facing commands read it; a host's own calls are not gated. 2b adds
// the service flags and a units-only profile.
import 'package:flutter/foundation.dart' show immutable, setEquals;
import 'package:jet_cad_2d/jet_cad_2d.dart' show DraftPermissions;
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart' show PlanGate;

/// The editor's permissions (spec P2).
///
/// - [tools]: the tool ids offered (the palette, the letters,
///   `PlanController.selectTool`); null offers every tool. `plan.select` is
///   always offered, whatever the set says. [copyWith] copies the set it
///   is given, unmodifiable; the `const` constructor keeps the set as
///   given.
/// - [move], [rotate], [mirror], [reshape], [delete]: the select tool's
///   gates and the panel's matching fields; [changeLayer], [recolor]: the
///   panel's layer field and colour row; [editLayers], [editPage]: the
///   Layer and Page panels; [undo]: the Undo and Redo buttons and chords;
///   [export], [print]: theirs. A property spec's `gate` names one of the
///   first nine ([allows]).
/// - [draft]: what the document's own `DraftPermissions` become.
@immutable
final class PlanPermissions {
  const PlanPermissions({
    this.tools,
    this.move = true,
    this.rotate = true,
    this.mirror = true,
    this.reshape = true,
    this.delete = true,
    this.changeLayer = true,
    this.recolor = true,
    this.editLayers = true,
    this.editPage = true,
    this.undo = true,
    this.export = true,
    this.print = true,
  });

  /// Every tool, every flag on: today's editor.
  static const PlanPermissions full = PlanPermissions();

  /// Select, pan and zoom; no edit, no undo. Export and print stay: neither
  /// is an edit.
  static const PlanPermissions readOnly = PlanPermissions(
    tools: {_select},
    move: false,
    rotate: false,
    mirror: false,
    reshape: false,
    delete: false,
    changeLayer: false,
    recolor: false,
    editLayers: false,
    editPage: false,
    undo: false,
  );

  static const String _select = 'plan.select';

  final Set<String>? tools;
  final bool move, rotate, mirror, reshape, delete;
  final bool changeLayer, recolor, editLayers, editPage;
  final bool undo, export, print;

  /// Whether the tool [id] is offered: `plan.select` always, else by
  /// [tools] (null: every id).
  bool allowsTool(String id) => id == _select || (tools?.contains(id) ?? true);

  /// Whether [gate]'s flag is on.
  bool allows(PlanGate gate) => switch (gate) {
        PlanGate.move => move,
        PlanGate.rotate => rotate,
        PlanGate.mirror => mirror,
        PlanGate.reshape => reshape,
        PlanGate.delete => delete,
        PlanGate.changeLayer => changeLayer,
        PlanGate.recolor => recolor,
        PlanGate.editLayers => editLayers,
        PlanGate.editPage => editPage,
      };

  /// Whether anything may be edited: an edit flag, or a tool other than
  /// `plan.select` (a drawing tool or a kit's).
  bool get edits =>
      move ||
      rotate ||
      mirror ||
      reshape ||
      delete ||
      changeLayer ||
      recolor ||
      editLayers ||
      editPage ||
      (tools?.any((id) => id != _select) ?? true);

  /// The document's engine permissions: [DraftPermissions.readOnly] when
  /// nothing may be edited ([edits] false), else [DraftPermissions.all].
  /// An engine group maps onto several flags, so it closes only when every
  /// one of them is off.
  DraftPermissions get draft =>
      edits ? DraftPermissions.all : DraftPermissions.readOnly;

  /// A copy with the given fields replaced; a null argument keeps the
  /// field (so `copyWith(tools: null)` keeps the set: start from [full] for
  /// every tool). A given [tools] is copied, unmodifiable.
  PlanPermissions copyWith({
    Set<String>? tools,
    bool? move,
    bool? rotate,
    bool? mirror,
    bool? reshape,
    bool? delete,
    bool? changeLayer,
    bool? recolor,
    bool? editLayers,
    bool? editPage,
    bool? undo,
    bool? export,
    bool? print,
  }) =>
      PlanPermissions(
        tools: tools == null ? this.tools : Set.unmodifiable(tools),
        move: move ?? this.move,
        rotate: rotate ?? this.rotate,
        mirror: mirror ?? this.mirror,
        reshape: reshape ?? this.reshape,
        delete: delete ?? this.delete,
        changeLayer: changeLayer ?? this.changeLayer,
        recolor: recolor ?? this.recolor,
        editLayers: editLayers ?? this.editLayers,
        editPage: editPage ?? this.editPage,
        undo: undo ?? this.undo,
        export: export ?? this.export,
        print: print ?? this.print,
      );

  /// The flags, in declaration order, by name.
  List<(String, bool)> get _flags => [
        ('move', move),
        ('rotate', rotate),
        ('mirror', mirror),
        ('reshape', reshape),
        ('delete', delete),
        ('changeLayer', changeLayer),
        ('recolor', recolor),
        ('editLayers', editLayers),
        ('editPage', editPage),
        ('undo', undo),
        ('export', export),
        ('print', print),
      ];

  @override
  bool operator ==(Object other) {
    if (other is! PlanPermissions || !setEquals(other.tools, tools)) {
      return false;
    }
    final a = other._flags, b = _flags;
    for (var i = 0; i < a.length; i++) {
      if (a[i].$2 != b[i].$2) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
      tools == null ? null : Object.hashAllUnordered(tools!),
      Object.hashAll([for (final (_, v) in _flags) v]));

  /// The fields that differ from [full], as `name: value`; the tools
  /// sorted.
  @override
  String toString() => 'PlanPermissions(${[
        if (tools case final t?) 'tools: {${(t.toList()..sort()).join(', ')}}',
        for (final (n, v) in _flags)
          if (!v) '$n: $v',
      ].join(', ')})';
}
```

(`toString` lists a flag only when it is `false`: every flag of `full` is `true`, so "differs from full" is "is false".)

- [ ] **Step 8: The gates.** Create `lib/src/tools/plan_select_gates.dart`. The lock half is Task 10's `LockGates` (`lib/src/kits/locks.dart`, a `base class`), extended, never copied:

```dart
// Spec P2 "Permissions" (the select gates: move, rotate, reshape, delete)
// and P4 "Locks" (the gates refuse a locked object), Task 12. One object on
// the select tool and on the grip cache, as today's shell shares one
// (planner_shell.dart:439-445, :648-657).
import '../controller/permissions.dart';
import '../kits/locks.dart' show LockGates;

/// The select tool's and the grip cache's gates: each drag kind and Delete
/// need their [PlanPermissions] flag, and a selection holding a locked
/// object (or a key inside one) shuts them all ([LockGates]).
///
/// The getters are read at every hover, key and frame (`SelectGates`'s
/// contract) and allocate nothing: the lock state is [LockGates]' cached
/// `bool`, and the permissions are read through one closure call.
final class PlanSelectGates extends LockGates {
  PlanSelectGates({
    required PlanPermissions Function() permissions,
    required super.selection,
    required super.locked,
  }) : _permissions = permissions;

  final PlanPermissions Function() _permissions;

  /// The select tool's idle keys (Escape, Delete, Backspace while no
  /// gesture runs): the shortcuts' option (Task 16 sets it).
  @override
  bool idleKeys = true;

  @override
  bool get move => _permissions().move && super.move;

  @override
  bool get rotate => _permissions().rotate && super.rotate;

  @override
  bool get reshape => _permissions().reshape && super.reshape;

  @override
  bool get delete => _permissions().delete && super.delete;
}
```

  `selectionLocked` and `dispose()` are `LockGates`'. If `flutter analyze` reports an unused import, delete it; change nothing else.

- [ ] **Step 9: The generic tools.** Create `lib/src/tools/generic_tools.dart`:

```dart
// Spec P1 "Reserved ids" and P2 "The keyboard" (Task 12): the plan
// library's own tools. plan.symbol is reserved here and built by Task 14;
// a kit's tools follow in the palette (Task 16).
import 'package:flutter/foundation.dart' show ValueListenable, immutable;
import 'package:flutter/material.dart' show IconData, Icons;
import 'package:jet_cad_2d/jet_cad_2d.dart' show Capability;
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

/// The plan library's reserved tool ids (spec P1).
abstract final class PlanToolIds {
  static const String select = 'plan.select';
  static const String line = 'plan.line';
  static const String polyline = 'plan.polyline';
  static const String rectangle = 'plan.rectangle';
  static const String circle = 'plan.circle';
  static const String arc = 'plan.arc';
  static const String text = 'plan.text';
  static const String symbol = 'plan.symbol';

  static const List<String> all = [
    select,
    line,
    polyline,
    rectangle,
    circle,
    arc,
    text,
    symbol,
  ];

  /// What a symbol placement commits (today's `kSymbolPlacementNeeds`,
  /// `symbol_panel.dart:28-32`): the definition copy, its leaves, its
  /// `jetcad.symbol` component.
  static const Set<Capability> symbolNeeds = {
    Capability.structure,
    Capability.geometry,
    Capability.components,
  };
}

/// One generic tool as the palette and the keyboard see it.
@immutable
final class GenericTool {
  const GenericTool({
    required this.id,
    required this.icon,
    required this.letter,
    required this.needs,
    this.fills = false,
  });

  final String id;
  final IconData icon;

  /// Today's letter (spec P2: V L P R C A T).
  final String letter;

  /// What the tool's commits need (`PlanTool.needs`' meaning).
  final Set<Capability> needs;

  /// Whether the Fill toggle applies to it.
  final bool fills;
}

/// The generic tools in palette order (today's rows for them,
/// `planner_shell.dart:517-623`).
const List<GenericTool> genericTools = [
  GenericTool(
      id: PlanToolIds.select,
      icon: Icons.north_west,
      letter: 'V',
      needs: <Capability>{}),
  GenericTool(
      id: PlanToolIds.line,
      icon: Icons.horizontal_rule,
      letter: 'L',
      needs: {Capability.geometry}),
  GenericTool(
      id: PlanToolIds.polyline,
      icon: Icons.polyline,
      letter: 'P',
      needs: {Capability.geometry},
      fills: true),
  GenericTool(
      id: PlanToolIds.rectangle,
      icon: Icons.crop_square,
      letter: 'R',
      needs: {Capability.geometry},
      fills: true),
  GenericTool(
      id: PlanToolIds.circle,
      icon: Icons.circle_outlined,
      letter: 'C',
      needs: {Capability.geometry},
      fills: true),
  GenericTool(
      id: PlanToolIds.arc,
      icon: Icons.looks,
      letter: 'A',
      needs: {Capability.geometry}),
  GenericTool(
      id: PlanToolIds.text,
      icon: Icons.title,
      letter: 'T',
      needs: {Capability.geometry}),
];

/// One document's generic tools: [select] and every tool by id, in
/// [genericTools] order.
final class GenericToolSet {
  GenericToolSet._(this.select, this.byId);

  final SelectTool select;
  final Map<String, Tool> byId;

  void dispose() {
    for (final tool in byId.values) {
      tool.dispose();
    }
  }
}

/// Builds the generic tools over [gates] (the select tool's), [fill] (the
/// polyline's, the rectangle's and the circle's) and [moveResolver] (null
/// until Task 14 injects plan.symbol's).
GenericToolSet buildGenericTools({
  required SelectGates gates,
  required ValueListenable<bool> fill,
  MoveResolver? moveResolver,
}) {
  final select = SelectTool(moveResolver: moveResolver, gates: gates);
  return GenericToolSet._(select, {
    PlanToolIds.select: select,
    PlanToolIds.line: LineTool(),
    PlanToolIds.polyline: PolylineTool(fill: fill),
    PlanToolIds.rectangle: RectangleTool(fill: fill),
    PlanToolIds.circle: CircleTool(fill: fill),
    PlanToolIds.arc: ArcTool(),
    PlanToolIds.text: TextTool(),
  });
}
```

- [ ] **Step 10: The session and the controller.** In `lib/src/controller/plan_controller.dart` (Task 8) and, for item 3, `lib/src/controller/session.dart`, make these edits. Each names the member Task 8 (or Tasks 10-11) wrote; the code shown is the full new body.

  1. Imports: `package:meta/meta.dart' show internal`, `'permissions.dart'`, `'../tools/generic_tools.dart'`, `'../tools/plan_select_gates.dart'`.
  2. Fields (controller-level, kept across document swaps):

```dart
  PlanPermissions _permissions;
  final ValueNotifier<bool> _fill = ValueNotifier<bool>(false);
  final Map<String, Set<Capability>> _toolNeeds = <String, Set<Capability>>{};
```

     Task 8's factory and private constructor gain the named parameter `PlanPermissions permissions = PlanPermissions.full` (spec P2; Task 8 leaves it to this task), passed through and assigned to `_permissions` in the private constructor's initialiser list; dispose `_fill` in `dispose()`.
  3. Per-document members: they live in `DocumentSession` (Shared interfaces), built in its constructor and owned by it.
     - In `session.dart`, import `../tools/generic_tools.dart` and `../tools/plan_select_gates.dart`. The constructor gains `required PlanPermissions Function() permissions` and `required ValueListenable<bool> fill` (import `permissions.dart`). Task 10's field `late final LockGates lockGates;` becomes `late final PlanSelectGates gates;` and the session gains `late final GenericToolSet generic;`. In the constructor body:
       - `lockGates = LockGates(selection: selection, locked: locked);` (right after the `SelectionController`, before the `OutlineCache` and the `GripCache`, so its selection listener runs before theirs) becomes `gates = PlanSelectGates(permissions: permissions, selection: selection, locked: locked);`, and the `GripCache`'s `gates: lockGates` becomes `gates: gates` (Task 10's L-6 and L-10 stay green: `PlanSelectGates` is a `LockGates`).
       - `select = SelectTool(gates: lockGates);` becomes, so that the session holds exactly one `plan.select` (the gated one):

```dart
    generic = buildGenericTools(gates: gates, fill: fill);
    select = generic.select;
```

       - right after Task 11's three lines that register the guarded select entry and make the `ToolController`, add the other generic tools, before any kit tool (`runKitFactories` runs later, from `_open`):

```dart
    for (final e in generic.byId.entries) {
      if (e.key != planSelectToolId) addTool(e.key, e.value);
    }
```

       - In `dispose()`, `lockGates.dispose();` becomes `gates.dispose();`. The generic tools are in the map, which `dispose()` already disposes (each through its `GuardedTool`): **never** call `generic.dispose()` from the session or the controller (a second dispose of a `Tool`, a `ChangeNotifier`, fails a debug assertion). `GenericToolSet.dispose` stays for a set no session holds (the unit tests of Step 4).
     - In `plan_controller.dart`, Task 8's `_open`: before the `DocumentSession(...)` call, `document.commands.permissions = _permissions.draft;` (before any system is installed); the call gains `permissions: () => _permissions, fill: _fill`. Register the needs once per document, before the kit tools:

```dart
    for (final t in genericTools) {
      _toolNeeds[t.id] = t.needs;
    }
    for (final kit in kits.kits) {
      for (final planTool in kit.tools) {
        _toolNeeds[planTool.id] = planTool.needs;
      }
    }
```

       `_toolNeeds` is not cleared: the ids are the same for every document of one controller.
  4. The tool gate (Task 8 left `_allowsTool` returning `true`):

```dart
  /// Whether [id] may be armed: offered by the permissions' ids, a tool
  /// this controller knows, and every capability its commits need allowed
  /// by the document's engine permissions (spec P2).
  bool _allowsTool(String id) {
    if (!_permissions.allowsTool(id)) return false;
    final needs = _toolNeeds[id];
    if (needs == null) return false;
    final engine = document.commands.permissions;
    for (final c in needs) {
      if (!engine.allows(c)) return false;
    }
    return true;
  }

  /// [id]'s needs, or null for an id this controller does not know.
  @internal
  Set<Capability>? needsOf(String id) => _toolNeeds[id];

  /// For Task 14's plan.symbol, which is built outside the generic set.
  @internal
  void registerToolNeeds(String id, Set<Capability> needs) =>
      _toolNeeds[id] = needs;
```

  5. Permissions at runtime (spec P2 "Host calls and runtime changes"; the stale-drag rule ported from `planner_shell.dart:1077-1084`, without `selectTablesOnly`, which is 2b's):

```dart
  /// The editor's permissions. Settable at runtime: the widgets rebuild
  /// (this notifies), the document's engine permissions follow
  /// ([PlanPermissions.draft]), a drag whose gate closes is cancelled now,
  /// and an active tool no longer allowed is cancelled and plan.select
  /// armed.
  PlanPermissions get permissions => _permissions;
  set permissions(PlanPermissions value) {
    if (value == _permissions) return;
    final old = _permissions;
    _permissions = value;
    document.commands.permissions = value.draft;
    final select = _session.select;
    final stale = switch (select.dragKind) {
      DragKind.move => old.move && !value.move,
      DragKind.rotate => old.rotate && !value.rotate,
      DragKind.reshape => old.reshape && !value.reshape,
      DragKind.band || null => false,
    };
    if (stale) select.cancel(toolController.context);
    grips.gatesChanged();
    if (!_allowsTool(activeTool.value)) selectTool(PlanToolIds.select);
    notifyListeners();
  }

  @internal
  PlanSelectGates get selectGates => _session.gates;

  @internal
  SelectTool get planSelect => _session.select;

  /// The Fill toggle (Task 16's palette row and F key).
  @internal
  ValueNotifier<bool> get fill => _fill;
```

  6. Host undo and redo (spec P2: host calls are not gated). Replace the `commands.undo()` / `commands.redo()` call inside Task 8's `undo()` / `redo()` (after its mid-shape check and settle) with `_unrestricted(commands.undo)` / `_unrestricted(commands.redo)`, and add:

```dart
  /// Runs [step] with the document's engine permissions lifted, then puts
  /// them back: a host's undo or redo is not gated (spec P2), and the
  /// dispatcher checks permissions on undo and redo too (undo.dart:213).
  void _unrestricted(void Function() step) {
    final commands = document.commands;
    final saved = commands.permissions;
    commands.permissions = DraftPermissions.all;
    try {
      step();
    } finally {
      commands.permissions = saved;
    }
  }
```

  7. `deleteSelection()`: after Task 8's mid-shape check and settle, its deleting call is the select tool's own, through the gates (today's `_deleteByHost`, `planner_shell.dart:960`):

```dart
    return _session.select.deleteSelection(toolController.context);
```

- [ ] **Step 11: The barrel.** In `lib/jet_cad_2d_plan.dart` add `export 'src/controller/permissions.dart';` (in the barrel's sorted position).

- [ ] **Step 12: Run the tests.** Run: `cd packages/jet_cad_2d_plan && flutter test test/controller/permissions_test.dart test/tools test/controller/permissions_controller_test.dart`. Expected: `All tests passed!`. Then run the whole suite: `flutter test`. Expected: `All tests passed!` (Tasks 8, 10 and 11's tests unchanged).

- [ ] **Step 13: Format and the gate.** `cd packages/jet_cad_2d_plan && dart format . && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .` — each exits 0. `git status --short` lists only this task's files.

- [ ] **Step 14: Commit.**

```bash
git add packages/jet_cad_2d_plan/lib/src/controller/permissions.dart packages/jet_cad_2d_plan/lib/src/tools/plan_select_gates.dart packages/jet_cad_2d_plan/lib/src/tools/generic_tools.dart packages/jet_cad_2d_plan/lib/src/controller/plan_controller.dart packages/jet_cad_2d_plan/lib/src/controller/session.dart packages/jet_cad_2d_plan/lib/jet_cad_2d_plan.dart packages/jet_cad_2d_plan/test/support/tool_events.dart packages/jet_cad_2d_plan/test/controller/permissions_test.dart packages/jet_cad_2d_plan/test/tools/plan_select_gates_test.dart packages/jet_cad_2d_plan/test/tools/generic_tools_test.dart packages/jet_cad_2d_plan/test/controller/permissions_controller_test.dart
git commit -m "$(cat <<'EOF'
feat(plan): permissions and the generic tools (P2)

PlanPermissions carries the tool ids and the edit flags, with the full
and readOnly profiles; the document's engine permissions close only when
nothing may be edited. The select tool and the grip cache share one
gates object over the flags and the locked set. plan.select, line,
polyline, rectangle, circle, arc and text are built per document;
selectTool checks the ids and each tool's needs, a runtime change cancels
a forbidden tool or drag, and a host's undo and redo stay ungated.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 15: Mutation check** (on the committed files; after each: run the named test, quote its red line, `git checkout -- <file>`, `git diff --quiet -- <file>` exits 0):
  - M-PM1 `permissions.dart`: delete `undo: false,` from `readOnly` → PM-1 red.
  - M-PM2 `permissions.dart`: `move: move ?? this.move,` → `move: this.move,` → PM-2 red.
  - M-PM3 `permissions.dart`: `|| !setEquals(other.tools, tools)` deleted → PM-3 red.
  - M-PM4 `permissions.dart`: `id == _select || ` deleted from `allowsTool` → PM-4 red.
  - M-PM5 `permissions.dart`: swap the right-hand sides of `PlanGate.move => move` and `PlanGate.rotate => rotate` → PM-5 red.
  - M-PM6a `permissions.dart`: `draft` returns `DraftPermissions.all` → PM-6 red; M-PM6b: delete the `|| (tools?.any(...) ?? true)` term of `edits` → PM-6 red.
  - M-PM8 `plan_select_gates.dart`: `delete` returns `super.delete` (the permission dropped) → PM-8 red (and PM-20).
  - M-PM9a `lib/src/kits/locks.dart`: in `LockGates`' constructor, delete `_locked.addListener(_recompute);` → PM-9 red; M-PM9b `plan_select_gates.dart`: `move` returns `_permissions().move` (the lock dropped) → PM-9 red.
  - M-PM10 `lib/src/kits/locks.dart`: in `LockGates._recompute`, delete the `for (var i = 0; i < chain.length && !hit; i++)` loop → PM-10 red.
  - M-PM12 `generic_tools.dart`: swap `letter: 'L'` and `letter: 'P'` → PM-12 red.
  - M-PM13 `generic_tools.dart`: `PolylineTool(fill: fill)` → `PolylineTool()` → PM-13 red.
  - M-PM14 `plan_controller.dart`: delete `if (!_permissions.allowsTool(id)) return false;` → PM-14 red.
  - M-PM15 `plan_controller.dart`: delete the `for (final c in needs)` loop of `_allowsTool` → PM-15 red.
  - M-PM16 `plan_controller.dart`: delete `if (!_allowsTool(activeTool.value)) selectTool(PlanToolIds.select);` → PM-16 red.
  - M-PM17 `plan_controller.dart`: delete `if (stale) select.cancel(toolController.context);` → PM-17 red.
  - M-PM18 `plan_controller.dart`: delete the per-document `document.commands.permissions = _permissions.draft;` → PM-18 red.
  - M-PM19 `plan_controller.dart`: `_unrestricted(commands.undo)` → `commands.undo()` → PM-19 red (`PermissionDeniedError`).

#### Assumed from earlier tasks

- Task 3: `enum PlanGate { move, rotate, mirror, reshape, delete, changeLayer, recolor, editLayers, editPage }` exported from `package:jet_cad_2d_kit/jet_cad_2d_kit.dart`.
- Task 4: `PlanTool.id`, `PlanTool.needs` (`Set<Capability>`).
- Task 8 (`PlanController`):
  - `PlanController({required List<PlanKit> kits, String? json, ...})` (this task adds `PlanPermissions permissions = PlanPermissions.full`, Step 10); `DraftDocument get document`; `void newPlan({String? decimalSeparator})`; `bool selectTool(String id)` that consults a private `bool _allowsTool(String id)`; `ValueListenable<String> get activeTool` (the active tool's id); `bool deleteSelection()`; `void undo()`, `void redo()` (mid-shape no-op, then settle); `ValueListenable<bool> get canUndo`; `ChangeNotifier` (`addListener`).
  - `@internal` accessors: `ToolController get toolController` (whose `context` is the current document's `ToolContext`), `SelectionController get selection`, `GripCache get grips`.
  - `DocumentSession` (`lib/src/controller/session.dart`): its constructor builds one document's views (Tasks 10-11 extend it), `_open` (shared by the constructor, `load`, `newPlan`, `import`) makes one per document, `dispose()` runs one frame after a swap, and its id → `Tool` map (`_entries`, `addTool`, `toolById`) owns every tool and is what `selectTool` arms.
- Task 10: `ValueListenable<Set<Handle>> PlanController.locked`.
- Task 11: every tool of the map is wrapped in `GuardedTool`, which forwards `phase`, `isMidShape` and the pointer calls (the tests read `toolController.active.phase` and `.isMidShape`).

---


# The interaction core — design

**Date:** 2026-09-21. **Status:** design, **revision 1**, not yet a plan.
**Sub-project:** `roadmap/02-interaction-core.md`. **Size:** L.
**Brainstormed with the human on 2026-09-21**, on `main` at `1909a5e`, the
day Plan 01 closed with its exit gate at 12 of 12.
**Depends on:** 01 (merged at `bae5f73`). **Blocks:** 03, 05, 06, 09, 12 —
everything with a user in it.

**Evidence of record.** Every claim below about what exists was read from the
tree at `1909a5e` on 2026-09-21, files cited by line:
`packages/jet_cad_2d/lib/src/index/spatial_index.dart` (`forEachInRect` 271,
`forEachInstanceInRect` 299, `pickInto` 452, `_descend` 517, `_writeChain`
1057 — the chain holds **instance** handles only, one per descent level, never
groups), `index/hit.dart` (`HitPath` 27, `HitKind` 11; the doc comment at
14-18 already names the policy this spec adopts: *"a viewer selects
`chain[0]`, the root-level ancestor"*), `index/query_filter.dart`
(`QueryFilter.picking()` 27: visible and unlocked), `index/container_index.dart`
(`boxOfLeaf` 758, `transformOfInstance` 581), `geometry/segment_clip.dart`
(`clipSegment` 22, Liang–Barsky; `circleClipWindows` 92),
`geometry/distance.dart` (`insideClosedPolyline` 152),
`geometry/primitives.dart` (`arcBounds` 82), `document/text_geometry.dart`
(`textLocalTransform` 310, `textLocalBounds` 325), `document/node.dart`
(`GroupNode.children` 70 holds **nodes only**; a leaf's container is
`EntityRecord.owner`, `store/entity_store.dart` 36), `document/tree.dart`
(`ancestorsOf` 240, `accumulatedTransform` 266), `document/commands.dart`
(`RemoveEntityCommand` 124, `RemoveNodeCommand` 360 — **does not cascade**:
`tree.removeNode` unlinks the node and nothing else), `document/command.dart`
(`DraftPermissions` 30, `Capability` 15), `document/undo.dart`
(`CommandDispatcher` 48, `permissions` 54, `execute` 102 — `onAfterMutate` is
a single slot and the index owns it, `spatial_index.dart` 139),
`document/doc_change.dart` (1-8: *"Selection is deliberately absent:
selection is view state and belongs to the widget layer's own controller"*),
`packages/jet_cad_2d_flutter/lib/src/draft_canvas.dart` (`RepaintBoundary >
CustomPaint` 465, `onPaintForTest` 171, `shouldRepaint` 636 — false on the
vertices path), `camera_gesture_detector.dart` (a `Listener`, middle button
and wheel only), `apps/floor_planner/lib/main.dart` (chrome keys 60-84, no
`Focus`, no `Shortcuts`), `test/support/gesture_fixture.dart`
(`fitOffOrigin` 21, `kDetectorTopLeft` 10) and `test/support/spy_canvas.dart`
(`RecordedCall.strokeWidth` 38). No compound command exists anywhere in
`packages/jet_cad_2d/lib` (grep `compound|Batch|MultiCommand`: none).

`flutter_diagram_editor` (Arokip, MIT) was read at `master` as the roadmap
asks. Its current master has **no** tool or mode concept, **no** selection
state, **no** keyboard handling; canvas-vs-component drag is resolved by
nesting `GestureDetector`s in the arena, and `ComponentHighlightPainter` is
an unwired per-component dashed rectangle. One idea transfers: default
behaviours run before user callbacks. Nothing else does. Notes of record:
[2026-09-21-flutter-diagram-editor-notes.md](../notes/2026-09-21-flutter-diagram-editor-notes.md).

---

## What this delivers

Clicking an entity selects it. Clicking empty space clears. Shift-click
toggles. Dragging from empty space draws a rubber band: left-to-right selects
what it **encloses**, right-to-left what it **touches**. Hovering highlights
what a click would select. Selected and hovered things are outlined in a
distinct colour, at constant screen width, at every zoom. Escape cancels a
band or clears the selection; Delete removes the selection through the
command log so undo works. A **tool state machine** exists, with
`SelectTool` as its first tool and an interface every later tool implements.
The app's top bar shows the active tool's name and the selection count.

## Non-goals

- Grips, move, rotate, scale, snapping while dragging — 03. A press on an
  entity followed by a drag does nothing in 02 beyond selecting on release;
  03 turns it into a move.
- Double-click to enter a group or block and pick its leaves — deferred, see
  [Open questions](#open-questions). 02 selects **root-level objects** only.
- Compound (single-step) undo for a multi-object delete — 06's spike. A
  delete of N objects is N undo steps in 02, and the spec says so where it
  happens (D10).
- Any drawing tool, property panel, layer panel, or persistence of
  selection. Selection is never serialised (roadmap decision 1).
- Touch. Desktop mouse and trackpad; a touch pointer is treated as the primary
  button and nothing more is designed for it.
- Changing `DraftCanvas`, `DraftPainter`, the tile cache or the harness.

## Decisions

Decisions D1–D4 were made by the human during the brainstorm. D5–D12 are the
design's, made in the sections the human approved.

### D1 — Rubber band: the CAD convention (human)

Left-to-right drag = **window**, selects only what the band fully encloses.
Right-to-left = **crossing**, selects anything the band touches. Direction is
read in screen space from the x component alone: `end.dx >= start.dx` is a
window. Each mode has its own band styling (D9).

### D2 — A click selects the root-level object (human)

A `HitPath` resolves to the thing directly under the root:

| hit | selected |
|---|---|
| a leaf reached through one or more instances (`chainLength > 0`) | the **root-level instance**, `chain[0]` |
| a root-container leaf whose `owner` is a group | the **topmost group** under the root — walk `tree.ancestorsOf(owner)` and take the last node that is a `GroupNode` before the root |
| a root-container leaf owned by the root | the leaf itself |

Clicking two different leaves of one instance selects that instance once.
Clicking the same leaf handle under two instances selects two things. The
identity that makes both true is D6's key, and the full `HitPath` copy it
carries is what lets a later sub-project descend without changing the type.

### D3 — Keys: shift toggles, Escape cancels or clears, Delete removes (human)

Plain click or band **replaces** the selection; with shift held it **toggles**
membership of what was picked. Escape during a band drops the band and leaves
the selection alone; Escape when idle clears the selection. Delete and
Backspace remove the selection (D10). No other key or modifier does anything
in 02. Ctrl/cmd-click is reserved, unbound.

### D4 — The tool machine: a `Tool` object with event methods and its own overlay paint (human)

Approach A of three offered. One class per tool; input handling and preview
painting live together; cancellation and switching are one method. The tool's
phase is exposed as a read-only enum so tests and the status line can see it.
Rejected: an explicit sealed-state reducer (five clients pay the boilerplate
five times) and the reference library's flat callback wiring (each of 03, 05,
09, 11 would re-wire a private answer — the roadmap's own warning).

### D5 — Package split

| package | gets |
|---|---|
| `jet_cad_2d` | `BandMode`, `forEachLeafInBand`, `forEachInstanceInBand` on `SpatialIndex` — the query side, next to `pickInto`. Pure Dart, no `dart:ui`. |
| `jet_cad_2d_flutter` | `SelectionKey`, `SelectionController`, `Tool`, `ToolContext`, `ToolPointerEvent`, `ToolPhase`, `ToolController`, `SelectTool`, `InteractionLayer`, `SelectionOverlay`, the colour and size constants |
| `apps/floor_planner` | wires them in `planner_view.dart`; the top bar gains the tool name and count |

The engine gets the geometry because the exact window/crossing predicates
need the leaf payloads, the composed instance transforms and the reentrancy
guard, all of which are the index's. The widget layer gets everything that
knows about pointers, keys, colours or `Canvas`. `dev_harness_2d` is not
touched; `git diff --stat main..HEAD -- apps/dev_harness_2d` stays empty.

### D6 — Selection identity: a copied chain plus a leaf, or a container itself

```dart
/// What is selected: the instance chain above a leaf, or a container itself.
final class SelectionKey {
  SelectionKey({required Uint32List chain, required this.entity})
      : chain = Uint32List.fromList(chain);   // own copy, never HitPath's buffer

  /// Instance handles, root first. Empty for a root-level thing.
  final Uint32List chain;

  /// The leaf, or [Handle.none] when the container named last in [chain]
  /// is itself the selection.
  final Handle entity;

  // `==` and `hashCode` over the chain element-wise, then `entity`.
}
```

D2 produces: an instance → `chain = [chain[0]]`, `entity = Handle.none`; a
group → `chain = []`, `entity = group`; a loose leaf → `chain = []`,
`entity = leaf`. **The chain is part of identity.** A key equality that
compares `entity` alone collapses every selected instance to `(none)` — that
is mutant M-02c, and the two-instance test kills it.

```dart
class SelectionController extends ChangeNotifier {
  Set<SelectionKey> get keys;          // unmodifiable view
  int get length; bool get isEmpty;
  bool contains(SelectionKey key);
  void replace(Iterable<SelectionKey> keys);
  void toggle(Iterable<SelectionKey> keys);
  void clear();
}
```

One `notifyListeners` per call, and **none when the set did not change** —
the same rule the camera clamp follows (01's D4). Selection is application
state: never in the document, never in the codec, never undone.

### D7 — Pick radius is a screen-pixel constant, converted per event

`kPickRadiusPixels = 6.0` logical pixels. `InteractionLayer` computes
`pickRadiusWorld = kPickRadiusPixels / camera.value.scale` for every event it
forwards, so the target stays the same size on screen at every zoom.
`pickInto` decides vertex over edge over fill, and ties, exactly as it does
today; `Tolerance` stays where it is, inside the engine's geometric decisions.
Nothing in this sub-project compares a stored value with a tolerance.

### D8 — Band queries live in the engine, exact, and descend into instances

```dart
enum BandMode { window, crossing }

/// Root-container leaves the band selects, ascending handle order.
void forEachLeafInBand(
    Aabb2 world, BandMode mode, QueryFilter filter, void Function(int slot) visit);

/// Root-level instances the band selects, ascending handle order. Descends
/// into the definition with composed transforms and tests leaf geometry.
void forEachInstanceInBand(
    Aabb2 world, BandMode mode, QueryFilter filter, void Function(Handle instance) visit);
```

| mode | a leaf | an instance |
|---|---|---|
| **window** | its world AABB (`boxOfLeaf`) ⊆ band. Tight for point, line, polyline, circle and arc (`arcBounds`); **conservative for rotated text** — the AABB of an oriented box is looser than the box, so a rotated text near the band edge may be missed. Documented, accepted. | its world box ⊆ band |
| **crossing** | broad phase: AABB overlaps band. Exact phase: **some point of the stroke lies inside the band.** Line and polyline segments: `clipSegment` returns true. Circle: `circleClipWindows` returns non-zero (or −1, fully inside). Arc: a clip window intersects the sweep (`angleInSweep`). Text and attrib: the oriented box's four edges as segments (`textLocalTransform` × `textLocalBounds`). Fill: its boundary polyline's segments. Point: `containsPoint`. Enclosed ⇒ touched, so no second case. **A band lying wholly inside a closed shape touches no stroke and selects nothing** — CAD behaviour. | any leaf under it, at any depth, passes the crossing test in world space with the composed transform (`toWorld.multiply(transformOfInstance)` per level, as `_descend` does). A circle or arc under a non-uniform scale uses the same approximated-radius rule `pickInto` uses, so pick and band agree. |

Both walks take the reentrancy guard (`_beginQuery`/`_endQuery`), reject by
`QueryFilter` the way the rect queries do, and report in ascending handle
order. They run at pointer-up rate, off the frame path; they may allocate
O(results) but must not walk the whole document — the broad phase is the
R-tree search, as for `forEachInRect`. A group-owned leaf is reported by the
leaf walk as a slot; resolving it to its topmost group is the tool's job (D2),
and **a group is selected when any member is** (window or crossing alike).

### D9 — The overlay: a sibling painter with cached world-space paths

`SelectionOverlay extends CustomPainter` sits in its own `RepaintBoundary`
above `DraftCanvas` in a `Stack`. Its `repaint` is
`Listenable.merge([selection, toolController, camera])`, where
`ToolController` forwards its active tool's notifications; `shouldRepaint`
returns `false`, the canvas's discipline. A selection change therefore cannot
repaint the drawing: `DraftCanvas.onPaintForTest` stays flat while the
overlay's own `onPaintForTest` counts (M-02q, M-02e).

**The overlay never walks the document.** Each key's outline is built once,
in world space, as a `ui.Path`, when the key enters the selection or becomes
the hover: line and polyline as segments, circle and arc as arcs, text and
attrib as the oriented box, fill as its boundary, an instance by walking its
definition with composed transforms (nested instances included; a group
inside a definition via `accumulatedTransform`), a group as the union of its
members' outlines. Per frame the painter does `save`, `clipRect`,
`transform(camera.worldToScreenMatrix)`, one `drawPath` per selected key
with the selection paint, one for the hover key if it is not selected with
the hover paint, `restore`, then `tool.paintOverlay(canvas, camera, viewport)`
in screen space. Stroke widths are `kSelectionStrokePixels / camera.scale`
(2.0 px) and `kHoverStrokePixels / camera.scale` (1.5 px) so they hold on
screen at any zoom (M-02m). Constants — `kSelectionColor`, `kHoverColor`,
`kWindowBandColor`, `kCrossingBandColor`, `kBandFillAlpha`, the two stroke
widths — live in one file, `selection_style.dart`.

Cache lifecycle: built on entry, dropped on exit; on a `DocChange` whose
`touched` contains any handle of a key, the key is re-resolved — gone →
dropped (D11), still present → path rebuilt (03's move needs this).
`DocumentLoaded` and `DocumentPurged` clear everything. Allocation happens at
selection-change rate, never inside `paint`.

Band paint (the tool's): window = solid 1 px stroke in `kWindowBandColor`
with a `kBandFillAlpha` fill; crossing = dashed 1 px stroke in
`kCrossingBandColor` with the same fill. Screen space, no camera transform.

### D10 — Delete: one command per object, permission-checked, cascading through groups

For each selected key, in ascending handle order of the selected object:

| selected | command | capability checked |
|---|---|---|
| loose leaf | `RemoveEntityCommand(entity)` | `geometry` |
| root-level instance | `RemoveNodeCommand(chain[0])` | `structure` |
| group | its owned leaves (`RemoveEntityCommand` each), its child instances (`RemoveNodeCommand` each), nested groups recursively the same way, then `RemoveNodeCommand(group)` | `geometry` for the leaves, `structure` for the nodes; the group is deleted only if **every** command in its cascade is permitted |

The cascade exists because `RemoveNodeCommand` unlinks the node and nothing
else: deleting a group alone would leave its leaves with an `owner` that no
longer resolves. Objects the permissions refuse stay selected and untouched;
the rest go. A read-only document (`DraftPermissions.readOnly`) is fully
selectable and Delete is a no-op on it (M-02n). **A delete of N objects is N
undo steps** (or more, for a group); this is recorded here as debt that 06's
compound undo retires, and the results note must say so in as many words.
The tool clears the selection of what it deleted before executing, so the
overlay never paints a key the document no longer has.

### D11 — Pruning listens to `document.changes`

`SelectionController` subscribes to `document.changes` (an async broadcast
stream; `onAfterMutate` is a single sync slot the index already owns). On
every `DocChange` it re-resolves each key: `entity` must still be in
`entities` (a leaf) or `tree` (a node), and every chain handle must still be
an `InstanceNode`. Keys that fail are dropped, one notify if anything
changed. Delivery is before the next frame, so an external
`RemoveEntityCommand` cannot leave a dead key painted. Undo of a delete does
**not** restore the selection: selection is not undoable (roadmap decision 1).

### D12 — The app's thin affordance: tool name and count in the top bar

`chrome-top` gains one `Text` at its left: `"Select — 3 selected"`, `"Select"`
when empty, rebuilt from `ListenableBuilder` over the selection and tool
controllers. Keyed `status-text` for the widget test. That is all the UI 02
adds; 12 consolidates.

---

## Architecture

Widget tree in `planner_view.dart`, outside in:

```
CameraGestureDetector            01, unchanged: middle drag, wheel, trackpad
  InteractionLayer               Focus(autofocus) + MouseRegion(onExit) + Listener(opaque)
    Stack
      RepaintBoundary DraftCanvas                  unchanged
      RepaintBoundary CustomPaint(SelectionOverlay)  repaint: selection | tool | camera
```

Both pointer handlers are `Listener`s, so there is no arena: every pointer
event reaches both, each ignores what is not its own. `InteractionLayer`
forwards events whose `buttons` include `kPrimaryButton` (plus hover and up),
ignores events whose only button is the middle one, ignores `PointerPanZoom*`
and `PointerSignal` entirely. It builds a `ToolPointerEvent` per event:

```dart
final class ToolPointerEvent {
  final Offset screen;          // local to the layer
  final Vector2 world;          // camera.value.screenToWorld(screen)
  final int buttons;
  final bool shift, control, meta, alt;   // HardwareKeyboard at dispatch time
  final double pickRadiusWorld; // kPickRadiusPixels / camera.value.scale
}

final class ToolContext {
  final DraftDocument document;
  final SpatialIndex index;
  final CameraController camera;
  final SelectionController selection;
  void execute(DraftCommand command) => document.commands.execute(command);
}

enum ToolPhase { idle, pressed, dragging }

abstract class Tool extends ChangeNotifier {
  String get name;
  ToolPhase get phase;
  void onPointerDown(ToolPointerEvent e, ToolContext ctx);
  void onPointerMove(ToolPointerEvent e, ToolContext ctx);   // buttons == 0 is a hover
  void onPointerUp(ToolPointerEvent e, ToolContext ctx);
  void onPointerExit(ToolContext ctx);
  KeyEventResult onKey(KeyEvent event, ToolContext ctx);
  void cancel(ToolContext ctx);   // → idle, no side effects on document or selection
  void paintOverlay(Canvas canvas, ViewportTransform camera, Size viewport);
}

class ToolController extends ChangeNotifier {
  ToolController({required Tool initial, required ToolContext context});
  Tool get active;
  void activate(Tool next);       // active.cancel(context) first, then swap, then notify
}
```

Keys: `Focus.onKeyEvent` hands every `KeyEvent` to `active.onKey`;
`KeyEventResult.ignored` bubbles. A pointer down on the layer calls
`requestFocus` so keys keep working after later chrome takes focus. Modifier
state is read from `HardwareKeyboard.instance` at dispatch, as 01 does for the
scroll rule.

### `SelectTool`

`kBandSlopPixels = 4.0`. Phase, then input, then effect:

| phase | input | effect |
|---|---|---|
| idle | hover move | `pickInto` at the pointer → hover key or none (D2 resolution); notify only on change |
| idle | primary down | → pressed; remember `start` (screen and world) and the pick result at the down point |
| pressed | move, distance < slop | nothing |
| pressed, down **missed** | move ≥ slop | → dragging; band from `start` to now; hover cleared |
| pressed, down **hit** | move ≥ slop | stays pressed (03 makes this a move); the release still selects |
| pressed | up | hit: `replace([key])`, shift: `toggle([key])`; miss: `clear()`, shift + miss: nothing; → idle |
| dragging | move | band end updated; mode = `now.dx >= start.dx ? window : crossing`; notify |
| dragging | up | band = `Aabb2.fromPoints([screenToWorld(start), screenToWorld(end)])`; keys from `forEachLeafInBand` (each slot → D2 resolution, groups deduplicated) and `forEachInstanceInBand`; `replace` or, with shift, `toggle`; → idle |
| dragging | Escape | band dropped, selection untouched, → idle |
| idle | Escape | `clear()` |
| idle | Delete or Backspace | D10 |
| any | pointer cancel, `cancel()`, pointer exit while dragging | → idle; hover cleared |

`paintOverlay` draws the band while dragging and nothing otherwise.

### Files

```
packages/jet_cad_2d/lib/src/index/spatial_index.dart       BandMode; forEachLeafInBand and forEachInstanceInBand as methods of SpatialIndex, beside pickInto (they need the private scratch and the guard)
packages/jet_cad_2d/lib/src/index/band_predicates.dart     top-level pure functions: leafEnclosedBy, leafTouchedBy — kind switch over a payload, a composed transform and a band; no index state
packages/jet_cad_2d/test/index/band_query_test.dart
packages/jet_cad_2d/test/index/band_predicates_test.dart

packages/jet_cad_2d_flutter/lib/src/selection.dart          SelectionKey, SelectionController, resolveHit(HitPath, DraftDocument) → SelectionKey
packages/jet_cad_2d_flutter/lib/src/selection_geometry.dart outline path builder per key
packages/jet_cad_2d_flutter/lib/src/selection_style.dart    the constants
packages/jet_cad_2d_flutter/lib/src/tool.dart               Tool, ToolContext, ToolPointerEvent, ToolPhase, ToolController
packages/jet_cad_2d_flutter/lib/src/select_tool.dart        SelectTool, kBandSlopPixels
packages/jet_cad_2d_flutter/lib/src/interaction_layer.dart  InteractionLayer, kPickRadiusPixels
packages/jet_cad_2d_flutter/lib/src/selection_overlay.dart  SelectionOverlay
packages/jet_cad_2d_flutter/lib/jet_cad_2d_flutter.dart     exports for all of the above
packages/jet_cad_2d_flutter/test/selection_test.dart
packages/jet_cad_2d_flutter/test/select_tool_test.dart       tool driven with synthetic ToolPointerEvents, no widgets
packages/jet_cad_2d_flutter/test/interaction_layer_test.dart widget-driven: click, shift, band, keys, focus
packages/jet_cad_2d_flutter/test/selection_overlay_test.dart SpyCanvas, paint counters
packages/jet_cad_2d_flutter/test/support/selection_fixture.dart

apps/floor_planner/lib/planner_view.dart                     the tree above
apps/floor_planner/lib/main.dart                             status text in chrome-top
apps/floor_planner/test/planner_shell_test.dart              status text follows the selection
```

---

## Invariants

- **The frame path allocates nothing per entity.** `query_allocation_test`
  and `paint_allocation_test` pass unchanged. The overlay's `paint` allocates
  nothing per key beyond what `drawPath` itself does; paths are built at
  selection-change rate.
- **A selection change never repaints the drawing.** `DraftCanvas`'s repaint
  listenable is not touched by anything in this sub-project.
- **The overlay never walks the document in `paint`.**
- **Hover picks allocate nothing.** `pickInto`'s existing guarantee; the tool
  owns one `HitPath` and reuses it.
- **Draw order is untouched.** Nothing here writes to the document except
  through the existing remove commands.
- **Geometric decisions use `Tolerance`; stored values compare exact.**
  Nothing in this sub-project introduces a tolerance comparison; the pick
  radius is a query parameter, not a tolerance.
- **The harness is untouched.**
- **Never commit `analysis_options.yaml`.** Ruling 01-1 stands: the app's
  own copy is already committed; `flutter pub get` rewrites the three
  package copies and they are restored, never staged.

---

## Testing

**Fixture rules, binding on every test in this sub-project.** The camera is
never the identity: use `fitOffOrigin` from 01's support or a camera at scale
≠ 1 with a non-zero translation. Geometry never sits at the origin. Every
instance fixture is placed at a translation, a rotation and a scale that are
all non-trivial (the spec's reference placement: `(300, −200)`, 30°, ×1.5).
Every band fixture has one entity **straddling** the band edge. Widget tests
assert the viewport size they claim (01's `pumpWidget` trap).

### Named mutants

Each must go red in the named test, or be declared equivalent with the reason
recorded in the mutation log. The log is the result of record.

| id | mutation | killed by |
|---|---|---|
| M-02a | swap the window and crossing predicates | `band_query_test`: a line straddling the band's right edge, one inside, one outside; window = {inside}, crossing = {inside, straddling} |
| M-02b | drop the instance transform in `forEachInstanceInBand`'s descent | `band_query_test`: instance at (300, −200), 30°, ×1.5; the band covers where the leaf lands only after the transform |
| M-02c | `SelectionKey.==` compares `entity` alone | `selection_test`: two instances of one definition, both selected, `length == 2` |
| M-02d | `kPickRadiusPixels` ×10 | `select_tool_test`: two parallel lines 30 px apart on screen; a click 10 px from A picks A; a click 20 px from both misses |
| M-02e | overlay built with `repaint: null` | `selection_overlay_test`: selecting one key increments the overlay's paint count |
| M-02f | `kBandSlopPixels` → 0 | `select_tool_test`: press on empty space, move 2 px, release → selection cleared (a click), phase never `dragging` |
| M-02g | band direction test inverted (`<` for `>=`) | `interaction_layer_test`: the M-02a fixture dragged both ways |
| M-02h | shift toggle replaced by replace | `select_tool_test`: two shift-clicks on different lines → `length == 2` |
| M-02i | `onPointerExit` does not clear hover | `interaction_layer_test`: hover a line, exit the layer, hover is none |
| M-02j | group delete skips the owned leaves | `select_tool_test`: group of three leaves and a nested group with one; after Delete, `entities.slotOf` is null for all four and both nodes are gone |
| M-02k | `SelectionController` never subscribes to `changes` | `selection_test`: select a leaf, `execute(RemoveEntityCommand)` externally, pump a microtask, `isEmpty` |
| M-02l | `pickRadiusWorld` not divided by `camera.scale` | `interaction_layer_test`: camera at scale 4, click 5 px from a line on screen picks it; at scale 0.25, a click 5 px away also picks it |
| M-02m | overlay stroke width not divided by `camera.scale` | `selection_overlay_test`: `SpyCanvas` records `strokeWidth == 2.0 / 4.0` at scale 4 |
| M-02n | permission check dropped from Delete | `select_tool_test`: `DraftPermissions.readOnly` document, select, Delete, entity still present, still selected |
| M-02o | instance crossing tests the instance box instead of descending | `band_query_test`: an L-shaped block; a band inside the empty quadrant of its box selects nothing |
| M-02p | D2 resolves to the **nearest** group, not the topmost | `selection_test`: leaf owned by a group inside a group; the key names the outer group |
| M-02q | overlay's `repaint` merged into the canvas's listenable (a selection change repaints the drawing) | `selection_overlay_test`: `DraftCanvas.onPaintForTest` count unchanged across `replace`, overlay count +1 |

### Equivalence

A mutant is equivalent only if no test **could** distinguish it under this
spec's rules, and the log says why in one sentence. "Hard to reach" is not
equivalent. The 01 precedent: E-01e′ was declared equivalent because the
Flutter VM gate made two events indistinguishable; the reason was written
down.

### Differential check

`band_query_test` includes one differential test: for a `generateDocument`
corpus (400 entities, 40 instances, nesting depth 2, mirrored and
non-uniform fractions non-zero) and a band, the crossing result must equal
the brute-force set computed by transforming every leaf of every root-level
object to world and applying the same predicate without the index. Window
likewise. This catches a broad-phase box that is too tight.

---

## Exit gate

| # | criterion |
|---|---|
| 1 | Clicking an entity selects exactly it; clicking empty space clears; both from a non-identity camera. |
| 2 | Window and crossing bands select the D8 sets; the straddling fixture distinguishes them; both drag directions tested. |
| 3 | The same leaf under two instances yields two keys; two leaves of one instance yield one. |
| 4 | Hover follows the pointer, clears on exit, and is never drawn for a key that is already selected. |
| 5 | Shift toggles; Escape cancels a band or clears; Delete removes through the command log and undo restores the geometry (not the selection). |
| 6 | Selection change repaints the overlay and not the canvas: both paint counters asserted. |
| 7 | `SelectTool` implements `Tool`; `ToolController.activate` cancels the outgoing tool; a second trivial tool in the test suite proves the interface is not `SelectTool`-shaped. |
| 8 | All seventeen mutants killed or declared equivalent with a reason, in `docs/superpowers/notes/plan-02-mutation-log.md`. |
| 9 | The differential band test passes on the generated corpus. |
| 10 | `query_allocation_test` and `paint_allocation_test` pass unchanged. |
| 11 | Harness untouched: `git diff --stat main..HEAD -- apps/dev_harness_2d` empty; its 82 tests pass. |
| 12 | All eleven gate commands exit 0 (`CI=true` prefixed), except `jet_cad_2d_flutter`'s `flutter test` on the same five pre-existing `text_ladder_golden_test.dart` failures and nothing else (the 01 baseline ruling); no `analysis_options.yaml` in the diff. |
| 13 | The app's top bar shows the tool name and the selection count, and a widget test drives it. |
| 14 | A human looked, on macOS, in Chrome and in Firefox from `build/web`: click, shift-click, both bands, hover, Escape, Delete, undo; each recorded seen / not seen / could not judge. |

**The eleven gate commands** (01's, unchanged):

```sh
cd packages/jet_cad_2d         && dart test && dart analyze && dart format --output=none --set-exit-if-changed .
cd packages/jet_cad_2d_flutter && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
cd apps/dev_harness_2d         && flutter test --concurrency=1 && flutter analyze && dart format --output=none --set-exit-if-changed .
cd apps/floor_planner          && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed . && flutter build macos --debug && flutter build web
```

---

## Open questions

Deferred, not unanswered:

- **Entering a container.** Double-click to enter a group or block and pick
  its leaves, with Escape to leave. The `SelectionKey` carries the full chain
  so this is a policy change in `resolveHit`, not a type change. Sub-project
  03 or 05 decides when it is needed.
- **Compound undo.** D10's N-step delete is the first concrete case for 06's
  spike.
- **Selection after undo.** 02 says "not restored". Most CAD tools agree; a
  later sub-project may reselect what an undo brought back.
- **Rotated text under a window band.** D8 accepts the AABB's looseness.
  If the look finds it wrong, the fix is an oriented-box-inside-rect test,
  local to the window predicate.
- **Touch.** Nothing designed. A long-press-to-band or two-finger convention
  is 12's or later.

## What this changes outside 02

- `jet_cad_2d` gains two public query methods and one enum on its index.
- `jet_cad_2d_flutter` gains nine files and their exports. `DraftCanvas`,
  `DraftPainter`, `CameraGestureDetector` unchanged.
- `apps/floor_planner` gains the interaction tree and one status text.
- `roadmap/02-interaction-core.md` status line, `roadmap/00-README.md`
  status row, `STATUS.md` — at merge, as 01 did.

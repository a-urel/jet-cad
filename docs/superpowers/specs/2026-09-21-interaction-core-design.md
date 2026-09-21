# The interaction core — design

**Date:** 2026-09-21. **Status:** design, **revision 2**, not yet a plan.
Revision 1 was reviewed the same day by three independent reviewers (Claude,
Codex, Copilot CLI); every finding was re-verified against the repo and the
SDK and is recorded, with its ruling, in
[2026-09-21-interaction-core-spec-review-r1.md](../notes/2026-09-21-interaction-core-spec-review-r1.md).
Revision 2 applies all of them. Five were blockers: the group window rule,
the float32 rebase the overlay must respect, the group resolution, the dirty
overlay's boxes, and the delete cascade.
**Sub-project:** `roadmap/02-interaction-core.md`. **Size:** L.
**Brainstormed with the human on 2026-09-21**, on `main` at `1909a5e`, the
day Plan 01 closed with its exit gate at 12 of 12.
**Depends on:** 01 (merged at `bae5f73`). **Blocks:** 03, 05, 06, 09, 12 —
everything with a user in it.

**Evidence of record.** Every claim below about what exists was read from the
tree at `fa51d27` on 2026-09-21, files cited by line:
`packages/jet_cad_2d/lib/src/index/spatial_index.dart` (`forEachInRect` 271,
`forEachInstanceInRect` 299, `pickInto` 452 with its broad phase widened by
`_broadPhaseMargin().pick` at 462, `_descend` 517 — the leaf transform
`_composeLeafTransform(toWorld, index.transformOfLeaf(slot))` at 564, the
per-level instance product at 642 —, `_considerLeaf` 755 returning before
kind dispatch when the payload has no points at 772 (a fill), `_writeChain`
1057 — the chain holds **instance** handles only, never groups, and truncates
from the root end —, `onAfterMutate` taken by the index at 141, the
dirty-overlay idiom `boxOfLeaf(last) ?? dirty.boxOf(last)` at 2434),
`index/hit.dart` (`HitPath` 27 with a fixed `Uint32List(16)` buffer at 28 and
a separate `chainLength` at 33; the doc comment at 14-18 already names the
policy this spec adopts: *"a viewer selects `chain[0]`, the root-level
ancestor"*), `index/query_filter.dart` (`QueryFilter.picking()` 27: visible
and unlocked; `FilterEvaluator` stops on a containment cycle without throwing,
121-132), `index/container_index.dart` (`boxOfLeaf` 758 — null for a leaf
live only on the dirty overlay —, `transformOfInstance` 581,
`transformOfLeaf` 606, `searchLeaves` 516 visits tree and overlay and may
visit a slot twice, 512-515), `index/dirty_list.dart` (`boxOf` 80),
`geometry/segment_clip.dart` (`clipSegment` 22, Liang–Barsky;
`circleClipWindows` 92, −1 when wholly inside), `geometry/primitives.dart`
(`angleInSweep` 67, `arcBounds` 82), `document/text_geometry.dart`
(`textLocalTransform` 310, `textLocalBounds` 325), `document/node.dart`
(`GroupNode.children` 70 holds **nodes only**; a leaf's container is
`EntityRecord.owner`, `store/entity_store.dart` 36), `document/tree.dart`
(the root **is** stored in `_nodes`, 61-63; `ancestorsOf` 240, nearest first,
excluding the node, ending with the root; `accumulatedTransform` 266;
`childNodesOf` 104; `_unlink` 612 copies the children list),
`document/draft_document.dart` (`leavesByOwner()` 232, one linear pass;
`changes` 146), `document/commands.dart` (`RemoveEntityCommand` 124 —
removing a boundary removes its one dependent fill in the same command,
144-201 —, `RemoveNodeCommand` 360 — **does not cascade**: `tree.removeNode`
unlinks the node and nothing else), `document/command.dart` (`Capability` 15,
`DraftPermissions` 30, `PermissionDeniedError` 62), `document/undo.dart`
(`CommandDispatcher` 48, `permissions` 54, `execute` 102 — `_require` at 193
**throws** on a denied capability; `changes` is an async broadcast
controller, 51), `document/doc_change.dart` (5-7: *"Selection is deliberately
absent: selection is view state and belongs to the widget layer's own
controller"*), `packages/jet_cad_2d_flutter/lib/src/viewport_transform.dart`
(12-13: *"Nothing here ever hands an absolute world coordinate to `dart:ui`"*;
`worldToScreenMatrix` is a `Transform2`, 50; `screenToWorld(Vector2)` 59;
`visibleWorld` 65), `camera_controller.dart` (`rebaseOriginFor` 18-33),
`draft_painter.dart` (73-78: *"at 4.5e6, float32 spacing is about 0.5
units"*; the per-leaf rebase 551-576), `canvas_draw_sink.dart` (the reusable
`Float64List(16)` at 67, `beginResidual` 100), `draft_canvas.dart`
(`RepaintBoundary > CustomPaint(size: Size.infinite)` 465-479, `onPaintForTest`
171, `shouldRepaint` 636 — false on the vertices path; its repaint listenable
`_repaint` is private), `camera_gesture_detector.dart` (a `Listener` with
`HitTestBehavior.opaque`, pans on any event whose mask contains the pan
button, 120-123), `apps/floor_planner/lib/main.dart` (`_PlannerShellState`
owns document, index, camera, 35-42; chrome keys 60-84; no `Focus`, no
`Shortcuts`), `test/support/gesture_fixture.dart` (`fitOffOrigin` 21,
`kDetectorTopLeft` 10), `test/support/spy_canvas.dart`
(`RecordedCall.strokeWidth` 38), `testing/generate_document.dart`
(`kDefaultOriginX = 4500000.0` at 34; knobs `instanceCount`, `nestingDepth`,
`mirroredFraction`, `nonUniformFraction`, `groupCount`). No compound command
exists: a case-sensitive grep for `class .*(Compound|Batch|Multi).*Command`
over `packages/jet_cad_2d/lib` returns nothing.

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
distinct colour, at constant screen width, at every zoom, and exactly where
the entity is drawn — also at x = 4.5e6. Escape cancels a band or clears the
selection; Delete removes the selection through the command log so undo
works. A **tool state machine** exists, with `SelectTool` as its first tool
and an interface every later tool implements. The app's top bar shows the
active tool's name and the selection count.

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
- A rotating camera. `CameraController` pans and zooms; the band rectangle
  and the rebase both assume an axis-aligned world-to-screen affine, and the
  one place that already handles rotation (`visibleWorld`'s four-corner form)
  is not extended here.
- Changing `DraftCanvas`, `DraftPainter`, the tile cache or the harness.

## Decisions

Decisions D1–D4 were made by the human during the brainstorm. D5–D12 are the
design's, made in the sections the human approved, revised per the review.

### D1 — Rubber band: the CAD convention (human)

Left-to-right drag = **window**, selects only what the band fully encloses.
Right-to-left = **crossing**, selects anything the band touches. Direction is
read in screen space from the x component alone: `end.dx >= start.dx` is a
window, so a purely vertical drag is a window. Each mode has its own band
styling (D9).

### D2 — A click selects the root-level object (human)

A `HitPath` resolves to the thing directly under the root:

| hit | selected |
|---|---|
| a leaf reached through one or more instances (`chainLength > 0`) | the **root-level instance**, `chain[0]` |
| a root-container leaf whose `owner` is a group | the **topmost group** under the root: `candidates = [owner, ...tree.ancestorsOf(owner)]` with the root handle removed; the selection is the **last** candidate for which `tree[h] is GroupNode`. For a group directly under the root that is `owner` itself. |
| a root-container leaf owned by the root | the leaf itself |

Two guards, both resolving to "treat as a miss or a leaf" rather than
throwing at hover rate: a `HitPath` with `truncated` set no longer names the
root-level ancestor (the chain is cut from the root end), and is treated as a
**miss**; the tool's `HitPath` keeps the default capacity of 16, which no
floor plan reaches. `ancestorsOf` throws `NodeCycleError` on a looped parent
chain; `resolveHit` catches it and resolves to the leaf, the precedent
`FilterEvaluator` sets for a malformed tree at query rate.

Clicking two different leaves of one instance selects that instance once.
Clicking the same leaf handle under two instances selects two things. The
identity that makes both true is D6's key.

### D3 — Keys: shift toggles, Escape cancels or clears, Delete removes (human)

Plain click or band **replaces** the selection; with shift held it **toggles**
membership of what was picked. Escape during a band drops the band and leaves
the selection alone; Escape when idle clears the selection. Delete and
Backspace remove the selection (D10). Every key acts on **`KeyDownEvent`
only**: `KeyRepeatEvent` and `KeyUpEvent` return `KeyEventResult.ignored`, so
one press is one delete and a held Delete does not repeat. No other key or
modifier does anything in 02. Ctrl/cmd-click is reserved, unbound.

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
| `jet_cad_2d` | `BandMode`; `forEachLeafInBand` and `forEachInstanceInBand` as methods of `SpatialIndex` beside `pickInto` (they need the private scratch, the guard and the broad-phase margin); the exact predicates as pure functions in `band_predicates.dart`. Pure Dart, no `dart:ui`. |
| `jet_cad_2d_flutter` | `SelectionKey`, `SelectionController` (selection **and hover**), `Tool`, `ToolContext`, `ToolPointerEvent`, `ToolPhase`, `ToolController`, `SelectTool`, `InteractionLayer`, `SelectionOverlay`, the outline cache, the colour and size constants |
| `apps/floor_planner` | `_PlannerShellState` owns the two controllers and the `ToolContext`; `planner_view.dart` builds the tree; the top bar gains the tool name and count |

The engine gets the geometry because the exact window/crossing predicates
need the leaf payloads, the composed transforms, the dirty overlay and the
reentrancy guard, all of which are the index's. The widget layer gets
everything that knows about pointers, keys, colours or `Canvas`.
`dev_harness_2d` is not touched; `git diff --stat main..HEAD --
apps/dev_harness_2d` stays empty.

### D6 — Selection identity: a target plus the instance chain above it

```dart
/// What is selected: an object's handle and the instance chain above it.
final class SelectionKey {
  /// [chain] is copied: never HitPath's buffer, never its capacity.
  SelectionKey({required Uint32List chain, required int chainLength, required this.target})
      : chain = Uint32List.fromList(Uint32List.sublistView(chain, 0, chainLength));

  /// Instance handles strictly above [target], root first.
  /// Always empty under D2 — the field exists so a later sub-project can
  /// select inside a container without changing the type.
  final Uint32List chain;

  /// The selected object: a root-level instance, a group, or a leaf.
  final Handle target;

  // `==` and `hashCode` over the chain element-wise, then `target`.
}
```

D2 produces: an instance → `chain = []`, `target = chain[0]` of the hit; a
group → `chain = []`, `target = group`; a loose leaf → `chain = []`,
`target = leaf`. Two instances of one definition are two targets; two leaves
of one instance are one. The roadmap's M-02c ("compare bare handles instead
of chains") is **equivalent under D2** — every chain is empty — and the log
records that; the mutant that stands in for it is M-02c′, `resolveHit`
returning the leaf instead of `chain[0]`.

```dart
class SelectionController extends ChangeNotifier {
  Set<SelectionKey> get keys;          // unmodifiable view
  int get length; bool get isEmpty;
  bool contains(SelectionKey key);
  void replace(Iterable<SelectionKey> keys);
  void toggle(Iterable<SelectionKey> keys);
  void remove(Iterable<SelectionKey> keys);   // D10 uses it after a successful delete
  void clear();

  SelectionKey? get hover;             // what a click would select; owned here, not by a tool
  void setHover(SelectionKey? key);
}
```

One `notifyListeners` per call, and **none when nothing changed** — the same
rule the camera clamp follows (01's D4); `setHover` with the current value
is silent. Selection is application state: never in the document, never in
the codec, never undone.

### D7 — Pick radius is a screen-pixel constant, converted per event

`kPickRadiusPixels = 6.0` logical pixels. `InteractionLayer` computes
`pickRadiusWorld = kPickRadiusPixels / camera.value.scale` for every event it
forwards, so the target stays the same size on screen at every zoom.
`pickInto` decides vertex over edge over fill, and ties, exactly as it does
today; `Tolerance` stays where it is, inside the engine's geometric decisions.
Nothing in this sub-project compares a stored value with a tolerance.

### D8 — Band queries live in the engine, exact, and descend into containers

```dart
enum BandMode { window, crossing }

/// Root-container leaves the band selects, ascending handle order, each
/// slot once. Skips EntityKind.fill.
void forEachLeafInBand(
    Aabb2 world, BandMode mode, QueryFilter filter, void Function(int slot) visit);

/// Root-level instances the band selects, ascending handle order. Descends
/// into the definition with composed transforms and tests leaf geometry.
void forEachInstanceInBand(
    Aabb2 world, BandMode mode, QueryFilter filter, void Function(Handle instance) visit);
```

**One rule for a container, in both modes:** window selects a container
when **every** member leaf passes the window test; crossing when **any**
member leaf passes the crossing test. A container with no member leaves is
never band-selected. Instances descend (`forEachInstanceInBand`); groups are
resolved by the tool from the leaves the leaf walk reports (D2), and the tool
applies the same every/any rule over the group's owned leaves, nested groups
included, using `leavesByOwner()` once per band.

**Amended at execution (Plan 02, 2026-09-22):** a group's member leaves are
its own and its nested groups'; an instance placed inside a group does not
enter the group's every/any rule (Ruling P-1).

| mode | a leaf |
|---|---|
| **window** | its world AABB ⊆ band, read as `boxOfLeaf(slot) ?? dirty.boxOf(slot)` — `boxOfLeaf` alone is null for a leaf live only on the dirty overlay, which is every leaf edited since the last rebuild. Tight for point, line, polyline, circle and arc (`arcBounds`); **conservative for rotated text** — the AABB of an oriented box is looser than the box, so a rotated text near the band edge may be missed. Documented, accepted. |
| **crossing** | broad phase: AABB overlaps the band **widened by `_broadPhaseMargin().pick`**, the margin `pickInto` uses for the same reason (a circle under a non-conformal transform may be accepted outside its exact box). Exact phase: **some point of the stroke lies inside the band.** Line and polyline segments: `clipSegment` returns true. Circle: `circleClipWindows` returns non-zero (or −1, fully inside). Arc: a clip window intersects the sweep (`angleInSweep`). Text and attrib: the oriented box's four edges as segments (`textLocalTransform` × `textLocalBounds`). Point: `containsPoint`. Enclosed ⇒ touched, so no second case. **A band lying wholly inside a closed shape touches no stroke and selects nothing** — CAD behaviour. |

Fills carry no coordinates and are never picked (`_considerLeaf` returns
before kind dispatch); both walks skip `EntityKind.fill`, and a region is
selected through its boundary, the way `pickInto` already answers.

Inside an instance, a leaf's world transform is the per-level product
`toWorld.multiply(transformOfInstance(node))` **followed by
`transformOfLeaf(slot)`** for the leaf itself (null means identity) — exactly
`_descend`'s pair at `spatial_index.dart:642` and `:564`; a grouped leaf
inside a definition is misplaced without the second half. A circle or arc
under a non-uniform scale uses the same approximated-radius rule `pickInto`
uses, so pick and band agree.

Both walks take the reentrancy guard (`_beginQuery`/`_endQuery`, released
between the two calls the tool makes back to back), reject by `QueryFilter`
the way the rect queries do, **deduplicate slots** (a slot may be visited
from both the tree and the overlay), and sort before reporting — ascending
handle order is the property that touches the draw-order non-negotiable, and
M-02z guards it. They run at pointer-up rate, off the frame path; they may
allocate O(results) but must not walk the whole document — the broad phase
is the R-tree search, as for `forEachInRect`.

**Amended at execution (Plan 02, 2026-09-22):** a singular instance transform
is judged forward rather than refused; crossing falls back to the container's
all box for that instance (Task 2 ruling).

### D9 — The overlay: a sibling painter over a rebased outline cache

`SelectionOverlay extends CustomPainter` sits in its own `RepaintBoundary`
above `DraftCanvas`, as `Positioned.fill(child: RepaintBoundary(child:
CustomPaint(painter: overlay, size: Size.infinite)))` — a bare `CustomPaint`
in a loose `Stack` lays out at `Size.zero`. The `Size` handed to `paint` is
the viewport the tool's `paintOverlay` receives. Its `repaint` is
`Listenable.merge([selection, toolController, camera])`, where
`ToolController` forwards its active tool's notifications (Architecture);
`shouldRepaint` returns `false`, the canvas's discipline. A selection change
therefore cannot repaint the drawing: `DraftCanvas.onPaintForTest` stays flat
while the overlay's own `onPaintForTest` counts (criterion 6, M-02e′).

**`paint` never walks the document.** When a key enters the selection or
becomes the hover, an `OutlineCache` records its outline **in world space as
`Float64List`s** — segments for line and polyline, centre/radius/angles for
circle and arc, the four corners for text and attrib, an instance by walking
its definition with composed transforms (nested instances included, grouped
leaves via `transformOfLeaf`), a group as the union of its members. That
walk is the only document access the overlay ever makes, and it happens at
selection-change rate.

**The `ui.Path` is built in rebased space, never in world space.** `ui.Path`
stores float32; at the generated corpus's x = 4.5e6 a world-space path would
sit up to half a unit off the entity it outlines, while the startup plan at
x = 5e3 would look fine. So each frame the painter computes
`origin = rebaseOriginFor(camera.visibleWorld(size))` — stable across small
pans by construction —, and if it differs from the cache's tag rebuilds every
path from the cached `Float64List`s with `origin` subtracted (no document
access), retags, then draws under the transform
`worldToScreenMatrix ∘ translate(origin)` written into **one reusable
`Float64List(16)`**, the way `CanvasDrawSink` pushes its residual. Per frame:
`save`, `clipRect`, `transform`, one `drawPath` per selected key with the
selection paint, one for the hover key if it is not selected with the hover
paint, `restore`, then `tool.paintOverlay(canvas, camera, size)` in screen
space. The two `Paint`s are fields, their `strokeWidth` set per frame to
`kSelectionStrokePixels / camera.scale` (2.0 px) and `kHoverStrokePixels /
camera.scale` (1.5 px) so widths hold on screen at any zoom (M-02m); nothing
is allocated per key in `paint` (M-02ab). Constants — `kSelectionColor`,
`kHoverColor`, `kWindowBandColor`, `kCrossingBandColor`, `kBandFillAlpha`, the
two stroke widths — live in `selection_style.dart`.

Cache lifecycle: built on entry, dropped on exit. **Every `DocChange`
rebuilds every cached outline** — a leaf edited inside a selected instance's
definition or group touches neither the instance nor the group handle, so an
exact-handle rule never fires for them; selection is small and commands
arrive at command rate, so the blanket rule is affordable in 02, and 03
narrows it with a measurement if its drag needs to. `DocumentLoaded` and
`DocumentPurged` clear everything (D11 drops the keys first).

Band paint (the tool's): window = solid 1 px stroke in `kWindowBandColor`
with a `kBandFillAlpha` fill; crossing = dashed 1 px stroke in
`kCrossingBandColor` with the same fill. Screen space, no camera transform.

**Amended at execution (Plan 02, 2026-09-22):** the painter class is named
`SelectionOverlayPainter`, not `SelectionOverlay` — Flutter's widgets library
already exports a `SelectionOverlay`, and the spec's name would force a
`hide` at every app import (Task 8 ruling); the Files list below is amended
the same way.

**Amended at execution (Plan 02, 2026-09-22):** a point key is drawn as a
screen-space cross of half-length 3 × the stroke width, centred at
`worldToScreen(worldPointOf(key))` (Task 7/8 ruling).

**Amended at execution (Plan 02, 2026-09-22):** `ui.Path.getBounds` returns
the conic control-point hull, not the curve's own bound (measured: 19.1 vs.
17.0 for a 2.6 rad sweep of radius 7), so an arc or circle outline is pinned
on the cache's world record (`debugWorldArcsOf`) to tight tolerance, and only
a containment bound is asserted on the `ui.Path` itself (Task 7 ruling).

### D10 — Delete: preflight per object, permission-checked, cascading through groups

For each selected key, in ascending handle order of `target`, the tool builds
that object's **command list**, checks it, and only then executes it:

| selected | command list | capability of each |
|---|---|---|
| loose leaf | `RemoveEntityCommand(target)` | `geometry` |
| root-level instance | `RemoveNodeCommand(target)` | `structure` |
| group | its owned leaves (`leavesByOwner()`, one linear pass per Delete, bucketed by owner), its child nodes (`childNodesOf(group.children)`): instances → `RemoveNodeCommand`, nested groups → recursively the same list, then `RemoveNodeCommand(group)` last. **A fill slot whose boundary is in the same list is skipped**: removing the boundary removes its dependent fill in the same command, and naming it twice would throw on the second. | `geometry` for the leaves, `structure` for the nodes |

Preflight: every command in the list must satisfy
`document.commands.permissions.allows(command.capability)` — `execute` throws
`PermissionDeniedError` rather than skipping, so the check comes first and a
list with one refused command is not started. A permitted list is executed
in order; on success the tool calls `selection.remove([key])`
**synchronously**, so the overlay never paints a key the document no longer
has and the async prune (D11) has nothing left to do for it. A refused object
stays selected and untouched. A read-only document
(`DraftPermissions.readOnly`) is fully selectable and Delete is a no-op on it
(M-02n).

The cascade exists because `RemoveNodeCommand` unlinks the node and nothing
else: deleting a group alone would leave its leaves with an `owner` that no
longer resolves. **A delete of N objects is N undo steps** (more for a group),
and an undo of part of a cascade restores leaves under an owner that is still
gone; both are recorded here as the concrete problem statement 06's compound
undo inherits, and the results note must say so in as many words.

### D11 — Pruning listens to `document.changes`

`SelectionController` subscribes to `document.changes` (an async broadcast
stream; `onAfterMutate` is the single sync slot the index owns). On every
`DocChange` it re-resolves each key: `target` must still be in `entities` (a
leaf) or `tree` (a node), and every chain handle must still resolve to an
`InstanceNode`. Keys that fail are dropped, hover included, one notify if
anything changed. Delivery is a microtask after the command, so tests pump a
microtask before asserting, and tool-initiated deletes do not rely on it
(D10 removes synchronously). An unrelated command leaves every key in place.
Undo of a delete does **not** restore the selection: selection is not
undoable (roadmap decision 1).

### D12 — The app's thin affordance: tool name and count in the top bar

`chrome-top` gains one `Text` at its left: `"Select — 3 selected"`, `"Select"`
when empty. `_PlannerShellState` owns `SelectionController`,
`ToolController` and the `ToolContext` for the window's lifetime, disposes
them in `dispose` beside the camera and the index, passes them into
`PlannerView`, and holds the status text's `Listenable.merge([selection,
tools])` as a `late final` field — not a fresh merge per build, which would
churn `ListenableBuilder`'s subscription. Keyed `status-text` for the widget
test. That is all the UI 02 adds; 12 consolidates.

---

## Architecture

Widget tree in `planner_view.dart`, outside in:

```
CameraGestureDetector            01, unchanged: middle drag, wheel, trackpad
  InteractionLayer               Focus(autofocus) + MouseRegion(onExit) + Listener(behavior: HitTestBehavior.opaque)
    Stack
      RepaintBoundary DraftCanvas                                          unchanged
      Positioned.fill RepaintBoundary CustomPaint(SelectionOverlay, Size.infinite)   repaint: selection | tool | camera
```

Both pointer handlers are `Listener`s, so there is no arena: every pointer
event reaches both, each ignores what is not its own.

**Pointer routing.** `InteractionLayer` tracks one **active pointer id** and
the previous event's `buttons`. Flutter reports a second button pressed or a
first button released while another is held as a `PointerMoveEvent` with a
new mask, and a `PointerUpEvent` only when every button is up (`buttons ==
0`), so the primary button is recognised on its **transition**:

| event | rule |
|---|---|
| any event whose mask contains the policy's pan button (middle) | camera-owned; ignored here, including a primary+middle mask |
| `PointerDownEvent` with primary, no active pointer | becomes the active pointer → `onPointerDown` |
| `PointerMoveEvent` from the active pointer, primary still set | `onPointerMove` |
| move from the active pointer in which primary **disappears**, or `PointerUpEvent` from it | `onPointerUp`; active pointer cleared |
| move in which primary **newly appears** on a non-active pointer | treated as a down |
| `PointerHoverEvent` (`Listener.onPointerHover`, no buttons) | `onPointerMove` with `buttons == 0` |
| `PointerCancelEvent` from the active pointer | `tool.cancel`; active pointer cleared |
| `MouseRegion.onExit` | `onPointerExit` (exit cleanup only; hovers come from the row above) |
| `PointerPanZoom*`, `PointerSignal` | ignored |

`dispose`/`deactivate` clear hover and call `cancel`, since `onExit` does not
fire when the widget disappears. A pointer down calls `requestFocus`, so keys
keep working after later chrome takes focus. Modifier state is read from
`HardwareKeyboard.instance` at dispatch, as 01 does for the scroll rule.

```dart
final class ToolPointerEvent {
  final Offset screen;          // local to the layer
  final Vector2 world;          // camera.value.screenToWorld(Vector2(screen.dx, screen.dy))
  final int pointer;
  final int buttons;
  final bool shift, control, meta, alt;
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
  KeyEventResult onKey(KeyEvent event, ToolContext ctx);      // KeyDownEvent only; the rest ignored
  void cancel(ToolContext ctx);   // → idle, no side effects on document or selection
  void paintOverlay(Canvas canvas, ViewportTransform camera, Size viewport);
}

class ToolController extends ChangeNotifier {
  ToolController({required Tool initial, required ToolContext context});  // listens to `initial`
  Tool get active;
  void activate(Tool next);   // active.cancel(context); remove its listener; install next's; swap; notify
  @override void dispose();   // removes the active listener
}
```

`Listenable.merge` needs a stable iterable, so the overlay merges the
**controller**, and the controller is the one that follows the active tool.

### `SelectTool`

`kBandSlopPixels = 4.0`. Phase, then input, then effect:

| phase | input | effect |
|---|---|---|
| idle | hover | `pickInto` at the pointer → `selection.setHover(resolved or null)` |
| idle | primary down | → pressed; remember `start` (screen and world) and the pick result at the down point |
| idle | move with `buttons != 0` | ignored (a mask change with no down of our own) |
| pressed | move, distance < slop | nothing |
| pressed, down **missed** | move ≥ slop | → dragging; band from `start` to now; hover cleared |
| pressed, down **hit** | move ≥ slop | stays pressed (03 makes this a move); the release still selects |
| pressed | up | hit: `replace([key])`, shift: `toggle([key])`; miss: `clear()`, shift + miss: nothing; → idle |
| dragging | move | band end updated; mode = `now.dx >= start.dx ? window : crossing`; notify |
| dragging | up | band = `Aabb2.fromPoints([screenToWorld(start), screenToWorld(end)])` (axis-aligned camera, see Non-goals); leaf slots from `forEachLeafInBand` resolved per D2, groups tested with the every/any rule over their owned leaves and deduplicated, plus `forEachInstanceInBand`; `replace` or, with shift, `toggle`; → idle |
| dragging | Escape (down) | band dropped, selection untouched, → idle |
| idle | Escape (down) | `clear()` |
| idle | Delete or Backspace (down) | D10 |
| any | repeat or up key event | ignored |
| any | pointer cancel, `cancel()`, exit while dragging | → idle; hover cleared |

**Amended at execution (Plan 02, 2026-09-22):** the "exit while dragging"
clause of the row above is superseded — exit with no active pointer clears
hover; a band drag past the layer's edge continues (Flutter keeps delivering
the captured pointer's moves and up) and its own `up` event ends it, not the
`onExit` (Task 9 ruling).

`paintOverlay` draws the band while dragging and nothing otherwise.

### Files

```
packages/jet_cad_2d/lib/src/index/spatial_index.dart       BandMode; forEachLeafInBand, forEachInstanceInBand
packages/jet_cad_2d/lib/src/index/band_predicates.dart     leafEnclosedBy, leafTouchedBy — pure functions over a payload, a composed transform and a band
packages/jet_cad_2d/test/index/band_query_test.dart
packages/jet_cad_2d/test/index/band_predicates_test.dart

packages/jet_cad_2d_flutter/lib/src/selection.dart          SelectionKey, SelectionController, resolveHit(HitPath, DraftDocument) → SelectionKey?
packages/jet_cad_2d_flutter/lib/src/outline_cache.dart      world-space Float64List outlines per key; rebased ui.Path per origin tag
packages/jet_cad_2d_flutter/lib/src/selection_style.dart    the constants
packages/jet_cad_2d_flutter/lib/src/tool.dart               Tool, ToolContext, ToolPointerEvent, ToolPhase, ToolController
packages/jet_cad_2d_flutter/lib/src/select_tool.dart        SelectTool, kBandSlopPixels, the delete preflight
packages/jet_cad_2d_flutter/lib/src/interaction_layer.dart  InteractionLayer, kPickRadiusPixels, the pointer routing table
packages/jet_cad_2d_flutter/lib/src/selection_overlay.dart  SelectionOverlayPainter (amended at execution, Plan 02: SelectionOverlay collides with Flutter's own export)
packages/jet_cad_2d_flutter/lib/jet_cad_2d_flutter.dart     exports for all of the above
packages/jet_cad_2d_flutter/test/selection_test.dart
packages/jet_cad_2d_flutter/test/outline_cache_test.dart
packages/jet_cad_2d_flutter/test/select_tool_test.dart       tool driven with synthetic ToolPointerEvents, no widgets
packages/jet_cad_2d_flutter/test/interaction_layer_test.dart widget-driven: click, shift, band, keys, focus, multi-button, cancel
packages/jet_cad_2d_flutter/test/selection_overlay_test.dart SpyCanvas, paint counters, the 4.5e6 fixture
packages/jet_cad_2d_flutter/test/support/selection_fixture.dart

apps/floor_planner/lib/main.dart                             controllers owned by the shell; status text in chrome-top
apps/floor_planner/lib/planner_view.dart                     the tree above
apps/floor_planner/test/planner_shell_test.dart              status text follows the selection
```

---

## Invariants

- **The frame path allocates nothing per entity.** `query_allocation_test`
  and `paint_allocation_test` pass unchanged. The overlay's `paint` allocates
  nothing per key: paths and `Paint`s are fields, rebuilt only when the
  rebase origin or the selection changes.
- **A selection change never repaints the drawing.** `DraftCanvas`'s repaint
  listenable is private and untouched; criterion 6 asserts both counters.
- **`SelectionOverlay.paint` never walks the document.** The outline cache
  walks at selection-change rate and at `DocChange` rate, never in `paint`.
- **Hover picks allocate nothing per entity.** `pickInto`'s guarantee holds
  and the tool reuses one `HitPath`; the O(1) allocations per hover event —
  the `ToolPointerEvent`, its `Vector2`, `ancestorsOf`'s list — are accepted
  and named here.
- **No absolute world coordinate reaches `dart:ui`.** The overlay obeys the
  renderer's rule through the rebase (D9, M-02v).
- **Draw order is untouched.** Nothing here writes to the document except
  through the existing remove commands; the band walks report ascending.
- **Geometric decisions use `Tolerance`; stored values compare exact.**
  Nothing in this sub-project introduces a tolerance comparison; the pick
  radius is a query parameter, not a tolerance.
- **The harness is untouched.**
- **Never commit `analysis_options.yaml`.** Ruling 01-1 stands.

---

## Testing

**Fixture rules, binding on every test in this sub-project.** The camera is
never the identity: use `fitOffOrigin` from 01's support or a camera at scale
≠ 1 with a non-zero translation. Geometry never sits at the origin. Every
instance fixture is placed at a translation, a rotation and a scale that are
all non-trivial (the spec's reference placement: `(300, −200)`, 30°, ×1.5).
Every band fixture has one entity **straddling** the band edge. The overlay's
precision fixture sits at `kDefaultOriginX` (4.5e6). Widget tests assert the
viewport size they claim (01's `pumpWidget` trap). Overlay tests mutate the
controller and pump **without rebuilding the widget**, so a repaint can only
come from the listenable.

### Named mutants

Each must go red in the named test, or be declared equivalent with the reason
recorded in `docs/superpowers/notes/plan-02-mutation-log.md`, the result of
record.

| id | mutation | killed by |
|---|---|---|
| M-02a | swap the window and crossing predicates | `band_query_test`: a line straddling the band's right edge, one inside, one outside; window = {inside}, crossing = {inside, straddling} |
| M-02b | drop the instance transform in `forEachInstanceInBand`'s descent | `band_query_test`: instance at (300, −200), 30°, ×1.5; the band covers where the leaf lands only after the transform |
| M-02c | *roadmap's:* key equality compares bare handles, not chains | **equivalent under D2** — every chain is empty; logged |
| M-02c′ | `resolveHit` returns the leaf instead of `chain[0]` | `selection_test`: two instances of one definition, both clicked; `length == 2` and both targets are `InstanceNode`s |
| M-02d | `kPickRadiusPixels` ×10 | `select_tool_test`: two parallel lines 30 px apart on screen; a click 3 px from A picks A; a click 10 px from A picks **nothing** — under ×10 it picks A |
| M-02e | *roadmap's:* overlay `shouldRepaint` false unconditionally | **equivalent under D9** — it is specified false; the repaint listenable drives every repaint and `RenderCustomPaint` re-attaches it regardless; logged |
| M-02e′ | overlay built with `repaint: null` | `selection_overlay_test`: `replace` on the controller, pump, overlay paint count +1, no widget rebuild |
| M-02f | `kBandSlopPixels` → 0 | `select_tool_test`: press on empty space, move 2 px, assert `phase == pressed` **before** the release; the post-release selection is not discriminating (`replace(∅)` = `clear()`) and the log says so |
| M-02g | band direction test inverted (`<` for `>=`) | `interaction_layer_test`: the M-02a fixture dragged both ways, **plus a purely vertical drag asserting window** — the only input the two spellings disagree on |
| M-02h | shift toggle replaced by replace | `select_tool_test`: two shift-clicks on different lines → `length == 2` |
| M-02i | `onPointerExit` does not clear hover | `interaction_layer_test`: hover a line, exit the layer, `selection.hover == null` |
| M-02j | group delete skips the owned leaves | `select_tool_test`: group of three leaves and a nested group with one; after Delete, `entities.slotOf` is null for all four and both nodes are gone |
| M-02k | `SelectionController` never subscribes to `changes` | `selection_test`: select a leaf, `execute(RemoveEntityCommand)` externally, pump a microtask, `isEmpty`; and the sibling assertion that an unrelated `AddEntityCommand` leaves a selected instance in place |
| M-02l | `pickRadiusWorld` not divided by `camera.scale` | `interaction_layer_test`: camera at scale 0.25, a click 5 px from a line on screen picks it (mutated world radius 6 = 1.5 px misses); the scale-4 half is not discriminating and is not used |
| M-02m | overlay stroke width not divided by `camera.scale` | `selection_overlay_test`: `SpyCanvas` records `strokeWidth == 2.0 / 4.0` at scale 4 |
| M-02n | permission preflight dropped from Delete | `select_tool_test`: `DraftPermissions.readOnly` document, select, Delete: no exception, entity present, still selected |
| M-02o | instance crossing tests the instance box instead of descending | `band_query_test`: an L-shaped block; a band inside the empty quadrant of its box selects nothing |
| M-02p | D2 resolves to the **nearest** group, not the topmost | `selection_test`: leaf owned by a group inside a group → the outer group; **and** a leaf owned by a group directly under the root → that group (the single-level arm) |
| M-02r | group window rule reads "any" instead of "every" | `select_tool_test`: group of two leaves, one inside a window band, one outside; window: not selected; crossing: selected |
| M-02s | the dirty-overlay fallback dropped from the window predicate | `band_query_test`: edit the straddling leaf with `SetEntityGeometryCommand`, run the window band before any rebuild |
| M-02t | `transformOfLeaf` dropped from the band descent | `band_query_test`: `generateDocument(groupCount: …)` with a grouped leaf inside a placed definition; the band covers where it lands only with the group transform |
| M-02u | band walks report a fill slot | `band_query_test`: a region (fill + boundary); crossing reports the boundary only |
| M-02v | outline path built at absolute world coordinates | `selection_overlay_test`: a line at `kDefaultOriginX`; the recorded path's bounds under the recorded transform agree with the line's screen endpoints to 0.01 px |
| M-02w | cache not rebuilt on a `DocChange` inside a selected container | `outline_cache_test`: select an instance, move a leaf inside its definition with `SetEntityGeometryCommand`, pump; the outline's bounds moved |
| M-02x | the `KeyDownEvent` gate removed | `interaction_layer_test`: one full Delete press (down, up); `document.commands` shows exactly one remove |
| M-02y | `onPointerCancel` not wired to `cancel` | `interaction_layer_test`: drag into a band, inject a cancel; `phase == idle`, band gone, selection untouched |
| M-02z | the band walks' result sort dropped | `band_query_test`: a fixture whose R-tree order differs from handle order; the visit sequence is ascending |
| M-02aa | `replace` notifies unconditionally | `selection_test`: listener counter across a no-op `replace` with the same set |
| M-02ab | a fresh `Paint` per key per frame in the overlay | `selection_overlay_test`: the `Paint` identities recorded by `SpyCanvas` across two frames are the same two objects |
| M-02ac | the hover skip removed | `selection_overlay_test`: hover == the single selected key; exactly one `drawPath` |

Thirty named, two equivalent by construction (M-02c, M-02e) with their
reasons logged, twenty-eight to kill.

### Equivalence

A mutant is equivalent only if no test **could** distinguish it under this
spec's rules, and the log says why in one sentence. "Hard to reach" is not
equivalent. The 01 precedent: E-01e′ was declared equivalent because the
Flutter VM gate made two events indistinguishable; the reason was written
down.

### Differential check

`band_query_test` includes one differential test: for a `generateDocument`
corpus (400 entities, 40 instances, nesting depth 2, mirrored and
non-uniform fractions non-zero, `groupCount` non-zero) and a band, the
crossing result must equal the brute-force set computed by transforming every
leaf of every root-level object to world and applying the same predicate
without the index. Window likewise. This catches a broad phase that is too
tight and a descent that drops a transform.

---

## Exit gate

| # | criterion |
|---|---|
| 1 | Clicking an entity selects exactly it; clicking empty space clears; both from a non-identity camera. |
| 2 | Window and crossing bands select the D8 sets; the straddling fixture distinguishes them; both drag directions and the vertical drag tested. |
| 3 | The same leaf under two instances yields two keys; two leaves of one instance yield one. |
| 4 | Hover follows the pointer, clears on exit, and is never drawn for a key that is already selected. |
| 5 | Shift toggles; Escape cancels a band or clears; Delete removes through the command log on one key-down and undo restores the geometry (not the selection). |
| 6 | Selection change repaints the overlay and not the canvas: `DraftCanvas.onPaintForTest` unchanged across `replace`, the overlay's count +1 — an invariant test, since the mutation cannot be planted without editing `DraftCanvas`. |
| 7 | `SelectTool` implements `Tool`; `ToolController.activate` cancels the outgoing tool and re-points its listener; a second trivial tool in the test suite proves the interface is not `SelectTool`-shaped. |
| 8 | All thirty mutants killed or declared equivalent with a reason, in `docs/superpowers/notes/plan-02-mutation-log.md`. |
| 9 | The differential band test passes on the generated corpus. |
| 10 | `query_allocation_test` and `paint_allocation_test` pass unchanged. |
| 11 | Harness untouched: `git diff --stat main..HEAD -- apps/dev_harness_2d` empty; its 82 tests pass. |
| 12 | All eleven gate commands exit 0 (`CI=true` prefixed), except `jet_cad_2d_flutter`'s `flutter test` on the same five pre-existing `text_ladder_golden_test.dart` failures and nothing else (the 01 baseline ruling); no `analysis_options.yaml` in the diff. |
| 13 | The app's top bar shows the tool name and the selection count, and a widget test drives it. |
| 14 | The overlay outline coincides with the drawn entity at `kDefaultOriginX` to 0.01 px (M-02v's fixture, as a plain test too). |
| 15 | A human looked, on macOS, in Chrome and in Firefox from `build/web`: click, shift-click, both bands, hover, Escape, Delete, undo; each recorded seen / not seen / could not judge. |

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
  its leaves, with Escape to leave. `SelectionKey.chain` exists for this: a
  leaf selected inside instance A becomes `(chain: [A], target: leaf)`, a
  policy change in `resolveHit`, not a type change. 03 or 05 decides when it
  is needed.
- **Compound undo.** D10's N-step delete and the partial-undo hazard are the
  first concrete cases for 06's spike.
- **Selection after undo.** 02 says "not restored". Most CAD tools agree; a
  later sub-project may reselect what an undo brought back.
- **Rotated text under a window band.** D8 accepts the AABB's looseness.
  If the look finds it wrong, the fix is an oriented-box-inside-rect test,
  local to the window predicate.
- **Outline cache invalidation.** D9 rebuilds everything on every change; 03
  measures whether its drag needs the containment rule instead.
- **Touch.** Nothing designed. A long-press-to-band or two-finger convention
  is 12's or later.

## What this changes outside 02

- `jet_cad_2d` gains two public query methods and one enum on its index, and
  one file of pure predicates.
- `jet_cad_2d_flutter` gains ten files and their exports. `DraftCanvas`,
  `DraftPainter`, `CameraGestureDetector` unchanged.
- `apps/floor_planner` gains the interaction tree, two controllers on the
  shell state and one status text.
- `roadmap/02-interaction-core.md` status line, `roadmap/00-README.md`
  status row, `STATUS.md` — at merge, as 01 did.

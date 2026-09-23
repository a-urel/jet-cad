# Grips and transform (sub-project 03) — implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** a selected object in `apps/floor_planner` shows grips. Dragging a
grip stretches a line end, a polyline vertex (a closed room's shared corner
as one), a circle's radius or an arc's end or radius. Dragging a selected
body or a centre grip moves the whole selection, and a rotation grip turns
it. Each drag previews live in the overlay, object-snaps with markers, falls
back to the grid and takes shift for ortho. Release dispatches exactly one
`CompoundCommand` labelled `Move`, `Rotate` or `Stretch`, and nothing else.
Escape and every other cancel path leave the document byte-identical. F3
toggles object snap.

**Architecture:** the engine gains `document/grips.dart`, which holds the
grip set per kind, the closed-polyline rule, `reshapeLeaf` and
`rigidTransformLeaf`, all pure and in owner space. It also gains
`index/drag_snap.dart`, which resolves object snap, then the ortho override,
then the grid, into a caller-owned `DragPoint`. The render layer gains
`OutlineCache.worldBoundsOf`, which bounds a key in doubles and never through
a `ui.Path`. It gains `GripCache`, which holds the world grips, the
selection box and the cap, rebuilt at selection and document rate.
`GripDrag` holds the press-time captures, the drag's `T` or its preview
payload, the revalidation and the one command. `SnapSettings` and
`drawSnapMarker` are new. `Tool` gains a cursor, a preview transform and a
world-space paint hook, and `ToolContext` gains three optional fields.
`SelectTool` gains the press classes, the drag kinds, the camera listener
and the key rule. `InteractionLayer` rebuilds only its `MouseRegion` when the
tool notifies. The overlay draws grips with `drawRawPoints`, then the
rotation grip, then the preview through `worldToScreen ∘ T ∘
translate(origin)`. The shell owns `OutlineCache`, `GripCache` and
`SnapSettings`, binds F3, shows `osnap-text` and gains a two-parameter test
seam.

**Tech Stack:** Dart, Flutter **3.47.2** (the installed SDK, under a cask
directory named `3.27.3`), `flutter_test`, `package:test`, `vector_math`,
`jet_cad_2d`, `jet_cad_2d_flutter`. No new dependency anywhere.

**Spec:** [docs/superpowers/specs/2026-09-23-grips-and-transform-design.md](../specs/2026-09-23-grips-and-transform-design.md),
**revision 2**. Read it whole before Task 1: the preamble ("world is root
space"), D1–D12, the eight invariants, the fixture rules, the twenty-seven
mutants M-03a…M-03aa, the differential check, the widget tests and the
sixteen exit criteria. The review that produced revision 2 is
[docs/superpowers/notes/2026-09-23-grips-and-transform-spec-review-r1.md](../notes/2026-09-23-grips-and-transform-spec-review-r1.md).
A developer is most likely to undo three of its findings by reflex:
- #1: never conjugate by the root's transform, and never write it.
- #4: the preview matrix is `worldToScreen ∘ T ∘ translate(origin)`, not
  `matrix ∘ T`.
- #3: the selection box comes from world records, never from
  `Path.getBounds`.

**Roadmap input:** [roadmap/03-grips-and-transform.md](../../../roadmap/03-grips-and-transform.md).

**Branch:** `plan-03/grips-and-transform`, cut from local `main` at
`c09b747` or later, in its own worktree. **`origin/main` is stale**
(memory: `jet-cad-plan-status`), so create the worktree by hand from local
`main`:

```sh
git worktree add .claude/worktrees/plan-03-grips-and-transform -b plan-03/grips-and-transform main
```

Enter it with `EnterWorktree path=.claude/worktrees/plan-03-grips-and-transform`.
While the plan is in flight, the ledger lives at
`.superpowers/sdd/2026-09-23-grips-and-transform/` (git-ignored, in the
worktree). As the branch's last commit before the merge, it is archived to
`docs/superpowers/ledgers/2026-09-23-grips-and-transform/`.

---

## Rulings made here rather than left to an implementer

Each ruling says what the plan does, why, and what it costs if it is wrong.
The ones marked **(spec amended)** are written into the spec as "Amended at
execution (Plan 03)" paragraphs in Task 12.

- **Ruling 03-1 — an arc's derived end angle is compared modulo 2π (spec
  amended, D3 and exit criterion 2).** D3 says that after a start-grip
  stretch, `s' + sweep'` equals the old `s + sweep` within `Tolerance`. The
  code cannot keep that literally. `s' = atan2(…)` lies in `(−π, π]`, and a
  stored `s` need not. Example: `s = 4.0`, `sweep = 1.0`, dragged to the
  direction `4.1`:
  - `s' = 4.1 − 2π`;
  - `sweep' = 0.9`;
  - so `s' + sweep' = 5.0 − 2π`. That is the same angle, but not the same
    double within 1e-9.
  The tests therefore compare `cos` and `sin` of the two angles within
  `Tolerance.standard.angular`. `grips_test.dart` carries this example as
  the ruling's witness. Cost if wrong: none; a same-direction check is what
  "the untouched end stays" means geometrically.
- **Ruling 03-2 — the "grip index" in D2's tie-break is the grip's ordinal
  in `leafGrips`' list.** `Grip.index` repeats across roles. An arc's start
  is `(stretch, 0)`, its radius grip is `(radius, 0)`, and its centre is
  `(move, 0)`. So "the lower grip index" has to mean list position.
  `GripRef.ordinal` carries it. Cost: none; within one object, coincident
  grips only happen on a degenerate zero-length segment.
- **Ruling 03-3 — the reshape preview is drawn through a new
  `Tool.paintWorldOverlay(Canvas, Vector2 origin, double scale)`, default
  no-op (spec amended, D7).** D7 says the reshape preview "is drawn by
  `SelectTool.paintOverlay`, which receives the origin through the
  painter". `paintOverlay(Canvas, ViewportTransform, Size)` has no origin
  parameter, and `tool_controller_test.dart`'s `_CountingTool` implements
  that exact signature. Instead, the overlay calls the new hook inside its
  existing `save … transform(_matrix) … restore` block, handing it the
  frame's origin and scale. The tool then draws `world − origin` under the
  overlay's own matrix, as D7 intends. Cost: one more `Tool` member with a
  default; no implementer changes.
- **Ruling 03-4 — the overlay reads the grips from `tools.context.grips`.**
  It takes no new constructor parameter. The tool hit-tests against the
  same `GripCache`, so what is drawn and what is hit cannot come from two
  caches. Cost: the painter depends on `ToolController.context`, which it
  already holds.
- **Ruling 03-5 — permissions are read live, never cached.**
  - `GripCache.leafGripsLive` reads `document.commands.permissions` at each
    call. The tool calls it at press and hover, the painter per frame.
  - `DraftPermissions` changes are not notified, so a cached answer would
    go stale.
  - A test changes permissions mid-drag by assigning the dispatcher's
    mutable field, `doc.commands.permissions = DraftPermissions.runtime;`.
    That is the idiom `select_tool_test.dart`'s read-only test already uses.
  - Cost: one bool read per frame.
- **Ruling 03-6 — the "press-time" capability check runs when the press
  crosses the slop, before any drag starts (spec amended, D2).**
  - For class 3b, the selection the drag would move is only known then:
    the current selection plus the key under a shift press, or that key
    alone.
  - A refused check marks the press click-only. Later moves do nothing, and
    release acts as the 02 click.
  - For 3b, the selection is not changed at the slop crossing when the
    check refuses.
  - The rotation grip is drawn and hit under any permissions; D2 hides only
    leaf grips. A refused rotate simply never starts.
  - Cost: none. Permissions cannot change between a press and a 4 px move
    except by a test, and the release check (D4) covers that.
- **Ruling 03-7 — the camera listener's lifecycle.**
  - `SelectTool._enter` adds the listener `_onCamera` (a method tear-off)
    to `ctx.camera` for move, rotate and reshape. A band gets no listener.
  - `_enter` also keeps the `ToolContext`, the last screen point and the
    last shift.
  - `_endDrag` is the single exit, and it removes the listener. Release,
    `cancel`, Escape, `ToolController.activate` and layer
    deactivate/dispose all go through it.
  - `_onCamera` maps the last screen point through the new camera and
    re-resolves the target.
  - Cost if wrong: a leaked listener. T14 checks that a camera change after
    release leaves no preview.
- **Ruling 03-8 — `KeyRepeatEvent` is consumed during a drag too (spec
  amended, D5).**
  - D5 says every key-down. A held cmd+Z auto-repeats as `KeyRepeatEvent`s,
    which are not `KeyDownEvent`s.
  - The shell's `SingleActivator(keyZ, meta: true)` keeps the default
    `includeRepeats: true`, so a repeat would bubble and undo mid-drag.
  - Key-ups pass: no shortcut acts on them.
  - Cost: none; the release revalidation would have caught it anyway.
- **Ruling 03-9 — a centre grip moves the whole selection, from the grip
  itself.** The spec says it both ways. "What this delivers" says dragging
  the centre grip "moves it". Exit criterion 4 says "a centre grip does the
  same" as a body drag, which moves the selection. The plan follows the
  exit criterion. The base is the grip's world point exactly (D8). Cost: a
  one-object selection behaves identically either way.
- **Ruling 03-10 — the grip point buffers are sized exactly, and are
  reallocated only when the count changes (spec amended, D6).**
  - `drawRawPoints` draws its whole list. A capacity-grown buffer would need
    a `sublistView` per frame, which is one allocation per draw call.
  - Exact sizing reallocates only at selection-change rate, and steady
    frames allocate nothing.
  - D6 says grips are "rebased by the frame origin before narrowing". The
    plan projects world → screen in doubles and narrows only screen
    coordinates, which are small. No world coordinate reaches float32, which
    is the property D6's sentence protects.
- **Ruling 03-11 — `dragGridStepMm(PageComponent?, double pxPerWorldMm)`
  lives in `drag_snap.dart` (spec amended, D8).**
  - It returns `page.gridStepMm` exactly, else the adaptive `pick(...)`'s
    `minorMm ?? majorMm`. That is 04's D6 rule, stated once.
  - Sub-project 05 inherits it together with `resolveDragPoint`.
- **Ruling 03-12 — the per-event cost includes three O(1) allocations (spec
  amended, invariant 5).**
  - `snapToGrid` returns a fresh `Vector2`.
  - `GridScale.pick` returns a fresh `GridScale`.
  - The camera listener's `screenToWorld` returns a fresh `Vector2`.
  - All three are per pointer event, never per entity. The frame path
    (paint) of a move or rotate preview allocates nothing beyond 02's
    overlay. A reshape frame builds one `Path`.
  - Invariant 5's "one `snapInto` … and, for a reshape only, one preview
    path" is amended to name them.
- **Ruling 03-13 — release re-targets from the up event before building the
  command.** The up carries the final position, which equals the last move
  under a mouse. It also makes M-03p's "back to the press pixel" exact.
- **Ruling 03-14 — the rotation angle is normalised to `(−π, π]` before
  shift-rounding.** `θ = atan2(pointer − p) − atan2(press − p)` lies in
  `(−2π, 2π)`. Normalising keeps an arc's `startAngle + θ` and a text's
  `rotation + θ` within one turn of their stored values. The geometry is the
  same either way.
- **Ruling 03-15 — `GripCache.rotatable` is `box != null` (spec amended,
  D6).**
  - A fill has no outline of its own (`OutlineCache._addLeaf` returns for a
    fill), so a fills-only selection has no box.
  - So "at least one non-fill key" is implied by a non-null box.
  - A separate non-fill flag would be an unkillable (equivalent) mutant.
- **Ruling 03-16 — the differential's tolerance scale is `max(2e6, |a|,
  |b|)`, not `max(|a|, |b|)` (spec amended, Testing).**
  - A rotated sample can land near zero while its operands sit near 2e6.
  - Cancellation then leaves roughly 1e-10 absolute error against a 1e-12
    floor. At 200 trials that fails spuriously a few times per run.
  - `2e6` is the trial range the spec itself names, so the bound becomes
    the spec's "about 1.1e-7" everywhere.
  - It still cannot hide an angle error. The smallest mutated error is
    `r·θ ≥ 1 × 1.5e-3`.
- **Ruling 03-17 — the plan adds mutants M-03ab…M-03ax (spec amended,
  Testing).** `CLAUDE.md` says a test lands only if a named mutation turns
  it red. Twenty-three tests below guard spec behaviour that has no named
  mutant: the cursor rebuild, the camera listener, the press-time
  permission, the preview cross, F3 repeats, the marker shapes, the arc and
  point bounds, the coincident-grip tie, the rebased reshape preview, the
  rotation grip's side, the grip cache's document listener, fills in a
  move, member order, cancel, the captured exit, the hot grip, the marker's
  position, a click on a grip, the centre grip, the stretch target, the
  press check, the fixed grid step and the rigidity check. Each gets a
  mutant in Task 10's table. `M-03ah` fires twice: the arc edit and the
  point edit (`ah′`).
- **Ruling 03-18 — the shell's test seam.**
  - `PlannerShell({Key? key, DraftDocument? document, ViewportTransform?
    initialCamera})`.
  - A test document must carry a `FlutterTextMeasurer`, because
    `DraftCanvas` refuses any other.
  - With no page, the nominal camera is `ViewportTransform.fit(extents,
    1440×900)`.
  - The shell widget tests run on a 1440 × 900 surface. They set their
    rotated camera after `pumpWidget` + `pump`, because `PlannerView` fits
    once at the end of its first frame (Ruling 04-16). The test says so in a
    comment.
- **Ruling 03-19 — `GripCache` listens to the `SelectionController` and to
  the `OutlineCache`, never to `document.changes`.**
  - The box is derived from `OutlineCache`'s world records, so it must
    rebuild after them.
  - `OutlineCache` notifies after its `DocChange` rebuild. On a selection
    change, `OutlineCache`'s listener was added first, so it runs first.
  - A selection notification whose key set is unchanged is skipped: that is
    a hover change, and rebuilding for it would reset the hot grip under the
    pointer.
- **Ruling 03-20 — M-03e's companion check is a standing test.**
  `grip_drag_test.dart` keeps a test that perturbs one restored coordinate
  by one ulp. It asserts that `==` sees the difference and that the
  `Tolerance` comparison does not. M-03e itself (the undo test switched to
  `Tolerance`) is fired in Task 10 and must stay green. The log records it
  as the designed survivor.
- **Ruling 03-21 — only one 02 test changes.** It is `select_tool_test.dart`'s
  "a 5 px move from empty space starts a band; from a hit it does not",
  which pins the old line 76 (`if (_downHit) return;`). Task 7 renames it
  with `D12` in its name and asserts the new behaviour.
  - Every other 02 tool test builds its `ToolContext` without `grips`. With
    `ctx.grips == null`, class 2 cannot occur, so D12's grip-click change
    cannot reach them.
  - The shell tests click walls that are not yet selected, so no grip is
    under their taps.

## Global Constraints

These are copied from `CLAUDE.md` and the spec; this plan's additions are
marked.

- **Pure-Dart engine.** Nothing under `packages/jet_cad_2d` imports Flutter
  or `dart:ui`. Task 11 greps for it.
- **`unused_import` and `unused_element` are errors in
  `jet_cad_2d_flutter`**, and that includes test files and fixtures.
  Import only names you reference.
- **The frame path allocates nothing per entity in steady state, and O(1)
  per flush.** `query_allocation_test.dart` and `paint_allocation_test.dart`
  stay green and unedited. **This plan adds:** the overlay draws grips in
  O(1) draw calls, from exact-size reused `Float32List`s, with no `Rect` or
  `Offset` per grip (invariant 6; Ruling 03-10).
- **Draw order is ascending handle value.** No drag allocates or frees a
  handle (invariant 4, checked in T3).
- **Geometric decisions use `Tolerance`; stored-value comparisons are exact
  `==`.**
  - The decisions are: the degenerate-reshape rule, the rigidity check, the
    move test's landing check, and the arc's derived end angle (Ruling
    03-1).
  - The stored values are: payloads (`GeometryPayload ==`), nodes
    (`GroupNode`/`InstanceNode ==`) and closedness.
  - **`Transform2` is never compared with `==`**: it is object identity.
- **World is root space.** Never read or write the root's transform. Every
  fixture asserts the root is the identity (`gripScene` does).
- **Never commit `analysis_options.yaml`.** Run `git status --short` before
  every commit. `git checkout -- <path>` only an `analysis_options.yaml`
  that `pub get` rewrote.
- **Never `git checkout --` a `.dart` file.** Before firing a mutation, back
  the file up with `cp`, restore from that copy, and `diff` to prove the
  restore.
- **Never synthesize test output.** Run the command and paste what it
  printed, including the summary line and the exit code.
- **Prefix every test command with `CI=true`.**
- **Code, comments and commit messages in English.**
- **Every commit ends with the trailer, exactly:** `Co-Authored-By: Claude
  Opus 5.5 <noreply@anthropic.com>`. Check it with `git log -1 --format=%B |
  grep -c "Opus 5.5"`, which must print `1`.
- **Format before the gate.** Run `dart format <files you touched>` before
  the gate line. The code blocks here are not guaranteed to be
  formatter-exact.
- **Every fixture is off the identity** (spec, Testing). The standard scene
  is `gripScene()` (Task 4), all at x ≈ 7000–7550, y ≈ 3000–3330. It has:
  - a rotated group;
  - two instances of one definition;
  - arcs with a non-zero start, one of them with a negative sweep;
  - a closed room.
  The standard camera is `gripCamera()`: scale 1.1, rotated 0.35 rad, y
  flipped, panned. Never scale 1.0 and never 0° or 90°.
- **Every task ends green.** The gate lines (spec criterion 15):

  ```sh
  cd packages/jet_cad_2d         && CI=true dart test && dart analyze && dart format --output=none --set-exit-if-changed .
  cd packages/jet_cad_2d_flutter && CI=true flutter test ; flutter analyze && dart format --output=none --set-exit-if-changed .
  cd apps/dev_harness_2d         && CI=true flutter test --concurrency=1 && flutter analyze && dart format --output=none --set-exit-if-changed .
  cd apps/floor_planner          && CI=true flutter test && flutter analyze && dart format --output=none --set-exit-if-changed . && flutter build macos --release && flutter build web --release
  ```

  - **The one standing exception:** the render layer's `flutter test` exits
    1 on the five pre-existing `text_ladder_golden_test.dart` failures and
    on nothing else. That is why its line uses `;` before `flutter
    analyze`. Paste its summary line and check the five failing names.
  - Tasks 1–3 run the `jet_cad_2d` line.
  - Tasks 4–8 run the `jet_cad_2d_flutter` line. Task 3 also runs it,
    because the barrel grew.
  - Task 9 adds the `floor_planner` line.
  - Tasks 11 and 12 run all four.
  - `apps/dev_harness_2d` is untouched: 82 tests at the branch point.

## File structure

| file | responsibility |
|---|---|
| `packages/jet_cad_2d/lib/src/document/grips.dart` | **create** — `GripRole`, `Grip`, `isClosedPolyline`, `leafGrips`, `reshapeLeaf`, `isRigidTransform`, `rigidTransformLeaf` |
| `packages/jet_cad_2d/lib/src/index/drag_snap.dart` | **create** — `kDragSnapMask`, `kSnapAperturePixels`, `DragPoint`, `resolveDragPoint`, `dragGridStepMm` |
| `packages/jet_cad_2d/lib/jet_cad_2d.dart` | **modify** — two exports |
| `packages/jet_cad_2d/test/document/grips_test.dart` | **create** — G1–G11 |
| `packages/jet_cad_2d/test/document/rigid_transform_test.dart` | **create** — R1–R6, the differential |
| `packages/jet_cad_2d/test/index/drag_snap_test.dart` | **create** — S1–S8 |
| `packages/jet_cad_2d_flutter/lib/src/outline_cache.dart` | **modify** — `worldBoundsOf` |
| `packages/jet_cad_2d_flutter/lib/src/selection_style.dart` | **modify** — grip, preview and marker constants |
| `packages/jet_cad_2d_flutter/lib/src/grip_cache.dart` | **create** — `kMaxGrips`, `kGripHitPixels`, `GripRef`, `rotationGripOf`, `GripCache` |
| `packages/jet_cad_2d_flutter/lib/src/snap_settings.dart` | **create** — `SnapSettings` |
| `packages/jet_cad_2d_flutter/lib/src/tool.dart` | **modify** — `ToolContext.page/snap/grips`; `Tool.cursor`, `selectionPreviewTransform`, `paintWorldOverlay` |
| `packages/jet_cad_2d_flutter/lib/src/interaction_layer.dart` | **modify** — `ListenableBuilder` around the `MouseRegion` |
| `packages/jet_cad_2d_flutter/lib/src/grip_drag.dart` | **create** — `DragKind`, `kRotationStep`, `GripDrag` |
| `packages/jet_cad_2d_flutter/lib/src/select_tool.dart` | **modify** — `PressClass`, drags, camera listener, keys, cursor; then (Task 8) guide, marker, reshape preview |
| `packages/jet_cad_2d_flutter/lib/src/snap_marker.dart` | **create** — `drawSnapMarker` |
| `packages/jet_cad_2d_flutter/lib/src/selection_overlay.dart` | **modify** — world hook, preview pass, preview crosses, grips, rotation grip |
| `packages/jet_cad_2d_flutter/lib/jet_cad_2d_flutter.dart` | **modify** — five exports |
| `packages/jet_cad_2d_flutter/test/support/grip_fixture.dart` | **create** (Task 4), **rewritten** (Task 7) — `GripScene`, `gripScene`, `gripCamera`, `screenOf`, `payloadOf`, `snapshot`; then `GripRig`, `gripRig`, `pointerAt`, `pressAndMove`, `release`, `click`, `pumpGripLayer`, `globalAt`, `kGripLayerSize` |
| `packages/jet_cad_2d_flutter/test/outline_cache_test.dart` | **modify** — O1 |
| `packages/jet_cad_2d_flutter/test/grip_cache_test.dart` | **create** — C1–C7 |
| `packages/jet_cad_2d_flutter/test/interaction_cursor_test.dart` | **create** — I1 |
| `packages/jet_cad_2d_flutter/test/grip_drag_test.dart` | **create** — D1–D11 |
| `packages/jet_cad_2d_flutter/test/select_tool_drag_test.dart` | **create** — T1–T6, T8–T17, W1–W3 (no T7) |
| `packages/jet_cad_2d_flutter/test/select_tool_test.dart` | **modify** — the D12 test (Ruling 03-21) |
| `packages/jet_cad_2d_flutter/test/selection_overlay_grips_test.dart` | **create** — P1, P2, P4, P5, P6, P8 |
| `packages/jet_cad_2d_flutter/test/snap_marker_test.dart` | **create** — K1 |
| `apps/floor_planner/lib/main.dart` | **modify** — seam, `SnapSettings`, `OutlineCache`, `GripCache`, F3, `osnap-text` |
| `apps/floor_planner/lib/planner_view.dart` | **modify** — takes `outlines` and `grips`; `grips` in the repaint merge |
| `apps/floor_planner/test/planner_grips_test.dart` | **create** — A1–A4 |
| `docs/superpowers/notes/plan-03-mutation-log.md` | **create** (Task 10) |
| `docs/superpowers/notes/2026-09-23-plan-03-results.md` | **create** (Task 12) |
| the spec, `roadmap/03-grips-and-transform.md`, `roadmap/00-README.md`, `STATUS.md` | **modify** (Task 12) |

In Tasks 1–3, paths under `lib/` and `test/` are relative to
`packages/jet_cad_2d/`. In Tasks 4–8 they are relative to
`packages/jet_cad_2d_flutter/`, and in Task 9 to `apps/floor_planner/`.

---

### Task 1: The branch point, and `grips.dart` — the grip set, closedness, reshape

**Files:**
- Create: `lib/src/document/grips.dart`
- Modify: `lib/jet_cad_2d.dart` (add `export 'src/document/grips.dart';`
  between `extents.dart` and `fill_index.dart`)
- Test: `test/document/grips_test.dart`

**Interfaces:**
- Consumes: `GeometryPayload` (`coords`, `scalars`, `pointCount`) from
  `store/geometry_store.dart`; `EntityKind` from `store/entity_store.dart`;
  `Tolerance.standard` from `core/tolerance.dart`; `Vector2`.
- Produces:
  - `enum GripRole { stretch, radius, move }`
  - `final class Grip { const Grip(GripRole role, int index, double x, double y); … }`
    with exact `==` and `hashCode`.
  - `bool isClosedPolyline(GeometryPayload payload)`
  - `List<Grip> leafGrips(EntityKind kind, GeometryPayload payload)`: the
    list order is the grip's ordinal (Ruling 03-2).
  - `GeometryPayload? reshapeLeaf(EntityKind kind, GeometryPayload payload, Grip grip, Vector2 localTarget)`

- [ ] **Step 1: The branch point.** In the worktree:
  - Run `git log --oneline -1` and check it is `c09b747` or later.
  - Run `flutter pub get` at the worktree root.
  - Run the four gate lines once and paste the four summary lines into the
    ledger's `progress.md`. At the Plan 04 merge they were: engine 862;
    render layer 797 + 1 skip + the five goldens; harness 82; app 21 with
    both builds. If they differ, record what they are — do not assume.
  - `git checkout --` the three `analysis_options.yaml` files that `pub
    get` rewrote.

- [ ] **Step 2: Write the failing test.**

```dart
// test/document/grips_test.dart
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

GeometryPayload payload(List<double> coords, List<double> scalars) =>
    GeometryPayload(
        coords: Float64List.fromList(coords),
        scalars: Float64List.fromList(scalars));

// The spec's fixture rules: off the origin, a closed room, arcs with a
// non-zero start and one negative sweep.
final GeometryPayload line = payload([7010, 3020, 7130, 3060], []);
final GeometryPayload open5 = payload(
    [7010, 3100, 7040, 3130, 7070, 3100, 7100, 3130, 7130, 3100], []);
final GeometryPayload room = payload(
    [7200, 3000, 7400, 3000, 7400, 3150, 7200, 3150, 7200, 3000], []);
final GeometryPayload circle = payload([7300, 3250], [25]);
final GeometryPayload arcPos = payload([7050, 3200], [40, 0.3, 1.9]);
final GeometryPayload arcNeg = payload([7150, 3250], [30, 2.2, -1.4]);

/// Ruling 03-1: two angles are the same angle when their unit vectors
/// agree; a derived angle may differ from a stored one by a whole turn.
void expectSameDirection(double actual, double expected) {
  expect(math.cos(actual),
      closeTo(math.cos(expected), Tolerance.standard.angular));
  expect(math.sin(actual),
      closeTo(math.sin(expected), Tolerance.standard.angular));
}

/// A point at [angle] and [radius] about [arc]'s centre.
Vector2 at(GeometryPayload arc, double angle, double radius) => Vector2(
    arc.coords[0] + radius * math.cos(angle),
    arc.coords[1] + radius * math.sin(angle));

void main() {
  group('leafGrips', () {
    test('the grip set per kind, in owner space (M-03y)', () {
      expect(leafGrips(EntityKind.line, line), const [
        Grip(GripRole.stretch, 0, 7010, 3020),
        Grip(GripRole.stretch, 1, 7130, 3060),
      ]);
      final open = leafGrips(EntityKind.polyline, open5);
      expect([for (final g in open) g.index], [0, 1, 2, 3, 4]);
      expect(open[2], const Grip(GripRole.stretch, 2, 7070, 3100));
      // Closed: vertex 0 stands for the repeated last vertex (spec D3).
      expect(leafGrips(EntityKind.polyline, room), const [
        Grip(GripRole.stretch, 0, 7200, 3000),
        Grip(GripRole.stretch, 1, 7400, 3000),
        Grip(GripRole.stretch, 2, 7400, 3150),
        Grip(GripRole.stretch, 3, 7200, 3150),
      ]);
      final c = leafGrips(EntityKind.circle, circle);
      expect(c, hasLength(5));
      expect(c[0], const Grip(GripRole.move, 0, 7300, 3250));
      const quadrants = [
        [7325.0, 3250.0],
        [7300.0, 3275.0],
        [7275.0, 3250.0],
        [7300.0, 3225.0],
      ];
      for (var q = 0; q < 4; q++) {
        expect(c[q + 1].role, GripRole.radius);
        expect(c[q + 1].index, q);
        expect(c[q + 1].x, closeTo(quadrants[q][0], 1e-9));
        expect(c[q + 1].y, closeTo(quadrants[q][1], 1e-9));
      }
      final a = leafGrips(EntityKind.arc, arcNeg);
      expect([for (final g in a) (g.role, g.index)], [
        (GripRole.move, 0),
        (GripRole.stretch, 0),
        (GripRole.stretch, 1),
        (GripRole.radius, 0),
      ]);
      expect(a[0].x, 7150);
      expect(a[0].y, 3250);
      for (final (g, angle) in [
        (a[1], 2.2),
        (a[2], 2.2 - 1.4),
        (a[3], 2.2 - 0.7),
      ]) {
        final p = at(arcNeg, angle, 30);
        expect(g.x, closeTo(p.x, 1e-9));
        expect(g.y, closeTo(p.y, 1e-9));
      }
      for (final kind in [
        EntityKind.point,
        EntityKind.text,
        EntityKind.attrib,
        EntityKind.fill,
      ]) {
        expect(leafGrips(kind, payload([7250, 3300], [12])), isEmpty,
            reason: kind.name);
      }
    });

    test('isClosedPolyline is an exact stored-value test', () {
      expect(isClosedPolyline(room), isTrue);
      expect(isClosedPolyline(open5), isFalse);
      expect(
          isClosedPolyline(payload([7010, 3020, 7100, 3090, 7010, 3020], [])),
          isTrue);
      expect(isClosedPolyline(payload([7010, 3020, 7010, 3020], [])), isFalse,
          reason: 'two points are a segment, not a loop');
      final nudged = Float64List.fromList(room.coords)..[8] = 7200.000000000001;
      expect(nudged[8], isNot(7200.0));
      expect(
          isClosedPolyline(
              GeometryPayload(coords: nudged, scalars: Float64List(0))),
          isFalse,
          reason: 'closedness is ==, not Tolerance');
    });
  });

  group('reshapeLeaf', () {
    test('a line stretch writes the grabbed pair and copies the rest', () {
      final grips = leafGrips(EntityKind.line, line);
      final out = reshapeLeaf(
          EntityKind.line, line, grips[1], Vector2(7151.125, 3077.375))!;
      expect(out.coords, [7010, 3020, 7151.125, 3077.375]);
      expect(out.scalars, isEmpty);
      // A zero-length segment is legal geometry, never degenerate.
      expect(
          reshapeLeaf(EntityKind.line, line, grips[1], Vector2(7010, 3020)),
          isNotNull);
    });

    test('a polyline middle-vertex stretch moves that vertex and nothing '
        'else (M-03o)', () {
      final grip = leafGrips(EntityKind.polyline, open5)[2];
      final out = reshapeLeaf(
          EntityKind.polyline, open5, grip, Vector2(7066.5, 3088.25))!;
      final expected = Float64List.fromList(open5.coords)
        ..[4] = 7066.5
        ..[5] = 3088.25;
      expect(out.coords, expected);
    });

    test('a closed room corner moves as one: first and last pairs stay == '
        '(M-03r)', () {
      final grips = leafGrips(EntityKind.polyline, room);
      final out = reshapeLeaf(
          EntityKind.polyline, room, grips[0], Vector2(7188.5, 2990.25))!;
      expect(out.coords,
          [7188.5, 2990.25, 7400, 3000, 7400, 3150, 7200, 3150, 7188.5, 2990.25]);
      expect(isClosedPolyline(out), isTrue);
      final other = reshapeLeaf(
          EntityKind.polyline, room, grips[2], Vector2(7410, 3160))!;
      expect(other.coords,
          [7200, 3000, 7400, 3000, 7410, 3160, 7200, 3150, 7200, 3000]);
    });

    test('a circle radius grip sets r = |target − centre|; degenerate is '
        'null', () {
      final q = leafGrips(EntityKind.circle, circle)[2];
      final out =
          reshapeLeaf(EntityKind.circle, circle, q, Vector2(7330, 3290))!;
      expect(out.coords, circle.coords);
      expect(out.scalars, [50]);
      expect(reshapeLeaf(EntityKind.circle, circle, q, Vector2(7300, 3250)),
          isNull);
      expect(
          reshapeLeaf(
              EntityKind.circle, circle, q, Vector2(7300 + 1e-10, 3250)),
          isNull);
    });

    test('an arc start stretch keeps the sweep direction and the end, both '
        'signs (Ruling 03-1)', () {
      final start = leafGrips(EntityKind.arc, arcPos)[1];
      final out =
          reshapeLeaf(EntityKind.arc, arcPos, start, at(arcPos, 0.1, 55))!;
      expect(out.coords, arcPos.coords);
      expect(out.scalars[0], 40);
      expect(out.scalars[1], closeTo(0.1, 1e-12));
      expect(out.scalars[2], closeTo(2.1, 1e-12));
      expectSameDirection(out.scalars[1] + out.scalars[2], 0.3 + 1.9);

      final negStart = leafGrips(EntityKind.arc, arcNeg)[1];
      final neg =
          reshapeLeaf(EntityKind.arc, arcNeg, negStart, at(arcNeg, 2.5, 18))!;
      expect(neg.scalars[1], closeTo(2.5, 1e-12));
      expect(neg.scalars[2], closeTo(-1.7, 1e-12));
      expectSameDirection(neg.scalars[1] + neg.scalars[2], 2.2 - 1.4);

      // Ruling 03-1's witness: atan2 answers in (−π, π], so the derived end
      // differs from the stored 5.0 by a whole turn — and is the same angle.
      final wide = payload([7050, 3200], [40, 4.0, 1.0]);
      final w = reshapeLeaf(EntityKind.arc, wide,
          leafGrips(EntityKind.arc, wide)[1], at(wide, 4.1, 40))!;
      expect(w.scalars[1], closeTo(4.1 - 2 * math.pi, 1e-12));
      expect(w.scalars[2], closeTo(0.9, 1e-12));
      expect((w.scalars[1] + w.scalars[2] - 5.0).abs(),
          closeTo(2 * math.pi, 1e-9));
      expectSameDirection(w.scalars[1] + w.scalars[2], 5.0);
    });

    test('an arc end stretch on a negative sweep stays negative (M-03n)', () {
      final end = leafGrips(EntityKind.arc, arcNeg)[2];
      final out = reshapeLeaf(EntityKind.arc, arcNeg, end, at(arcNeg, 0.5, 30))!;
      expect(out.scalars[1], 2.2, reason: 'the start is copied bit for bit');
      expect(out.scalars[2], closeTo(-1.7, 1e-12));
      final past =
          reshapeLeaf(EntityKind.arc, arcNeg, end, at(arcNeg, 2.9, 30))!;
      expect(past.scalars[2], closeTo(0.7 - 2 * math.pi, 1e-12),
          reason: 'past the start the other way, still clockwise');
      final pos = reshapeLeaf(EntityKind.arc, arcPos,
          leafGrips(EntityKind.arc, arcPos)[2], at(arcPos, 2.6, 40))!;
      expect(pos.scalars[1], 0.3);
      expect(pos.scalars[2], closeTo(2.3, 1e-12));
    });

    test('an arc radius grip copies the angles', () {
      final mid = leafGrips(EntityKind.arc, arcPos)[3];
      final out = reshapeLeaf(
          EntityKind.arc, arcPos, mid, Vector2(7050 + 36, 3200 + 48))!;
      expect(out.scalars, [60, 0.3, 1.9]);
      expect(out.coords, arcPos.coords);
    });

    test('an arc stretch to a zero or a full sweep is null', () {
      final grips = leafGrips(EntityKind.arc, arcPos);
      expect(
          reshapeLeaf(
              EntityKind.arc, arcPos, grips[1], at(arcPos, 0.3 + 1.9, 40)),
          isNull,
          reason: 'the start dragged onto the end');
      expect(reshapeLeaf(EntityKind.arc, arcPos, grips[2], at(arcPos, 0.3, 40)),
          isNull,
          reason: 'the end dragged onto the start');
    });

    test('a move grip is not a reshape, and a kind without grips throws', () {
      expect(
          () => reshapeLeaf(EntityKind.circle, circle,
              leafGrips(EntityKind.circle, circle)[0], Vector2(7400, 3300)),
          throwsArgumentError);
      expect(
          () => reshapeLeaf(EntityKind.text, payload([7020, 3300], [12]),
              const Grip(GripRole.stretch, 0, 7020, 3300), Vector2(7030, 3300)),
          throwsArgumentError);
    });
  });
}
```

- [ ] **Step 3: Run it to fail.** `cd packages/jet_cad_2d && CI=true dart
  test test/document/grips_test.dart` → compile error: `leafGrips`, `Grip`
  and `GripRole` are undefined.

- [ ] **Step 4: Implement.**

```dart
// lib/src/document/grips.dart
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../core/tolerance.dart';
import '../store/entity_store.dart';
import '../store/geometry_store.dart';

/// What dragging a grip does (spec D3).
enum GripRole { stretch, radius, move }

/// One grip of one leaf, in the leaf's **owner** space (spec D3).
///
/// For a root-level leaf that is root space, which is world: the canvas, the
/// index and the oracle all descend from the identity and never apply the
/// root node's own transform (spec preamble, review finding #1).
final class Grip {
  const Grip(this.role, this.index, this.x, this.y);

  final GripRole role;

  /// Vertex index; quadrant 0..3; arc end 0 (start) or 1 (end); else 0.
  /// Not unique across roles — the tie-break uses the list ordinal
  /// (Ruling 03-2).
  final int index;

  final double x, y;

  /// Exact: a grip's position is a stored coordinate, not a decision.
  @override
  bool operator ==(Object other) =>
      other is Grip &&
      other.role == role &&
      other.index == index &&
      other.x == x &&
      other.y == y;

  @override
  int get hashCode => Object.hash(role, index, x, y);

  @override
  String toString() => 'Grip(${role.name} $index @ $x, $y)';
}

/// First and last coordinate pairs equal, on three or more points — the
/// rule `triangulate.dart` closes a boundary by. A stored-value test, so `==`.
bool isClosedPolyline(GeometryPayload payload) {
  final n = payload.pointCount;
  if (n < 3) return false;
  final c = payload.coords;
  return c[0] == c[(n - 1) * 2] && c[1] == c[(n - 1) * 2 + 1];
}

/// Spec D3's grip set, in owner space. The list order is each grip's
/// ordinal, which D2's tie-break reads (Ruling 03-2).
List<Grip> leafGrips(EntityKind kind, GeometryPayload payload) {
  final c = payload.coords;
  switch (kind) {
    case EntityKind.line:
    case EntityKind.polyline:
      final n = payload.pointCount;
      // A closed polyline's last vertex *is* its first: vertex 0 stands for
      // both, so the shared corner has one grip and moves as one (D3).
      final count =
          kind == EntityKind.polyline && isClosedPolyline(payload) ? n - 1 : n;
      return [
        for (var i = 0; i < count; i++)
          Grip(GripRole.stretch, i, c[i * 2], c[i * 2 + 1]),
      ];
    case EntityKind.circle:
      if (payload.pointCount == 0 || payload.scalars.isEmpty) return const [];
      final cx = c[0], cy = c[1], r = payload.scalars[0];
      return [
        Grip(GripRole.move, 0, cx, cy),
        // The snap engine's own quadrant expression (`_considerSnapLeaf`),
        // so a radius grip sits bit for bit where a quadrant snap lands.
        for (var q = 0; q < 4; q++)
          Grip(GripRole.radius, q, cx + r * math.cos(q * (math.pi / 2)),
              cy + r * math.sin(q * (math.pi / 2))),
      ];
    case EntityKind.arc:
      if (payload.pointCount == 0 || payload.scalars.length < 3) {
        return const [];
      }
      final cx = c[0], cy = c[1];
      final r = payload.scalars[0];
      final start = payload.scalars[1];
      final sweep = payload.scalars[2];
      final end = start + sweep;
      final mid = start + sweep / 2;
      return [
        Grip(GripRole.move, 0, cx, cy),
        Grip(GripRole.stretch, 0, cx + r * math.cos(start),
            cy + r * math.sin(start)),
        Grip(GripRole.stretch, 1, cx + r * math.cos(end),
            cy + r * math.sin(end)),
        Grip(GripRole.radius, 0, cx + r * math.cos(mid),
            cy + r * math.sin(mid)),
      ];
    case EntityKind.point:
    case EntityKind.text:
    case EntityKind.attrib:
    case EntityKind.fill:
      // A point and a text move by their body; an attrib is never
      // root-level; a fill follows its boundary (D3).
      return const [];
  }
}

/// The payload [grip] dragged to [localTarget] (owner space), or null when
/// the result is degenerate — the preview then shows the object unchanged
/// and release dispatches nothing (spec D3).
///
/// Every coordinate and scalar the grip does not own is the stored double,
/// copied, never recomputed. Throws [ArgumentError] for a move grip (the
/// tool routes a centre grip to a move) and for a kind without grips.
GeometryPayload? reshapeLeaf(EntityKind kind, GeometryPayload payload,
    Grip grip, Vector2 localTarget) {
  if (grip.role == GripRole.move) {
    throw ArgumentError.value(
        grip, 'grip', 'a move grip is routed to a move, not a reshape');
  }
  final c = payload.coords;
  switch (kind) {
    case EntityKind.line:
    case EntityKind.polyline:
      final n = payload.pointCount;
      final i = grip.index;
      if (grip.role != GripRole.stretch || i < 0 || i >= n) {
        throw ArgumentError.value(grip, 'grip', 'not a vertex of this ${kind.name}');
      }
      final coords = Float64List.fromList(c);
      coords[i * 2] = localTarget.x;
      coords[i * 2 + 1] = localTarget.y;
      // The loop stays closed: the shared corner is written twice (M-03r).
      if (i == 0 && kind == EntityKind.polyline && isClosedPolyline(payload)) {
        coords[(n - 1) * 2] = localTarget.x;
        coords[(n - 1) * 2 + 1] = localTarget.y;
      }
      // Never degenerate: a zero-length segment is legal geometry. An
      // unfillable result is `SetEntityGeometryCommand`'s to drop.
      return GeometryPayload(
          coords: coords, scalars: Float64List.fromList(payload.scalars));
    case EntityKind.circle:
      if (grip.role != GripRole.radius) {
        throw ArgumentError.value(grip, 'grip', 'a circle reshapes by radius');
      }
      final r = _distance(localTarget, c[0], c[1]);
      if (r <= Tolerance.standard.linear) return null;
      final scalars = Float64List.fromList(payload.scalars)..[0] = r;
      return GeometryPayload(coords: Float64List.fromList(c), scalars: scalars);
    case EntityKind.arc:
      final s = payload.scalars;
      final scalars = Float64List.fromList(s);
      if (grip.role == GripRole.radius) {
        final r = _distance(localTarget, c[0], c[1]);
        if (r <= Tolerance.standard.linear) return null;
        scalars[0] = r;
      } else {
        if (grip.index != 0 && grip.index != 1) {
          throw ArgumentError.value(grip, 'grip', 'an arc has ends 0 and 1');
        }
        final start = s[1], sweep = s[2];
        final a = math.atan2(localTarget.y - c[1], localTarget.x - c[0]);
        final double nextStart;
        final double nextSweep;
        if (grip.index == 0) {
          // The end angle e = start + sweep stays; the sweep turns the
          // same way it did (D3).
          nextStart = a;
          nextSweep = _wrapSweep(start + sweep - a, sweep);
        } else {
          nextStart = start;
          nextSweep = _wrapSweep(a - start, sweep);
        }
        if (_degenerateSweep(nextSweep)) return null;
        scalars[1] = nextStart;
        scalars[2] = nextSweep;
      }
      return GeometryPayload(coords: Float64List.fromList(c), scalars: scalars);
    case EntityKind.point:
    case EntityKind.text:
    case EntityKind.attrib:
    case EntityKind.fill:
      throw ArgumentError.value(kind, 'kind', 'has no grips (spec D3)');
  }
}

double _distance(Vector2 p, double cx, double cy) {
  final dx = p.x - cx, dy = p.y - cy;
  return math.sqrt(dx * dx + dy * dy);
}

/// The value congruent to [raw] mod 2π that turns the way [direction] does:
/// in [0, 2π) for a positive sweep, (−2π, 0] for a negative one. The two
/// closed ends are [_degenerateSweep]'s business.
double _wrapSweep(double raw, double direction) {
  const twoPi = 2 * math.pi;
  final w = raw % twoPi; // Dart's % is Euclidean: w is in [0, 2π).
  return direction < 0 && w != 0 ? w - twoPi : w;
}

/// A decision, so `Tolerance` (spec D3, invariant 8).
bool _degenerateSweep(double sweep) {
  final a = sweep.abs();
  return a <= Tolerance.standard.angular ||
      (2 * math.pi - a) <= Tolerance.standard.angular;
}
```

Add the export to `lib/jet_cad_2d.dart`, between `extents.dart` and
`fill_index.dart`:

```dart
export 'src/document/grips.dart';
```

- [ ] **Step 5: Run it to pass.** `CI=true dart test
  test/document/grips_test.dart` → all tests pass. Then run the
  `jet_cad_2d` gate line.
- [ ] **Step 6: Commit.**

```bash
git add packages/jet_cad_2d/lib/src/document/grips.dart packages/jet_cad_2d/lib/jet_cad_2d.dart packages/jet_cad_2d/test/document/grips_test.dart
git commit -m "$(cat <<'EOF'
feat(engine): grips -- leafGrips, isClosedPolyline, reshapeLeaf

Spec 03 D3: the grip set per kind in owner space, the closed-polyline rule
(vertex 0 stands for the repeated last vertex and a stretch writes both),
and reshape with the degenerate rule. Ruling 03-1: an arc's derived end
angle is compared modulo 2 pi.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 2: `rigidTransformLeaf`, and the seeded differential

**Files:**
- Modify: `lib/src/document/grips.dart` (append)
- Test: `test/document/rigid_transform_test.dart`

**Interfaces:**
- Consumes: `Transform2` (`a…f`, `multiply`, `translation`, `rotation`,
  `transformPoint`); `GeometryPayload.transformedBy`; `scalarOr` from
  `text_scalars.dart`.
- Produces:
  - `bool isRigidTransform(Transform2 t, [Tolerance tol = Tolerance.standard])`
  - `GeometryPayload rigidTransformLeaf(EntityKind kind, GeometryPayload payload, Transform2 t)`,
    with `t` in the leaf's owner space. It throws `ArgumentError` for a
    non-rigid `t`, a fill or an attrib.

- [ ] **Step 1: Write the failing test.**

```dart
// test/document/rigid_transform_test.dart
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

GeometryPayload payload(List<double> coords, List<double> scalars) =>
    GeometryPayload(
        coords: Float64List.fromList(coords),
        scalars: Float64List.fromList(scalars));

/// translate(p) ∘ rotate(θ) ∘ translate(−p): a rotation about p.
Transform2 rotationAbout(double theta, double px, double py) =>
    Transform2.translation(px, py)
        .multiply(Transform2.rotation(theta))
        .multiply(Transform2.translation(-px, -py));

/// Every vertex, and the points a quarter, a half and three quarters along
/// every segment, of an interleaved coordinate list.
List<double> polySamples(Float64List c) {
  final out = <double>[...c];
  for (var i = 0; i + 3 < c.length; i += 2) {
    for (var k = 1; k <= 3; k++) {
      out
        ..add(c[i] + (c[i + 2] - c[i]) * k / 4)
        ..add(c[i + 1] + (c[i + 3] - c[i + 1]) * k / 4);
    }
  }
  return out;
}

void main() {
  test('a pure translation adds exactly, and every scalar is bit for bit',
      () {
    final t = Transform2.translation(123.25, -45.5);
    final cases = {
      EntityKind.point: payload([7250, 3300], []),
      EntityKind.line: payload([7010.1, 3020.3, 7130.7, 3060.9], []),
      EntityKind.polyline:
          payload([7200, 3000, 7400.5, 3000, 7400.5, 3150.25, 7200, 3000], []),
      EntityKind.circle: payload([7300.3, 3250.7], [25.5]),
      EntityKind.arc: payload([7050.1, 3200.9], [40, 0.3, 1.9]),
      EntityKind.text: payload([7020.2, 3300.4], [12, 0.2, 0.9, 0.1]),
    };
    for (final MapEntry(key: kind, value: p) in cases.entries) {
      final out = rigidTransformLeaf(kind, p, t);
      for (var i = 0; i < p.coords.length; i += 2) {
        expect(out.coords[i], p.coords[i] + 123.25, reason: '${kind.name} x');
        expect(out.coords[i + 1], p.coords[i + 1] + -45.5,
            reason: '${kind.name} y');
      }
      expect(out.scalars, p.scalars,
          reason: '${kind.name}: θ = 0 leaves every scalar unchanged');
    }
  });

  test('an arc rotates its start angle; radius and sweep are copied (M-03h)',
      () {
    final arc = payload([7050, 3200], [40, 0.3, 1.9]);
    final t = rotationAbout(0.7, 7100, 3100);
    final out = rigidTransformLeaf(EntityKind.arc, arc, t);
    final centre = t.transformPoint(Vector2(7050, 3200));
    expect(out.coords[0], closeTo(centre.x, 1e-9));
    expect(out.coords[1], closeTo(centre.y, 1e-9));
    expect(out.scalars[0], 40);
    expect(out.scalars[1], closeTo(1.0, 1e-12));
    expect(out.scalars[2], 1.9);
    final neg = rigidTransformLeaf(
        EntityKind.arc, payload([7150, 3250], [30, 2.2, -1.4]), t);
    expect(neg.scalars[1], closeTo(2.9, 1e-12));
    expect(neg.scalars[2], -1.4, reason: "a rigid transform keeps the sweep's sign");
  });

  test('a text rotates its rotation scalar; a height-only text gains one '
      '(M-03m)', () {
    final t = rotationAbout(0.7, 7100, 3100);
    final full = rigidTransformLeaf(
        EntityKind.text, payload([7020, 3300], [12, 0.2, 0.9, 0.1]), t);
    expect(full.scalars[0], 12);
    expect(full.scalars[1], closeTo(0.9, 1e-12));
    expect(full.scalars.sublist(2), [0.9, 0.1]);
    final at = t.transformPoint(Vector2(7020, 3300));
    expect(full.coords[0], closeTo(at.x, 1e-9));
    expect(full.coords[1], closeTo(at.y, 1e-9));
    final schema3 =
        rigidTransformLeaf(EntityKind.text, payload([7020, 3300], [12]), t);
    expect(schema3.scalars, hasLength(2),
        reason: 'a real edit of that entity writes scalars[1] (spec D3)');
    expect(schema3.scalars[0], 12);
    expect(schema3.scalars[1], closeTo(0.7, 1e-12));
  });

  test('a circle moves its centre and keeps its scalars bit for bit', () {
    final t = rotationAbout(-1.1, 7000, 3000);
    final out =
        rigidTransformLeaf(EntityKind.circle, payload([7300, 3250], [25.5]), t);
    final centre = t.transformPoint(Vector2(7300, 3250));
    expect(out.coords[0], closeTo(centre.x, 1e-9));
    expect(out.coords[1], closeTo(centre.y, 1e-9));
    expect(out.scalars, [25.5]);
  });

  test('non-rigid transforms, fills and attribs are refused (M-03ax)', () {
    final line = payload([7010, 3020, 7130, 3060], []);
    for (final t in [
      Transform2.scale(2, 2),
      const Transform2(1, 0, 0.5, 1, 0, 0),
      Transform2.scale(1, -1),
    ]) {
      expect(() => rigidTransformLeaf(EntityKind.line, line, t),
          throwsArgumentError,
          reason: '$t');
    }
    final t = Transform2.translation(1, 2);
    expect(() => rigidTransformLeaf(EntityKind.fill, payload([], [17]), t),
        throwsArgumentError);
    expect(
        () => rigidTransformLeaf(
            EntityKind.attrib, payload([7020, 3300], [12]), t),
        throwsArgumentError);
    expect(isRigidTransform(rotationAbout(2.1, 7e5, -3e5)), isTrue);
  });

  test(
      'differential: 200 seeded rigid transforms agree with an independent '
      'oracle (M-03h, M-03m)', () {
    const seed = 0x5EED0003;
    const trials = 200;
    const ulp52 = 2.220446049250313e-16; // 2^-52
    // Ruling 03-16: the scale is the trial range the spec names, 2e6, so a
    // sample that lands near zero is judged by the magnitude it was
    // computed from. About 1.1e-7; an angle error moves a point by r·Δθ.
    const range = 2e6;
    final random = math.Random(seed);
    double coord() => (random.nextDouble() * 2 - 1) * 1e6;
    double angle() {
      while (true) {
        final a = (random.nextDouble() * 2 - 1) * 2 * math.pi;
        final q = a / (math.pi / 2);
        if ((q - q.roundToDouble()).abs() > 1e-3) return a;
      }
    }

    final worst = <String, double>{};
    void check(String kind, double a, double b) {
      final residual = (a - b).abs();
      final allowed = math.max(
          1e-12, 256 * ulp52 * math.max(range, math.max(a.abs(), b.abs())));
      expect(residual, lessThanOrEqualTo(allowed), reason: '$kind: $a vs $b');
      worst[kind] = math.max(worst[kind] ?? 0, residual);
    }

    for (var trial = 0; trial < trials; trial++) {
      final theta = angle();
      final tx = coord(), ty = coord();
      final t =
          Transform2.translation(tx, ty).multiply(Transform2.rotation(theta));
      // The oracle, written out here: rotate, then translate. It shares no
      // code with rigidTransformLeaf.
      final c = math.cos(theta), s = math.sin(theta);
      double ox(double x, double y) => c * x - s * y + tx;
      double oy(double x, double y) => s * x + c * y + ty;

      for (final (kind, n) in [
        (EntityKind.point, 1),
        (EntityKind.line, 2),
        (EntityKind.polyline, 5),
      ]) {
        final p = payload([for (var i = 0; i < 2 * n; i++) coord()], []);
        final out = rigidTransformLeaf(kind, p, t);
        final before = polySamples(p.coords);
        final after = polySamples(out.coords);
        for (var i = 0; i < before.length; i += 2) {
          check(kind.name, ox(before[i], before[i + 1]), after[i]);
          check(kind.name, oy(before[i], before[i + 1]), after[i + 1]);
        }
      }

      {
        final cx = coord(), cy = coord(), r = 1 + random.nextDouble() * 1e4;
        final out =
            rigidTransformLeaf(EntityKind.circle, payload([cx, cy], [r]), t);
        for (var k = 0; k < 8; k++) {
          final phi = k * math.pi / 4 + 0.1;
          final x = cx + r * math.cos(phi), y = cy + r * math.sin(phi);
          // The same rim point on the moved circle sits at φ + θ.
          check('circle', ox(x, y),
              out.coords[0] + out.scalars[0] * math.cos(phi + theta));
          check('circle', oy(x, y),
              out.coords[1] + out.scalars[0] * math.sin(phi + theta));
        }
      }

      {
        final cx = coord(), cy = coord(), r = 1 + random.nextDouble() * 1e4;
        final start = (random.nextDouble() * 2 - 1) * math.pi;
        var sweep = 0.0;
        while (sweep.abs() < 1e-3) {
          sweep = (random.nextDouble() * 2 - 1) * 2 * math.pi;
        }
        final out = rigidTransformLeaf(
            EntityKind.arc, payload([cx, cy], [r, start, sweep]), t);
        for (var k = 0; k <= 8; k++) {
          // Sampled from the stored values: centre + r·(cos, sin) over the
          // sweep, on both sides.
          final phi = start + sweep * k / 8;
          final psi = out.scalars[1] + out.scalars[2] * k / 8;
          final x = cx + r * math.cos(phi), y = cy + r * math.sin(phi);
          check('arc', ox(x, y), out.coords[0] + out.scalars[0] * math.cos(psi));
          check('arc', oy(x, y), out.coords[1] + out.scalars[0] * math.sin(psi));
        }
      }

      {
        final x = coord(), y = coord(), h = 1 + random.nextDouble() * 1e3;
        final heightOnly = trial % 4 == 0;
        final rot = heightOnly ? 0.0 : (random.nextDouble() * 2 - 1) * math.pi;
        final out = rigidTransformLeaf(EntityKind.text,
            payload([x, y], heightOnly ? [h] : [h, rot, 1.0, 0.0]), t);
        // The baseline direction, from the stored rotation (a height-only
        // text reads 0).
        final bx = x + h * math.cos(rot), by = y + h * math.sin(rot);
        final rot2 = out.scalars[1];
        check('text', ox(x, y), out.coords[0]);
        check('text', oy(x, y), out.coords[1]);
        check('text', ox(bx, by), out.coords[0] + out.scalars[0] * math.cos(rot2));
        check('text', oy(bx, by), out.coords[1] + out.scalars[0] * math.sin(rot2));
      }
    }
    // Pasted into the results note (spec, Differential check).
    print('03 differential: seed 0x5EED0003, $trials trials, '
        'worst residual per kind: $worst');
    expect(worst.keys,
        containsAll(['point', 'line', 'polyline', 'circle', 'arc', 'text']));
  });
}
```

- [ ] **Step 2: Run it to fail.** `CI=true dart test
  test/document/rigid_transform_test.dart` → compile error:
  `rigidTransformLeaf` is undefined.

- [ ] **Step 3: Implement.** Append to `lib/src/document/grips.dart`, and
  add the imports `import '../geometry/transform2.dart';` and `import
  'text_scalars.dart';`:

```dart
/// `det = +1` and orthonormal columns, within [tol]. A decision, so
/// `Tolerance` (spec D3, invariant 8); the residuals are dimensionless.
bool isRigidTransform(Transform2 t, [Tolerance tol = Tolerance.standard]) =>
    tol.eq(t.a * t.d - t.b * t.c, 1) &&
    tol.eq(t.a * t.a + t.b * t.b, 1) &&
    tol.eq(t.c * t.c + t.d * t.d, 1) &&
    tol.isZero(t.a * t.c + t.b * t.d);

/// [payload] moved by the rigid [t], given in the leaf's owner space (spec
/// D3). A circle stays a circle, an arc keeps its sweep's sign, and a
/// text keeps its height.
///
/// A pure translation `(1, 0, 0, 1, dx, dy)` gives `x + dx` exactly for
/// every coordinate, and θ = 0 leaves every scalar bit for bit.
GeometryPayload rigidTransformLeaf(
    EntityKind kind, GeometryPayload payload, Transform2 t) {
  if (!isRigidTransform(t)) {
    throw ArgumentError.value(
        t, 't', 'not rigid: a move or rotate is det = +1 and orthonormal');
  }
  final theta = math.atan2(t.b, t.a);
  switch (kind) {
    case EntityKind.point:
    case EntityKind.line:
    case EntityKind.polyline:
    case EntityKind.circle:
      // `transformedBy` moves the coordinates and copies the scalars — for
      // a circle, the centre moves and the radius is copied.
      return payload.transformedBy(t);
    case EntityKind.arc:
      final moved = payload.transformedBy(t);
      final scalars = Float64List.fromList(payload.scalars);
      if (scalars.length >= 2) scalars[1] = scalars[1] + theta;
      return GeometryPayload(coords: moved.coords, scalars: scalars);
    case EntityKind.text:
      final moved = payload.transformedBy(t);
      // A schema-3 text holds only its height; writing its rotation is a
      // real edit of that entity, not padding on load (spec D3).
      final scalars = Float64List(math.max(2, payload.scalars.length))
        ..setRange(0, payload.scalars.length, payload.scalars);
      scalars[1] = scalarOr(payload, 1, 0) + theta;
      return GeometryPayload(coords: moved.coords, scalars: scalars);
    case EntityKind.attrib:
    case EntityKind.fill:
      throw ArgumentError.value(kind, 'kind',
          'a fill follows its boundary; an attrib is never root-level');
  }
}
```

- [ ] **Step 4: Run it to pass.** `CI=true dart test
  test/document/rigid_transform_test.dart` → all tests pass. Paste the
  `03 differential:` line into the ledger. Then run the `jet_cad_2d` gate
  line.
- [ ] **Step 5: Commit.**

```bash
git add packages/jet_cad_2d/lib/src/document/grips.dart packages/jet_cad_2d/test/document/rigid_transform_test.dart
git commit -m "$(cat <<'EOF'
feat(engine): rigidTransformLeaf and its seeded differential

Spec 03 D3: a rigid transform of a leaf in owner space -- an arc's start and
a text's rotation turn by theta, radius, sweep and height are copied. The
differential (seed 0x5EED0003, 200 trials) compares against an oracle that
shares no code, at the magnitude-scaled tolerance of Ruling 03-16.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

---
### Task 3: `drag_snap.dart` — object snap, then ortho, then the grid

**Files:**
- Create: `lib/src/index/drag_snap.dart`
- Modify: `lib/jet_cad_2d.dart`: add `export 'src/index/drag_snap.dart';`
  between `dirty_list.dart` and `hit.dart`.
- Test: `test/index/drag_snap_test.dart`

**Interfaces:**
- Consumes:
  - `SpatialIndex.snapInto(Vector2, double, SnapMask, SnapResult)`, with the
    default filter `QueryFilter.rendering`;
  - `SnapResult.found/kind/point`;
  - `SnapMask`, `SnapKind`;
  - `PageComponent` (`snapToGrid`, `gridStepMm`, `displayUnit`);
  - `snapToGrid(Vector2, double, PageComponent)`;
  - `GridScale.pick(DisplayUnit, double)`.
- Produces:
  - `const SnapMask kDragSnapMask = SnapMask(0x9F);`
  - `const double kSnapAperturePixels = 10.0;`
  - `final class DragPoint { final Vector2 point; SnapKind? objectKind; bool grid; void reset(); }`
  - `void resolveDragPoint({required Vector2 raw, required Vector2? orthoBase, required SpatialIndex index, required double apertureWorld, required bool objectSnap, required PageComponent? page, required double? gridStepMm, required SnapResult scratch, required DragPoint out})`
  - `double? dragGridStepMm(PageComponent? page, double pxPerWorldMm)`
    (Ruling 03-11)

- [ ] **Step 1: Write the failing test.**

```dart
// test/index/drag_snap_test.dart
import 'dart:typed_data';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

/// Copied from `snap_test.dart`'s `addEntity`, never imported from a test
/// file.
Handle addLine(DraftDocument doc, List<double> coords) {
  final handle = doc.handleSeed.next();
  doc.commands.execute(AddEntityCommand(
    record: EntityRecord(
      handle: handle,
      owner: doc.rootHandle,
      kind: EntityKind.line,
      layer: ReservedHandles.layerZero,
      linetype: ReservedHandles.byLayerLinetype,
      linetypeScale: 1.0,
      geomIndex: 0,
      color: const ByLayerColor(),
      lineweight: kByLayer,
      transparency: kByLayer,
      flags: 0,
    ),
    payload: GeometryPayload(
        coords: Float64List.fromList(coords), scalars: Float64List(0)),
  ));
  return handle;
}

/// An index over [lines], torn down with the test.
SpatialIndex indexOver(List<List<double>> lines) {
  final doc = DraftDocument.empty();
  for (final l in lines) {
    addLine(doc, l);
  }
  final index = SpatialIndex(doc);
  addTearDown(index.dispose);
  return index;
}

/// A 100 mm lattice anchored off the origin.
final PageComponent grid100 =
    PageComponent(originX: 7000, originY: 3000, gridStepMm: 100);

DragPoint resolve(SpatialIndex index, Vector2 raw,
    {Vector2? orthoBase,
    bool objectSnap = true,
    PageComponent? page,
    SnapResult? scratch}) {
  final out = DragPoint();
  resolveDragPoint(
    raw: raw,
    orthoBase: orthoBase,
    index: index,
    apertureWorld: 10,
    objectSnap: objectSnap,
    page: page,
    gridStepMm: page?.gridStepMm,
    scratch: scratch ?? SnapResult(),
    out: out,
  );
  return out;
}

void main() {
  test('kDragSnapMask is the cheap kinds plus intersection', () {
    expect(kDragSnapMask.bits, SnapMask.cheap.with_(SnapKind.intersection).bits);
  });

  test('the raw point passes through when nothing snaps', () {
    final index = indexOver([]);
    final free = resolve(index, Vector2(7043.25, 3011.5), page: null);
    expect([free.point.x, free.point.y], [7043.25, 3011.5]);
    expect(free.objectKind, isNull);
    expect(free.grid, isFalse);
    final off = resolve(index, Vector2(7043.25, 3011.5),
        page: grid100.copyWith(snapToGrid: false));
    expect([off.point.x, off.point.y], [7043.25, 3011.5],
        reason: "page.snapToGrid == false is the caller's check (04 D6)");
  });

  test('ortho pins the minor world axis to the base (M-03f)', () {
    final index = indexOver([]);
    final base = Vector2(7000.3, 3000.7);
    final x = resolve(index, Vector2(7050.2, 3010.9),
        orthoBase: base, objectSnap: false);
    expect([x.point.x, x.point.y], [7050.2, 3000.7]);
    final y = resolve(index, Vector2(7010.2, 3060.9),
        orthoBase: base, objectSnap: false);
    expect([y.point.x, y.point.y], [7000.3, 3060.9]);
  });

  test('an object snap overrides ortho, and is copied out of the scratch '
      '(invariant 7)', () {
    final index = indexOver([
      [7093, 3004, 7093, 3304],
    ]);
    final scratch = SnapResult();
    final out = resolve(index, Vector2(7094.5, 3006.0),
        orthoBase: Vector2(7500, 3500), scratch: scratch);
    expect([out.point.x, out.point.y], [7093, 3004],
        reason: 'released near an endpoint, a drag lands on it exactly');
    expect(out.objectKind, SnapKind.endpoint);
    expect(out.grid, isFalse);
    index.snapInto(Vector2(7093, 3300), 10, SnapMask.cheap, scratch);
    expect(scratch.point.y, 3304);
    expect([out.point.x, out.point.y], [7093, 3004],
        reason: 'no SnapResult.point is held past the call that filled it');
  });

  test('an object snap beats a nearer grid point (M-03g)', () {
    final index = indexOver([
      [7093, 3004, 7093, 3304],
    ]);
    // Grid (7100, 3000) is 2.2 away; the endpoint (7093, 3004) is 5.8 away.
    final out = resolve(index, Vector2(7098, 3001), page: grid100);
    expect([out.point.x, out.point.y], [7093, 3004]);
    expect(out.objectKind, SnapKind.endpoint);
    expect(out.grid, isFalse);
  });

  test('kind decides between object snaps through a drag (M-03b)', () {
    final index = indexOver([
      [7200, 3500, 7212, 3500],
    ]);
    // The midpoint (7206, 3500) is 1.5 away, the endpoint (7200, 3500) 4.5.
    final out = resolve(index, Vector2(7204.5, 3500.2));
    expect(out.objectKind, SnapKind.endpoint);
    expect([out.point.x, out.point.y], [7200, 3500]);
  });

  test('a grid snap re-pins the ortho axis afterwards (M-03q)', () {
    final index = indexOver([]);
    final base = Vector2(7003.7, 3017.3);
    final x = resolve(index, Vector2(7160.2, 3040.1),
        orthoBase: base, objectSnap: false, page: grid100);
    expect([x.point.x, x.point.y], [7200, 3017.3],
        reason: 'a shift-drag from an off-grid base stays on its line');
    expect(x.grid, isTrue);
    final y = resolve(index, Vector2(7010.2, 3160.1),
        orthoBase: base, objectSnap: false, page: grid100);
    expect([y.point.x, y.point.y], [7003.7, 3200]);
  });

  test('object snap off never snaps to an object: the grid wins (M-03x)', () {
    final index = indexOver([
      [7093, 3004, 7093, 3304],
    ]);
    final out =
        resolve(index, Vector2(7096, 3006), objectSnap: false, page: grid100);
    expect([out.point.x, out.point.y], [7100, 3000]);
    expect(out.objectKind, isNull);
    expect(out.grid, isTrue);
  });

  test('dragGridStepMm: the page step exactly, else the adaptive minor '
      '(M-03aw)', () {
    expect(dragGridStepMm(null, 0.5), isNull);
    expect(dragGridStepMm(grid100.copyWith(gridStepMm: 250), 0.5), 250,
        reason: 'a fixed step is used exactly at every zoom (04 D6)');
    expect(dragGridStepMm(grid100.copyWith(gridStepMm: 250), 7.0), 250);
    // Adaptive, metric, 0.5 px/mm: the first rung with a 64 px major is
    // 200 mm, divisor 4, so the minor is 50 mm (25 px, above 8).
    expect(dragGridStepMm(PageComponent(originX: 7000, originY: 3000), 0.5),
        50);
  });
}
```

- [ ] **Step 2: Run it to fail.** `CI=true dart test
  test/index/drag_snap_test.dart` → compile error: `resolveDragPoint` and
  `DragPoint` are undefined.

- [ ] **Step 3: Implement.**

```dart
// lib/src/index/drag_snap.dart
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../document/page_component.dart';
import '../geometry/grid_scale.dart';
import 'snap.dart';
import 'spatial_index.dart';

/// The kinds live during a drag (spec D8): the cheap five plus
/// intersection.
const SnapMask kDragSnapMask = SnapMask(0x9F); // cheap | intersection

/// The object-snap aperture in screen pixels; a caller divides by the
/// camera's scale.
const double kSnapAperturePixels = 10.0;

/// A drag's resolved point. Caller-owned and reused, never held (spec D8).
final class DragPoint {
  final Vector2 point = Vector2.zero();

  /// Non-null: an object snap won.
  SnapKind? objectKind;

  /// The grid won.
  bool grid = false;

  void reset() {
    point.setZero();
    objectKind = null;
    grid = false;
  }
}

/// Spec D8's chain: ortho in world axes, then an object snap that overrides
/// it, then the grid with the ortho axis re-pinned, else the constrained
/// point.
///
/// Object snap always beats the grid, whatever the two distances (04 D6).
/// Between object-snap kinds, the engine's kind-first order decides.
void resolveDragPoint({
  required Vector2 raw,
  required Vector2? orthoBase,
  required SpatialIndex index,
  required double apertureWorld,
  required bool objectSnap,
  required PageComponent? page,
  required double? gridStepMm,
  required SnapResult scratch,
  required DragPoint out,
}) {
  out.objectKind = null;
  out.grid = false;

  // 1. Ortho, in world axes: the minor axis is pinned to the base. Under a
  //    rotated camera this looks diagonal on screen, deliberately.
  var cx = raw.x, cy = raw.y;
  var pinX = false, pinY = false;
  final base = orthoBase;
  if (base != null) {
    if ((raw.x - base.x).abs() >= (raw.y - base.y).abs()) {
      cy = base.y;
      pinY = true;
    } else {
      cx = base.x;
      pinX = true;
    }
  }

  // 2. Object snap, queried at the pointer: the marker the user aims at is
  //    under it. It wins outright and overrides ortho. Copied at once,
  //    because the next query rewrites `scratch.point` (invariant 7).
  if (objectSnap) {
    index.snapInto(raw, apertureWorld, kDragSnapMask, scratch);
    if (scratch.found) {
      out.point.setFrom(scratch.point);
      out.objectKind = scratch.kind;
      return;
    }
  }

  // 3. The grid, then the ortho axis written back from the base, so a
  //    shift-drag from an off-grid base stays exactly on its line (M-03q).
  if (page != null && page.snapToGrid && gridStepMm != null) {
    out.point.setValues(cx, cy);
    out.point.setFrom(snapToGrid(out.point, gridStepMm, page));
    if (pinY) out.point.y = base!.y;
    if (pinX) out.point.x = base!.x;
    out.grid = true;
    return;
  }

  // 4. Otherwise, the constrained point.
  out.point.setValues(cx, cy);
}

/// The drag's grid step (04 D6, Ruling 03-11): the page's fixed step
/// exactly, else the zoom-adaptive minor, else the major; null with no page
/// or no rung.
double? dragGridStepMm(PageComponent? page, double pxPerWorldMm) {
  if (page == null) return null;
  final fixed = page.gridStepMm;
  if (fixed != null) return fixed;
  final scale = GridScale.pick(page.displayUnit, pxPerWorldMm);
  if (scale == null) return null;
  return scale.minorMm ?? scale.majorMm;
}
```

Add the export to `lib/jet_cad_2d.dart`, between `dirty_list.dart` and
`hit.dart`:

```dart
export 'src/index/drag_snap.dart';
```

- [ ] **Step 4: Run it to pass.** `CI=true dart test
  test/index/drag_snap_test.dart` → all tests pass. Run the `jet_cad_2d`
  gate line. Then run the `jet_cad_2d_flutter` gate line, because the barrel
  grew and a name clash would show there.
- [ ] **Step 5: Commit.**

```bash
git add packages/jet_cad_2d/lib/src/index/drag_snap.dart packages/jet_cad_2d/lib/jet_cad_2d.dart packages/jet_cad_2d/test/index/drag_snap_test.dart
git commit -m "$(cat <<'EOF'
feat(engine): resolveDragPoint -- object snap, ortho, then the grid

Spec 03 D8: ortho in world axes, an object snap that overrides it and always
beats the grid, the grid with the ortho axis re-pinned afterwards, and
dragGridStepMm for the page's fixed or adaptive step (Ruling 03-11).

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 4: `OutlineCache.worldBoundsOf`, the style constants, `GripCache`

**Files:**
- Modify: `lib/src/outline_cache.dart` (add `worldBoundsOf` after `worldPointOf`)
- Modify: `lib/src/selection_style.dart` (append the constants)
- Create: `lib/src/grip_cache.dart`
- Modify: `lib/jet_cad_2d_flutter.dart`: add `export
  'src/grip_cache.dart';` after the `src/gpu/...` exports and before
  `src/interaction_layer.dart`.
- Create: `test/support/grip_fixture.dart` (first version)
- Test: `test/outline_cache_test.dart` (O1), `test/grip_cache_test.dart` (C1–C7)

**Interfaces:**
- Consumes: `Grip`, `GripRole` and `leafGrips` (Task 1); `arcBounds`,
  `Aabb2`, `Transform2`, `Capability` and `DraftPermissions` (engine);
  `SelectionController`; `OutlineCache`.
- Produces:
  - `Aabb2? OutlineCache.worldBoundsOf(SelectionKey key)`
  - in `selection_style.dart`: `kGripPixels`, `kGripColor`,
    `kGripMoveColor`, `kGripHotColor`, `kRotationGripPixels`,
    `kRotationGripOffset`, `kPreviewColor`, `kPreviewStrokePixels`,
    `kSnapMarkerColor`, `kSnapMarkerPixels`, `kSnapMarkerStrokePixels`,
    `kGridMarkerPixels`
  - in `grip_cache.dart`:
    - `const int kMaxGrips = 400;`
    - `const double kGripHitPixels = 7.0;`
    - `final class GripRef { const GripRef(SelectionKey key, Grip grip, int ordinal); }`
    - `({Offset anchor, Offset centre}) rotationGripOf(Aabb2 box, Transform2 worldToScreen)`
  - `class GripCache extends ChangeNotifier`:
    - `GripCache(DraftDocument document, SelectionController selection, OutlineCache outlines)`
    - `List<GripRef> get grips` (an unmodifiable view, the same object every
      call)
    - `int get moveCount`
    - `int get stretchCount`
    - `Aabb2? get box`
    - `bool get rotatable`
    - `int hot` (writable; `-1` for none)
    - `bool get leafGripsLive`
    - `int hitTest(Offset screen, Transform2 worldToScreen)`
    - `bool hitsRotationGrip(Offset screen, Transform2 worldToScreen)`
  - in `test/support/grip_fixture.dart`: `GripScene`,
    `GripScene gripScene({TextMeasurer measurer, PageComponent? page})`,
    `CameraController gripCamera({Vector2? centre, Size viewport, double scale, double rotation})`,
    `Offset screenOf(CameraController, double x, double y)`,
    `GeometryPayload payloadOf(DraftDocument, Handle)`,
    `String snapshot(DraftDocument)`

- [ ] **Step 1: Write the fixture.**

```dart
// test/support/grip_fixture.dart
import 'dart:ui' show Offset, Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/src/camera_controller.dart';
import 'package:jet_cad_2d_flutter/src/viewport_transform.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'selection_fixture.dart';

/// The spec's standard 03 fixture (Testing).
///
/// - Everything sits at x ≈ 7000–7550, y ≈ 3000–3330, so the rebase origin
///   is non-zero.
/// - A closed room.
/// - Arcs with a non-zero start, one of them with a negative sweep.
/// - A group whose own transform is a rotation.
/// - Two instances of one definition.
/// - The root stays the identity.
final class GripScene {
  GripScene._(this.document);

  final DraftDocument document;
  late final Handle line, polyline, room, circle, arcPos, arcNeg, point;
  late final Handle group, groupLeaf, def, defLeaf, instA, instB;
}

GripScene gripScene(
    {TextMeasurer measurer = const InsertionPointMeasurer(),
    PageComponent? page}) {
  final doc = DraftDocument.empty(measurer: measurer);
  final s = GripScene._(doc);
  final root = doc.rootHandle;
  s.line = addEntity(doc, root, EntityKind.line, [7010, 3020, 7130, 3060], []);
  s.polyline = addEntity(doc, root, EntityKind.polyline,
      [7010, 3100, 7040, 3130, 7070, 3100, 7100, 3130, 7130, 3100], []);
  s.room = addEntity(doc, root, EntityKind.polyline,
      [7200, 3000, 7400, 3000, 7400, 3150, 7200, 3150, 7200, 3000], []);
  s.circle = addEntity(doc, root, EntityKind.circle, [7300, 3250], [25]);
  s.arcPos = addEntity(doc, root, EntityKind.arc, [7050, 3200], [40, 0.3, 1.9]);
  s.arcNeg =
      addEntity(doc, root, EntityKind.arc, [7150, 3250], [30, 2.2, -1.4]);
  s.point = addEntity(doc, root, EntityKind.point, [7250, 3300], []);
  s.group = addGroup(doc, root,
      Transform2.translation(7400, 3300).multiply(Transform2.rotation(0.6)));
  s.groupLeaf = addEntity(doc, s.group, EntityKind.line, [0, 0, 40, 0], []);
  s.def = addDefinition(doc, 'Table');
  s.defLeaf = addEntity(doc, s.def, EntityKind.line, [0, 0, 30, 10], []);
  s.instA = addInstance(doc, s.def,
      Transform2.translation(7450, 3050).multiply(Transform2.rotation(0.3)));
  s.instB = addInstance(doc, s.def,
      Transform2.translation(7500, 3200).multiply(Transform2.rotation(-0.5)));
  if (page != null) {
    PageComponent.register(doc.components);
    doc.commands.execute(SetComponentCommand<PageComponent>(root, page));
  }
  // `undoDepth` counts the drag under test only.
  doc.commands.clearHistory();
  expect(doc.tree[root]!.transform.isIdentity, isTrue,
      reason: 'spec, Testing: the root stays the identity');
  return s;
}

/// Zoomed (scale ≠ 1), rotated (not 0°, not 90°), y flipped, and panned so
/// [centre] sits in the middle of [viewport].
CameraController gripCamera(
    {Vector2? centre,
    Size viewport = const Size(800, 600),
    double scale = 1.1,
    double rotation = 0.35}) {
  final c = centre ?? Vector2(7270, 3161);
  final linear =
      Transform2.rotation(rotation).multiply(Transform2.scale(scale, -scale));
  final mid = linear.transformPoint(c);
  return CameraController(ViewportTransform(
      worldToScreenMatrix: Transform2.translation(
              viewport.width / 2 - mid.x, viewport.height / 2 - mid.y)
          .multiply(linear)));
}

/// World (x, y) on screen under [camera].
Offset screenOf(CameraController camera, double x, double y) {
  final s = camera.value.worldToScreen(Vector2(x, y));
  return Offset(s.x, s.y);
}

/// The stored payload of [h], as a `read` copy.
GeometryPayload payloadOf(DraftDocument doc, Handle h) =>
    doc.geometry.read(doc.entities.geomIndexAt(doc.entities.slotOf(h)!));

/// The codec's output: equal strings are a byte-identical document
/// (invariant 2).
String snapshot(DraftDocument doc) => DraftDocumentCodec.encodeToString(doc);
```

- [ ] **Step 2: Write the failing tests.** Append O1 to
  `test/outline_cache_test.dart`, inside `main()`:

```dart
  test('worldBoundsOf: an arc by arcBounds, a point by its position '
      '(M-03ah)', () {
    final doc = DraftDocument.empty();
    // Start 2.9, sweep −1.6: clockwise to 1.3, through the top extreme
    // (π/2) and no other.
    final arc = addEntity(
        doc, doc.rootHandle, EntityKind.arc, [7050, 3200], [40, 2.9, -1.6]);
    final dot =
        addEntity(doc, doc.rootHandle, EntityKind.point, [7250, 3300], []);
    final line = addEntity(
        doc, doc.rootHandle, EntityKind.line, [7010, 3020, 7130, 3060], []);
    final (selection, cache) = wire(doc);
    selection.replace([
      SelectionKey.root(arc),
      SelectionKey.root(dot),
      SelectionKey.root(line),
    ]);

    final a = cache.worldBoundsOf(SelectionKey.root(arc))!;
    expect(a.minX, closeTo(7050 + 40 * math.cos(2.9), 1e-9));
    expect(a.maxX, closeTo(7050 + 40 * math.cos(2.9 - 1.6), 1e-9));
    expect(a.minY, closeTo(3200 + 40 * math.sin(2.9), 1e-9));
    expect(a.maxY, closeTo(3240, 1e-9),
        reason: 'the top extreme is inside the sweep; a control-point box '
            'or a full circle would say otherwise');
    final p = cache.worldBoundsOf(SelectionKey.root(dot))!;
    expect([p.minX, p.minY, p.maxX, p.maxY], [7250, 3300, 7250, 3300],
        reason: 'a point is its position, never Rect.zero');
    expect(cache.worldBoundsOf(SelectionKey.root(line))!.maxY, 3060);
    expect(cache.worldBoundsOf(SelectionKey.root(const Handle(999999))),
        isNull);
  });
```

Create `test/grip_cache_test.dart`:

```dart
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Offset;

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/src/grip_cache.dart';
import 'package:jet_cad_2d_flutter/src/outline_cache.dart';
import 'package:jet_cad_2d_flutter/src/selection.dart';
import 'package:jet_cad_2d_flutter/src/selection_style.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'support/grip_fixture.dart';
import 'support/selection_fixture.dart';

/// Selection, outlines and grips over [doc], built in the shell's order
/// (spec D6) and torn down with the test.
(SelectionController, OutlineCache, GripCache) wire(DraftDocument doc) {
  final selection = SelectionController(doc);
  final outlines = OutlineCache(doc, selection);
  final grips = GripCache(doc, selection, outlines);
  addTearDown(() {
    grips.dispose();
    outlines.dispose();
    selection.dispose();
  });
  return (selection, outlines, grips);
}

SelectionKey k(Handle h) => SelectionKey.root(h);

void main() {
  test('grips of the selected root leaves, in world, in ascending handle '
      'order (M-03y)', () {
    final s = gripScene();
    final doc = s.document;
    final (selection, _, grips) = wire(doc);
    selection.replace([
      k(s.instA),
      k(s.arcNeg),
      k(s.group),
      k(s.room),
      k(s.circle),
      k(s.line),
    ]);
    final expected = <(Handle, Grip)>[
      for (final h in [s.line, s.room, s.circle, s.arcNeg])
        for (final g in leafGrips(
            doc.entities.kindAt(doc.entities.slotOf(h)!), payloadOf(doc, h)))
          (h, g),
    ];
    expect([for (final r in grips.grips) (r.key.target, r.grip)], expected);
    expect(grips.grips, hasLength(2 + 4 + 5 + 4),
        reason: 'a group and an instance have no grips (spec D3)');
    expect([for (final r in grips.grips) r.ordinal].take(6), [0, 1, 0, 1, 2, 3]);
    expect(grips.moveCount, 2, reason: "the circle's and the arc's centres");
    expect(grips.stretchCount, 13);
  });

  test('the selection box is the union of worldBoundsOf; fills alone have '
      'none (M-03ah)', () {
    final s = gripScene();
    final doc = s.document;
    final region = AddRegionCommand.allocate(
      seed: doc.handleSeed,
      owner: doc.rootHandle,
      boundaryKind: EntityKind.polyline,
      boundaryPayload: GeometryPayload(
          coords: Float64List.fromList(
              [7600, 3000, 7700, 3000, 7700, 3100, 7600, 3000]),
          scalars: Float64List(0)),
      layer: ReservedHandles.layerZero,
      fillColor: const TrueColor(0x8844AA),
      boundaryColor: const ByLayerColor(),
    );
    doc.commands.execute(region);
    final (selection, outlines, grips) = wire(doc);
    selection.replace([k(s.arcNeg), k(s.point)]);
    final arc = outlines.worldBoundsOf(k(s.arcNeg))!;
    final box = grips.box!;
    expect(box.minX, arc.minX);
    expect(box.minY, arc.minY);
    expect(box.maxX, 7250, reason: 'the point counts by its position');
    expect(box.maxY, 3300);
    expect(grips.rotatable, isTrue);
    selection.replace([k(region.fill.handle)]);
    expect(grips.box, isNull);
    expect(grips.rotatable, isFalse,
        reason: 'a fill has no outline of its own (spec D4, Ruling 03-15)');
    expect(grips.grips, isEmpty);
  });

  test('a DocChange rebuilds the grips after the outline cache (M-03al)',
      () async {
    final s = gripScene();
    final doc = s.document;
    final (selection, _, grips) = wire(doc);
    selection.replace([k(s.line)]);
    expect(grips.grips[1].grip.x, 7130);
    var notified = 0;
    grips.addListener(() => notified++);
    doc.commands.execute(SetEntityGeometryCommand(
        s.line,
        GeometryPayload(
            coords: Float64List.fromList([7010, 3020, 7160, 3090]),
            scalars: Float64List(0))));
    await Future<void>.delayed(Duration.zero);
    expect(grips.grips[1].grip.x, 7160);
    expect(grips.box!.maxY, 3090);
    expect(notified, greaterThan(0));
  });

  test('the cap: kMaxGrips grips are kept, kMaxGrips + 1 keep none (M-03z)',
      () {
    final doc = DraftDocument.empty();
    List<double> zigzag(int n) => [
          for (var i = 0; i < n; i++) ...[7000.0 + i, i.isEven ? 3000.0 : 3005.0],
        ];
    final atCap =
        addEntity(doc, doc.rootHandle, EntityKind.polyline, zigzag(kMaxGrips), []);
    final overCap = addEntity(
        doc, doc.rootHandle, EntityKind.polyline, zigzag(kMaxGrips + 1), []);
    final (selection, _, grips) = wire(doc);
    selection.replace([k(atCap)]);
    expect(grips.grips, hasLength(kMaxGrips));
    selection.replace([k(overCap)]);
    expect(grips.grips, isEmpty);
    expect(grips.box, isNotNull,
        reason: 'body move and rotate still work over the cap (spec D6)');
  });

  test('leaf grips are not live under a geometry denial (M-03ad)', () {
    final s = gripScene();
    final doc = s.document;
    final (selection, _, grips) = wire(doc);
    selection.replace([k(s.line), k(s.instA)]);
    final camera = gripCamera();
    addTearDown(camera.dispose);
    final m = camera.value.worldToScreenMatrix;
    final vertex = screenOf(camera, 7130, 3060);
    expect(grips.leafGripsLive, isTrue);
    expect(grips.hitTest(vertex, m), 1);
    doc.commands.permissions = DraftPermissions.runtime;
    expect(grips.leafGripsLive, isFalse);
    expect(grips.hitTest(vertex, m), -1);
    expect(grips.rotatable, isTrue,
        reason: 'the rotation grip is not a leaf grip (Ruling 03-6)');
  });

  test('hitTest: the nearest, then the greater handle, then the lower '
      'ordinal (M-03ai)', () {
    final doc = DraftDocument.empty();
    final wallA = addEntity(
        doc, doc.rootHandle, EntityKind.line, [7600, 3400, 7650, 3400], []);
    final wallB = addEntity(
        doc, doc.rootHandle, EntityKind.line, [7650, 3400, 7650, 3450], []);
    final twin = addEntity(doc, doc.rootHandle, EntityKind.polyline,
        [7800, 3400, 7800, 3400, 7850, 3420], []);
    final (selection, _, grips) = wire(doc);
    selection.replace([k(wallA), k(wallB), k(twin)]);
    final camera = gripCamera(centre: Vector2(7700, 3420));
    addTearDown(camera.dispose);
    final m = camera.value.worldToScreenMatrix;

    final corner =
        grips.hitTest(screenOf(camera, 7650, 3400) + const Offset(2, 1), m);
    expect(grips.grips[corner].key.target, wallB,
        reason: 'coincident grips of two objects: the greater handle moves');
    expect(grips.grips[corner].ordinal, 0);
    final dup = grips.hitTest(screenOf(camera, 7800, 3400), m);
    expect(grips.grips[dup].key.target, twin);
    expect(grips.grips[dup].ordinal, 0,
        reason: "one object's coincident grips: the lower ordinal");
    final near =
        grips.hitTest(screenOf(camera, 7600, 3400) + const Offset(5, 0), m);
    expect(grips.grips[near].key.target, wallA);
    expect(grips.hitTest(screenOf(camera, 7600, 3400) + const Offset(8, 0), m),
        -1,
        reason: 'kGripHitPixels is 7');
  });

  test('the rotation grip hangs 24 px above the screen box, screen-up '
      '(M-03ak)', () {
    final camera = gripCamera();
    addTearDown(camera.dispose);
    final m = camera.value.worldToScreenMatrix;
    expect(m.b, isNot(closeTo(0, 1e-3)),
        reason: 'rotated, so the screen box is not the projected world box');
    const box = Aabb2.raw(7010, 3020, 7130, 3060);
    final corners = [
      for (final (x, y) in const [
        (7010.0, 3020.0),
        (7130.0, 3020.0),
        (7010.0, 3060.0),
        (7130.0, 3060.0),
      ])
        screenOf(camera, x, y),
    ];
    final minX = corners.map((c) => c.dx).reduce(math.min);
    final maxX = corners.map((c) => c.dx).reduce(math.max);
    final minY = corners.map((c) => c.dy).reduce(math.min);
    final g = rotationGripOf(box, m);
    expect(g.anchor.dx, closeTo((minX + maxX) / 2, 1e-9));
    expect(g.anchor.dy, closeTo(minY, 1e-9));
    expect(g.centre.dx, closeTo(g.anchor.dx, 1e-12));
    expect(g.centre.dy, closeTo(minY - kRotationGripOffset, 1e-9));
  });
}
```

- [ ] **Step 3: Run them to fail.** `cd packages/jet_cad_2d_flutter &&
  CI=true flutter test test/outline_cache_test.dart
  test/grip_cache_test.dart` → compile errors: `worldBoundsOf`,
  `GripCache`, `rotationGripOf` and `kRotationGripOffset` are undefined.

- [ ] **Step 4: Implement.** In `lib/src/outline_cache.dart`, after
  `worldPointOf`:

```dart
  /// The world AABB of [key]'s outline, in doubles (spec D6); null when
  /// [key] is not cached or its outline is empty (a fill, a hidden leaf).
  ///
  /// Computed from the world records, **never** from a `ui.Path`. The
  /// reason: `Path.getBounds` answers an arc's control-point bounds (see
  /// [debugWorldArcsOf]) and `Rect.zero` for a lone point, and a path is
  /// float32, rebased by whatever origin it was last built at (review
  /// finding #3).
  Aabb2? worldBoundsOf(SelectionKey key) {
    final outlines = _world[key];
    if (outlines == null) return null;
    var box = Aabb2.empty();
    for (final outline in outlines) {
      switch (outline) {
        case _Segments(:final coords):
          for (var i = 0; i + 1 < coords.length; i += 2) {
            box = box.expandedToPoint(Vector2(coords[i], coords[i + 1]));
          }
        case _Arc(:final cx, :final cy, :final r, :final start, :final sweep):
          box = box.union(arcBounds(Vector2(cx, cy), r, start, sweep));
        case _Point(:final x, :final y):
          box = box.expandedToPoint(Vector2(x, y));
      }
    }
    return box.isEmpty ? null : box;
  }
```

Append to `lib/src/selection_style.dart`:

```dart
/// Grip squares (spec D6): side in screen pixels, drawn by `drawRawPoints`
/// with a square cap at this stroke width.
const double kGripPixels = 8.0;

/// Stretch and radius grips.
const Color kGripColor = Color(0xFF1E6FE8);

/// Move (centre) grips.
const Color kGripMoveColor = Color(0xFF7A3FD1);

/// The hovered grip, and the grabbed one during a drag.
const Color kGripHotColor = Color(0xFFE8541E);

/// The rotation grip: a disc of this diameter, [kRotationGripOffset] screen
/// pixels above the top-centre of the selection's screen box (spec D6).
const double kRotationGripPixels = 8.0;
const double kRotationGripOffset = 24.0;

/// The drag preview and its guide line (spec D7).
const Color kPreviewColor = Color(0xFFE8A11E);
const double kPreviewStrokePixels = 1.5;

/// Snap markers (spec D9).
const Color kSnapMarkerColor = Color(0xFF2E9E5B);
const double kSnapMarkerPixels = 10.0;
const double kSnapMarkerStrokePixels = 1.5;
const double kGridMarkerPixels = 6.0;
```

Create `lib/src/grip_cache.dart`:

```dart
import 'dart:collection';
import 'dart:math' as math;
import 'dart:ui' show Offset;

import 'package:flutter/foundation.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';

import 'outline_cache.dart';
import 'selection.dart';
import 'selection_style.dart';

/// Past this many grips in the selection, no leaf grip is shown (spec D6).
/// Body move and rotate still work.
const int kMaxGrips = 400;

/// A press or hover within this many screen pixels of a grip's centre hits
/// it (spec D2).
const double kGripHitPixels = 7.0;

/// One grip of one selected root leaf. For a root leaf, owner space is
/// world, so [grip]'s coordinates are world.
final class GripRef {
  const GripRef(this.key, this.grip, this.ordinal);

  final SelectionKey key;
  final Grip grip;

  /// The grip's position in `leafGrips`' list — D2's tie-break "grip index"
  /// (Ruling 03-2).
  final int ordinal;
}

/// Where the rotation grip sits (spec D6): the centre of the screen-space
/// bounding box of [box]'s four projected corners, [kRotationGripOffset]
/// pixels up. Under a rotated camera, "up" means screen-up. [anchor] is the
/// top-centre the grip hangs from.
({Offset anchor, Offset centre}) rotationGripOf(
    Aabb2 box, Transform2 worldToScreen) {
  final m = worldToScreen;
  var minX = double.infinity, maxX = double.negativeInfinity;
  var minY = double.infinity;
  for (var i = 0; i < 4; i++) {
    final x = i.isEven ? box.minX : box.maxX;
    final y = i < 2 ? box.minY : box.maxY;
    final sx = m.a * x + m.c * y + m.e;
    final sy = m.b * x + m.d * y + m.f;
    minX = math.min(minX, sx);
    maxX = math.max(maxX, sx);
    minY = math.min(minY, sy);
  }
  final cx = (minX + maxX) / 2;
  return (
    anchor: Offset(cx, minY),
    centre: Offset(cx, minY - kRotationGripOffset),
  );
}

/// The selection's grips and box, in world doubles (spec D6).
///
/// Rebuilt at selection-change and document-change rate, never per frame.
/// It listens to the selection controller and to the [OutlineCache], never
/// to `document.changes` (Ruling 03-19). The box is derived from the
/// outline cache's world records, so it must rebuild after them. The shell
/// constructs this after the outline cache, so on a selection change the
/// cache's listener has already run.
class GripCache extends ChangeNotifier {
  GripCache(this.document, this.selection, this.outlines) {
    selection.addListener(_onSelection);
    outlines.addListener(_rebuild);
    _rebuild();
  }

  final DraftDocument document;
  final SelectionController selection;
  final OutlineCache outlines;

  final List<GripRef> _grips = <GripRef>[];

  /// Every shown grip, in ascending handle order, then by ordinal. The same
  /// view object on every call, so a painter reading it per frame
  /// allocates nothing.
  late final List<GripRef> grips = UnmodifiableListView<GripRef>(_grips);

  Set<SelectionKey> _built = const {};
  int _moveCount = 0;
  Aabb2? _box;

  /// How many of [grips] are move (centre) grips.
  int get moveCount => _moveCount;

  /// How many are stretch or radius grips.
  int get stretchCount => _grips.length - _moveCount;

  /// The union of `worldBoundsOf` over the selection; null when nothing
  /// selected has an outline.
  Aabb2? get box => _box;

  /// A rotation grip is drawn and hit (spec D6). A fill has no outline of
  /// its own, so a non-null box already means a non-fill key
  /// (Ruling 03-15).
  bool get rotatable => _box != null;

  /// Index into [grips] of the hovered or grabbed grip, or -1.
  ///
  /// Written by the select tool, which notifies for the repaint itself.
  /// Reset on every rebuild.
  int hot = -1;

  /// Leaf grips need `geometry` (spec D2). Read live, never cached: a
  /// permission change is not notified (Ruling 03-5).
  bool get leafGripsLive =>
      document.commands.permissions.allows(Capability.geometry);

  /// The grip under [screen] within [kGripHitPixels], or -1.
  ///
  /// The nearest wins, then the greater handle (coincident grips of two
  /// objects: the later-drawn one moves), then the lower ordinal. Nothing
  /// hits while leaf grips are not live.
  int hitTest(Offset screen, Transform2 worldToScreen) {
    if (!leafGripsLive) return -1;
    final m = worldToScreen;
    var best = -1;
    var bestDistance = double.infinity;
    var bestHandle = -1;
    var bestOrdinal = 0;
    for (var i = 0; i < _grips.length; i++) {
      final ref = _grips[i];
      final g = ref.grip;
      final dx = m.a * g.x + m.c * g.y + m.e - screen.dx;
      final dy = m.b * g.x + m.d * g.y + m.f - screen.dy;
      final d = math.sqrt(dx * dx + dy * dy);
      if (d > kGripHitPixels) continue;
      final h = ref.key.target.value;
      final better = best < 0 ||
          d < bestDistance ||
          (d == bestDistance &&
              (h > bestHandle ||
                  (h == bestHandle && ref.ordinal < bestOrdinal)));
      if (!better) continue;
      best = i;
      bestDistance = d;
      bestHandle = h;
      bestOrdinal = ref.ordinal;
    }
    return best;
  }

  /// Whether [screen] is within [kGripHitPixels] of the rotation grip.
  bool hitsRotationGrip(Offset screen, Transform2 worldToScreen) {
    final b = _box;
    if (b == null) return false;
    return (rotationGripOf(b, worldToScreen).centre - screen).distance <=
        kGripHitPixels;
  }

  /// A hover change notifies the selection controller with the same keys.
  /// Rebuilding for it would reset [hot] under the pointer, so it is skipped
  /// (Ruling 03-19).
  void _onSelection() {
    if (setEquals(_built, selection.keys.toSet())) return;
    _rebuild();
  }

  void _rebuild() {
    _grips.clear();
    _moveCount = 0;
    hot = -1;
    var box = Aabb2.empty();
    final keys = selection.keys.toList()
      ..sort((a, b) => a.target.value.compareTo(b.target.value));
    for (final key in keys) {
      final bounds = outlines.worldBoundsOf(key);
      if (bounds != null) box = box.union(bounds);
      final slot = document.entities.slotOf(key.target);
      if (slot == null) continue; // a group or an instance: no grips (D3)
      if (document.entities.ownerAt(slot) != document.rootHandle) continue;
      final list = leafGrips(document.entities.kindAt(slot),
          document.geometry.peek(document.entities.geomIndexAt(slot)));
      for (var i = 0; i < list.length; i++) {
        _grips.add(GripRef(key, list[i], i));
        if (list[i].role == GripRole.move) _moveCount++;
      }
    }
    if (_grips.length > kMaxGrips) {
      _grips.clear();
      _moveCount = 0;
    }
    _box = box.isEmpty ? null : box;
    _built = selection.keys.toSet();
    notifyListeners();
  }

  @override
  void dispose() {
    selection.removeListener(_onSelection);
    outlines.removeListener(_rebuild);
    super.dispose();
  }
}
```

Add the export to `lib/jet_cad_2d_flutter.dart`, after the last
`src/gpu/...` export:

```dart
export 'src/grip_cache.dart';
```

- [ ] **Step 5: Run them to pass.** `CI=true flutter test
  test/outline_cache_test.dart test/grip_cache_test.dart` → all tests
  pass. Then run the `jet_cad_2d_flutter` gate line: only the five goldens
  fail.
- [ ] **Step 6: Commit.**

```bash
git add packages/jet_cad_2d_flutter/lib/src/outline_cache.dart packages/jet_cad_2d_flutter/lib/src/selection_style.dart packages/jet_cad_2d_flutter/lib/src/grip_cache.dart packages/jet_cad_2d_flutter/lib/jet_cad_2d_flutter.dart packages/jet_cad_2d_flutter/test/support/grip_fixture.dart packages/jet_cad_2d_flutter/test/outline_cache_test.dart packages/jet_cad_2d_flutter/test/grip_cache_test.dart
git commit -m "$(cat <<'EOF'
feat(render): worldBoundsOf and GripCache -- grips, box, cap, hit test

Spec 03 D6: the selection box in world doubles from the outline records
(arcs by arcBounds, points by position, never Path.getBounds), the world grips
of every selected root leaf, the kMaxGrips cap, D2's hit order, and the
rotation grip hung screen-up from the screen box.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 5: `Tool` and `ToolContext` additions, `SnapSettings`, the cursor rebuild

**Files:**
- Modify: `lib/src/tool.dart`
- Create: `lib/src/snap_settings.dart`
- Modify: `lib/src/interaction_layer.dart` (the `build` method)
- Modify: `lib/jet_cad_2d_flutter.dart`: add `export
  'src/snap_settings.dart';` after `src/selection_style.dart`.
- Test: `test/interaction_cursor_test.dart` (I1)

**Interfaces:**
- Consumes: `GripCache` (Task 4); `PageNotifier`.
- Produces:
  - `ToolContext({required document, required index, required camera, required selection, PageNotifier? page, SnapSettings? snap, GripCache? grips})`
    with fields `page`, `snap` and `grips`. Every 02 call site still
    compiles.
  - `Tool.cursor` → `MouseCursor`, default `MouseCursor.defer`.
  - `Tool.selectionPreviewTransform` → `Transform2?`, default null.
  - `void Tool.paintWorldOverlay(Canvas canvas, Vector2 origin, double scale)`,
    a default no-op (Ruling 03-3).
  - `class SnapSettings extends ChangeNotifier { SnapSettings({bool objectSnap = true}); bool get objectSnap; void toggleObjectSnap(); }`

- [ ] **Step 1: Write the failing test.**

```dart
// test/interaction_cursor_test.dart
import 'dart:ui' show Canvas, Size;

import 'package:flutter/services.dart'
    show KeyEvent, MouseCursor, SystemMouseCursors;
import 'package:flutter/widgets.dart' show KeyEventResult, MouseRegion, Offset;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/src/flutter_text_measurer.dart';
import 'package:jet_cad_2d_flutter/src/interaction_layer.dart';
import 'package:jet_cad_2d_flutter/src/tool.dart';
import 'package:jet_cad_2d_flutter/src/viewport_transform.dart';

import 'support/selection_fixture.dart';

/// A tool that has only a cursor, and says when it changes.
class _CursorTool extends Tool {
  MouseCursor _cursor = MouseCursor.defer;

  @override
  MouseCursor get cursor => _cursor;

  void show(MouseCursor next) {
    _cursor = next;
    notifyListeners();
  }

  @override
  String get name => 'Cursor';
  @override
  ToolPhase get phase => ToolPhase.idle;
  @override
  void onPointerDown(ToolPointerEvent e, ToolContext ctx) {}
  @override
  void onPointerMove(ToolPointerEvent e, ToolContext ctx) {}
  @override
  void onPointerUp(ToolPointerEvent e, ToolContext ctx) {}
  @override
  void onPointerExit(ToolContext ctx) {}
  @override
  KeyEventResult onKey(KeyEvent event, ToolContext ctx) =>
      KeyEventResult.ignored;
  @override
  void cancel(ToolContext ctx) {}
  @override
  void paintOverlay(Canvas canvas, ViewportTransform camera, Size viewport) {}
}

void main() {
  testWidgets("the MouseRegion follows the active tool's cursor (spec D5, "
      'M-03ab)', (tester) async {
    final measurer = FlutterTextMeasurer();
    addTearDown(measurer.clear);
    final doc = DraftDocument.empty(measurer: measurer);
    final rig = await pumpInteraction(tester,
        document: doc, camera: cameraAt(2.0, const Offset(-1850, 1120)));
    MouseCursor current() => tester
        .widget<MouseRegion>(find
            .descendant(
                of: find.byType(InteractionLayer),
                matching: find.byType(MouseRegion))
            .first)
        .cursor;

    expect(current(), MouseCursor.defer, reason: 'SelectTool, idle');
    final probe = _CursorTool();
    addTearDown(probe.dispose);
    rig.tools.activate(probe);
    probe.show(SystemMouseCursors.move);
    await tester.pump();
    expect(current(), SystemMouseCursors.move,
        reason: 'a notification rebuilds the MouseRegion');
    probe.show(SystemMouseCursors.grabbing);
    await tester.pump();
    expect(current(), SystemMouseCursors.grabbing);
    rig.tools.activate(rig.tool);
    await tester.pump();
    expect(current(), MouseCursor.defer);
  });
}
```

- [ ] **Step 2: Run it to fail.** `CI=true flutter test
  test/interaction_cursor_test.dart` → compile error: `cursor` is not a
  member of `Tool`, so there is nothing to override.

- [ ] **Step 3: Implement.** Create `lib/src/snap_settings.dart`:

```dart
import 'package:flutter/foundation.dart';

/// F3's object-snap toggle (spec D10). The shell owns it; a drag reads it
/// per event through `ToolContext.snap`.
class SnapSettings extends ChangeNotifier {
  SnapSettings({bool objectSnap = true}) : _objectSnap = objectSnap;

  bool _objectSnap;
  bool get objectSnap => _objectSnap;

  void toggleObjectSnap() {
    _objectSnap = !_objectSnap;
    notifyListeners();
  }
}
```

In `lib/src/tool.dart`:
- change the services import to `import 'package:flutter/services.dart'
  show KeyEvent, MouseCursor;`;
- add `import 'grip_cache.dart';`, `import 'page_notifier.dart';` and
  `import 'snap_settings.dart';`;
- replace `ToolContext` with:

```dart
/// Everything a [Tool] needs to act: the document to mutate, the index to
/// query, the camera to read, the selection to update — and, since 03, the
/// page, the snap settings and the grips, each optional so every 02 call
/// site still compiles (spec D10).
final class ToolContext {
  const ToolContext({
    required this.document,
    required this.index,
    required this.camera,
    required this.selection,
    this.page,
    this.snap,
    this.grips,
  });

  final DraftDocument document;
  final SpatialIndex index;
  final CameraController camera;
  final SelectionController selection;

  /// The page, for the drag's grid snap; null: no grid snap.
  final PageNotifier? page;

  /// F3's toggle; null: object snap is on.
  final SnapSettings? snap;

  /// The selection's grips and box; null: no grip or rotation grip is drawn
  /// or hit.
  final GripCache? grips;

  void execute(DraftCommand command) => document.commands.execute(command);
}
```

Add three members to `abstract class Tool`, after `paintOverlay`:

```dart
  /// The pointer's cursor over the layer (spec 03 D5). `InteractionLayer`
  /// rebuilds its `MouseRegion` when the tool notifies.
  MouseCursor get cursor => MouseCursor.defer;

  /// The world transform a live move or rotate would apply, for the
  /// overlay's preview (spec 03 D7); null otherwise.
  Transform2? get selectionPreviewTransform => null;

  /// Paints under the overlay's rebased world matrix, `worldToScreen ∘
  /// translate(origin)`, so coordinates handed to [canvas] must be `world −
  /// origin` (Ruling 03-3). [scale] is the camera's, for stroke widths.
  void paintWorldOverlay(Canvas canvas, Vector2 origin, double scale) {}
```

In `lib/src/interaction_layer.dart`, replace `build` with:

```dart
  @override
  Widget build(BuildContext context) => Focus(
        focusNode: _focus,
        autofocus: true,
        onKeyEvent: (_, event) => _tool.onKey(event, _ctx),
        // Spec 03 D5: a cursor is a widget parameter, so it needs a
        // rebuild. Only the MouseRegion is rebuilt, and only when the tool
        // (or a swap) notifies; the Listener subtree is the cached child.
        child: ListenableBuilder(
          listenable: widget.tools,
          builder: (context, child) => MouseRegion(
            cursor: _tool.cursor,
            onExit: _onExit,
            child: child,
          ),
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: _onDown,
            onPointerMove: _onMove,
            onPointerUp: _onUp,
            onPointerCancel: _onCancel,
            onPointerHover: _onHover,
            child: widget.child,
          ),
        ),
      );
```

Add the export to `lib/jet_cad_2d_flutter.dart`, after
`src/selection_style.dart`:

```dart
export 'src/snap_settings.dart';
```

- [ ] **Step 4: Run it to pass.** `CI=true flutter test
  test/interaction_cursor_test.dart test/interaction_layer_test.dart
  test/tool_controller_test.dart` → all tests pass. `_CountingTool` still
  compiles; it overrides nothing new. Then run the `jet_cad_2d_flutter`
  gate line.
- [ ] **Step 5: Commit.**

```bash
git add packages/jet_cad_2d_flutter/lib/src/tool.dart packages/jet_cad_2d_flutter/lib/src/snap_settings.dart packages/jet_cad_2d_flutter/lib/src/interaction_layer.dart packages/jet_cad_2d_flutter/lib/jet_cad_2d_flutter.dart packages/jet_cad_2d_flutter/test/interaction_cursor_test.dart
git commit -m "$(cat <<'EOF'
feat(render): Tool cursor and preview hooks, ToolContext page/snap/grips

Spec 03 D5, D7, D10: Tool.cursor, selectionPreviewTransform and
paintWorldOverlay with defaults (Ruling 03-3); three optional ToolContext
fields; SnapSettings; and a ListenableBuilder that rebuilds only the
InteractionLayer's MouseRegion when the tool notifies.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 6: `GripDrag` — captures, `T`, the one command, revalidation, permissions

**Files:**
- Create: `lib/src/grip_drag.dart`
- Modify: `lib/jet_cad_2d_flutter.dart`: add `export 'src/grip_drag.dart';`
  after `src/grip_cache.dart`.
- Test: `test/grip_drag_test.dart` (D1–D11)

**Interfaces:**
- Consumes: `leafGrips`, `reshapeLeaf`, `rigidTransformLeaf` and `Grip`
  (Tasks 1–2); `SetEntityGeometryCommand`, `TransformNodeCommand`,
  `CompoundCommand`, `DraftPermissions` and `Capability`; `Node ==`;
  `GeometryPayload ==`; `SelectionKey`.
- Produces:
  - `enum DragKind { band, move, rotate, reshape }`
  - `const double kRotationStep = math.pi / 12;`
  - `final class GripDrag`:
    - `static GripDrag? move(DraftDocument, Iterable<SelectionKey>)`
    - `static GripDrag? rotate(DraftDocument, Iterable<SelectionKey>, Vector2 pivot, Vector2 press)`
    - `static GripDrag? reshape(DraftDocument, SelectionKey, Grip)`
    - fields `kind`, `grip`, `base`, `target`
    - getters `theta`, `transform`, `previewPayload`, `leafKind`,
      `capabilities`
    - `bool permittedBy(DraftPermissions)`
    - `void moveTo(Vector2 world)` (move and reshape)
    - `void rotateTo(Vector2 pointer, {required bool step})` (rotate)
    - `DraftCommand? command(DraftPermissions permissions)`

- [ ] **Step 1: Write the failing test.**

```dart
// test/grip_drag_test.dart
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/src/grip_drag.dart';
import 'package:jet_cad_2d_flutter/src/selection.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'support/grip_fixture.dart';

SelectionKey k(Handle h) => SelectionKey.root(h);

Handle targetOf(DraftCommand c) => switch (c) {
      SetEntityGeometryCommand(:final handle) => handle,
      TransformNodeCommand(:final handle) => handle,
      _ => throw StateError('unexpected member $c'),
    };

/// The next double above a positive [x].
double nextUp(double x) {
  final b = ByteData(8)..setFloat64(0, x);
  b.setInt64(0, b.getInt64(0) + 1);
  return b.getFloat64(0);
}

/// A *decision*-style comparison — what M-03e swaps the undo assertion to.
bool payloadsClose(GeometryPayload a, GeometryPayload b) {
  if (a.coords.length != b.coords.length ||
      a.scalars.length != b.scalars.length) {
    return false;
  }
  for (var i = 0; i < a.coords.length; i++) {
    if (!Tolerance.standard.eq(a.coords[i], b.coords[i])) return false;
  }
  for (var i = 0; i < a.scalars.length; i++) {
    if (!Tolerance.standard.eq(a.scalars[i], b.scalars[i])) return false;
  }
  return true;
}

/// A rotate of a leaf, an arc, the rotated group and an instance, executed
/// and then undone. Returns what was stored before.
(Map<Handle, GeometryPayload>, Map<Handle, Node>) rotateAndUndo(GripScene s) {
  final doc = s.document;
  final payloads = {for (final h in [s.line, s.arcNeg]) h: payloadOf(doc, h)};
  final nodes = {for (final h in [s.group, s.instA]) h: doc.tree[h]!};
  final drag = GripDrag.rotate(doc,
      [k(s.line), k(s.arcNeg), k(s.group), k(s.instA)],
      Vector2(7200, 3150), Vector2(7300, 3150))!;
  drag.rotateTo(Vector2(7250, 3240), step: false);
  doc.commands.execute(drag.command(DraftPermissions.all)!);
  expect(payloadOf(doc, s.line), isNot(payloads[s.line]),
      reason: 'the fixture really moved');
  doc.commands.undo();
  return (payloads, nodes);
}

void main() {
  test('a move is one CompoundCommand labelled Move, members in ascending '
      'handle order (M-03an)', () {
    final s = gripScene();
    final drag = GripDrag.move(
        s.document, [k(s.instA), k(s.group), k(s.arcNeg), k(s.line)])!;
    expect(drag.kind, DragKind.move);
    drag.base.setValues(7046, 3032);
    drag.moveTo(Vector2(7083.5, 3013.25));
    expect(drag.transform!.e, 37.5);
    expect(drag.transform!.f, -18.75);
    final command = drag.command(DraftPermissions.all)! as CompoundCommand;
    expect(command.label, 'Move');
    expect([for (final c in command.children) targetOf(c)],
        [s.line, s.arcNeg, s.group, s.instA]);
    expect([for (final c in command.children) c.runtimeType], [
      SetEntityGeometryCommand,
      SetEntityGeometryCommand,
      TransformNodeCommand,
      TransformNodeCommand,
    ]);
  });

  test('a rotated group moves by T.multiply(node.transform) (M-03i)', () {
    final s = gripScene();
    final doc = s.document;
    final g0 = doc.tree[s.group]! as GroupNode;
    expect(g0.transform.b, isNot(0.0), reason: "the fixture's group is rotated");
    final leaf0 = payloadOf(doc, s.groupLeaf);
    final drag = GripDrag.move(doc, [k(s.group)])!..base.setValues(7400, 3300);
    drag.moveTo(Vector2(7437.5, 3281.25));
    doc.commands.execute(drag.command(DraftPermissions.all)!);
    final g1 = doc.tree[s.group]! as GroupNode;
    final want = Transform2.translation(37.5, -18.75).multiply(g0.transform);
    final got = g1.transform;
    for (final (a, b) in [
      (got.a, want.a),
      (got.b, want.b),
      (got.c, want.c),
      (got.d, want.d),
      (got.e, want.e),
      (got.f, want.f),
    ]) {
      expect(a, closeTo(b, 1e-9));
    }
    expect(g1.children, g0.children);
    expect(payloadOf(doc, s.groupLeaf), leaf0,
        reason: "the group's leaf lives in the group's space; only the node "
            'moves');
  });

  test('an instance move rewrites the instance node, never the definition '
      '(M-03c)', () {
    final s = gripScene();
    final doc = s.document;
    final a0 = doc.tree[s.instA]! as InstanceNode;
    final b0 = doc.tree[s.instB]!;
    final leaf0 = payloadOf(doc, s.defLeaf);
    final drag = GripDrag.move(doc, [k(s.instA)])!..base.setValues(7460, 3055);
    drag.moveTo(Vector2(7431.25, 3102.5));
    doc.commands.execute(drag.command(DraftPermissions.all)!);
    final a1 = doc.tree[s.instA]! as InstanceNode;
    expect(a1.transform.e, closeTo(a0.transform.e - 28.75, 1e-9));
    expect(a1.transform.f, closeTo(a0.transform.f + 47.5, 1e-9));
    expect(a1.definition, a0.definition);
    expect(doc.tree[s.instB], b0, reason: 'the other instance is untouched');
    expect(payloadOf(doc, s.defLeaf), leaf0, reason: 'so is the definition');
  });

  test("a rotate is labelled Rotate and turns an arc's start angle (M-03h)",
      () {
    final s = gripScene();
    final doc = s.document;
    final drag = GripDrag.rotate(
        doc, [k(s.arcPos)], Vector2(7100, 3100), Vector2(7200, 3100))!;
    drag.rotateTo(
        Vector2(7100 + 100 * math.cos(0.7), 3100 + 100 * math.sin(0.7)),
        step: false);
    expect(drag.theta, closeTo(0.7, 1e-12));
    final command = drag.command(DraftPermissions.all)! as CompoundCommand;
    expect(command.label, 'Rotate');
    doc.commands.execute(command);
    final arc = payloadOf(doc, s.arcPos);
    expect(arc.scalars[0], 40);
    expect(arc.scalars[1], closeTo(1.0, 1e-12));
    expect(arc.scalars[2], 1.9);
    // The centre (7050, 3200) is (−50, 100) from the pivot.
    expect(arc.coords[0],
        closeTo(7100 + math.cos(0.7) * -50 - math.sin(0.7) * 100, 1e-9));
    expect(arc.coords[1],
        closeTo(3100 + math.sin(0.7) * -50 + math.cos(0.7) * 100, 1e-9));
  });

  test('a reshape is one CompoundCommand labelled Stretch', () {
    final s = gripScene();
    final doc = s.document;
    final grip = leafGrips(EntityKind.line, payloadOf(doc, s.line))[1];
    final drag = GripDrag.reshape(doc, k(s.line), grip)!;
    expect(drag.kind, DragKind.reshape);
    expect(drag.leafKind, EntityKind.line);
    expect([drag.base.x, drag.base.y], [7130, 3060]);
    drag.moveTo(Vector2(7150.5, 3070.25));
    expect(drag.previewPayload!.coords, [7010, 3020, 7150.5, 3070.25]);
    final command = drag.command(DraftPermissions.all)! as CompoundCommand;
    expect(command.label, 'Stretch');
    expect(command.children, hasLength(1));
    doc.commands.execute(command);
    expect(payloadOf(doc, s.line).coords, [7010, 3020, 7150.5, 3070.25]);
  });

  test('a drag that changes nothing builds no command (M-03p)', () {
    final s = gripScene();
    final doc = s.document;
    final move = GripDrag.move(doc, [k(s.line)])!..base.setValues(7046, 3032);
    move.moveTo(Vector2(7046, 3032));
    expect(move.command(DraftPermissions.all), isNull,
        reason: 'Δ == (0, 0) exactly');
    final rotate = GripDrag.rotate(
        doc, [k(s.line)], Vector2(7070, 3040), Vector2(7100, 3080))!;
    rotate.rotateTo(Vector2(7100, 3080), step: false);
    expect(rotate.command(DraftPermissions.all), isNull,
        reason: 'θ == 0 exactly');
    final end = leafGrips(EntityKind.line, payloadOf(doc, s.line))[1];
    final same = GripDrag.reshape(doc, k(s.line), end)!
      ..moveTo(Vector2(7130, 3060));
    expect(same.command(DraftPermissions.all), isNull,
        reason: 'a payload == the stored one');
    final radius = leafGrips(EntityKind.circle, payloadOf(doc, s.circle))[1];
    final flat = GripDrag.reshape(doc, k(s.circle), radius)!
      ..moveTo(Vector2(7300, 3250));
    expect(flat.previewPayload, isNull);
    expect(flat.command(DraftPermissions.all), isNull,
        reason: 'a degenerate reshape');
    expect(doc.commands.undoDepth, 0);
  });

  test('release revalidates against the press-time captures (M-03t)', () {
    final s = gripScene();
    final doc = s.document;
    final drag = GripDrag.move(doc, [k(s.line), k(s.instA)])!
      ..base.setValues(7046, 3032);
    drag.moveTo(Vector2(7080, 3010));
    expect(drag.command(DraftPermissions.all), isNotNull);
    doc.commands.execute(SetEntityGeometryCommand(
        s.line,
        GeometryPayload(
            coords: Float64List.fromList([7010, 3020, 7140, 3080]),
            scalars: Float64List(0))));
    expect(drag.command(DraftPermissions.all), isNull,
        reason: 'the leaf is not == its capture');
    doc.commands.undo();
    expect(drag.command(DraftPermissions.all), isNotNull,
        reason: 'undo restored it exactly, so the capture matches again');
    doc.commands
        .execute(TransformNodeCommand(s.instA, Transform2.translation(1, 2)));
    expect(drag.command(DraftPermissions.all), isNull,
        reason: 'the node is not == its capture');
    doc.commands.undo();
    doc.commands.execute(RemoveEntityCommand(s.line));
    expect(drag.command(DraftPermissions.all), isNull,
        reason: 'a target that is gone, with no throw');
  });

  test('a refused member cancels the whole drag (M-03k)', () {
    final s = gripScene();
    final doc = s.document;
    final drag = GripDrag.move(doc, [k(s.line), k(s.instA)])!
      ..base.setValues(7046, 3032);
    drag.moveTo(Vector2(7080, 3010));
    expect(drag.capabilities, {Capability.geometry, Capability.transform});
    expect(drag.permittedBy(DraftPermissions.all), isTrue);
    expect(drag.permittedBy(DraftPermissions.runtime), isFalse);
    expect(drag.command(DraftPermissions.runtime), isNull,
        reason: 'all or nothing: the instance is permitted, the line is not');
    final table = GripDrag.move(doc, [k(s.instA)])!;
    expect(table.capabilities, {Capability.transform});
    expect(table.permittedBy(DraftPermissions.runtime), isTrue);
  });

  test('fills are skipped; a fills-only selection has no drag (M-03am)', () {
    final s = gripScene();
    final doc = s.document;
    final region = AddRegionCommand.allocate(
      seed: doc.handleSeed,
      owner: doc.rootHandle,
      boundaryKind: EntityKind.polyline,
      boundaryPayload: GeometryPayload(
          coords: Float64List.fromList(
              [7600, 3000, 7700, 3000, 7700, 3100, 7600, 3000]),
          scalars: Float64List(0)),
      layer: ReservedHandles.layerZero,
      fillColor: const TrueColor(0x8844AA),
      boundaryColor: const ByLayerColor(),
    );
    doc.commands.execute(region);
    expect(GripDrag.move(doc, [k(region.fill.handle)]), isNull);
    final drag = GripDrag.move(doc, [k(region.fill.handle), k(s.line)])!
      ..base.setValues(7046, 3032);
    drag.moveTo(Vector2(7080, 3010));
    final command = drag.command(DraftPermissions.all)! as CompoundCommand;
    expect([for (final c in command.children) targetOf(c)], [s.line]);
  });

  test('undo restores every stored value with == (spec D11; M-03e is the '
      'designed survivor)', () {
    final s = gripScene();
    final doc = s.document;
    final (payloads, nodes) = rotateAndUndo(s);
    // GeometryPayload == is exact per double. Transform2 is never compared
    // with == (object identity); the nodes are compared by value.
    expect(payloadOf(doc, s.line), payloads[s.line]);
    expect(payloadOf(doc, s.arcNeg), payloads[s.arcNeg]);
    expect(doc.tree[s.group], nodes[s.group]);
    expect(doc.tree[s.instA], nodes[s.instA]);
  });

  test('the undo assertion enforces ==: one ulp is caught (M-03e '
      'companion, Ruling 03-20)', () {
    final s = gripScene();
    final doc = s.document;
    final (payloads, _) = rotateAndUndo(s);
    final restored = payloadOf(doc, s.line);
    final original = payloads[s.line]!;
    final nudged = GeometryPayload(
        coords: Float64List.fromList(restored.coords)
          ..[0] = nextUp(restored.coords[0]),
        scalars: Float64List.fromList(restored.scalars));
    expect(nudged.coords[0], isNot(restored.coords[0]));
    expect(nudged == original, isFalse,
        reason: '== sees one ulp: the undo test above would go red on it');
    expect(payloadsClose(nudged, original), isTrue,
        reason: 'Tolerance does not — which is why M-03e survives');
  });
}
```

- [ ] **Step 2: Run it to fail.** `CI=true flutter test
  test/grip_drag_test.dart` → compile error: `grip_drag.dart` does not
  exist.

- [ ] **Step 3: Implement.**

```dart
// lib/src/grip_drag.dart
import 'dart:math' as math;

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'selection.dart';

/// What a `SelectTool` drag is doing (spec D5).
enum DragKind { band, move, rotate, reshape }

/// Shift's rotation step (spec D8): 15°.
const double kRotationStep = math.pi / 12;

/// What release will rewrite, read at press (spec D4).
sealed class _Capture {
  const _Capture(this.handle);
  final Handle handle;
}

final class _LeafCapture extends _Capture {
  const _LeafCapture(super.handle, this.entityKind, this.payload);
  final EntityKind entityKind;

  /// A `read` copy, never a `peek`: the store's own buffer changes under an
  /// edit.
  final GeometryPayload payload;
}

final class _NodeCapture extends _Capture {
  const _NodeCapture(super.handle, this.node);

  /// `GroupNode`/`InstanceNode ==` is exact component equality.
  final Node node;
}

/// One drag's state and its one command (spec D2, D4).
///
/// Nothing is dispatched while the drag lives. [command] builds a single
/// [CompoundCommand], even for one member, so the undo label says `Move`,
/// `Rotate` or `Stretch`. It returns null — dispatch nothing — when:
/// - a target is gone or changed since press (revalidation);
/// - a member's capability is refused (all or nothing);
/// - the drag changes nothing.
final class GripDrag {
  GripDrag._(this.document, this.kind, this._captures, [this.grip]);

  /// A move of every movable key in [keys]. A fill follows its boundary and
  /// an attrib is never root-level, so both are skipped (D4). Null when
  /// nothing is left.
  static GripDrag? move(DraftDocument document, Iterable<SelectionKey> keys) {
    final captures = _capture(document, keys);
    return captures.isEmpty
        ? null
        : GripDrag._(document, DragKind.move, captures);
  }

  /// A rotate of [keys] about [pivot], measured from the press at [press].
  static GripDrag? rotate(DraftDocument document, Iterable<SelectionKey> keys,
      Vector2 pivot, Vector2 press) {
    final captures = _capture(document, keys);
    if (captures.isEmpty) return null;
    final drag = GripDrag._(document, DragKind.rotate, captures);
    drag.base.setFrom(pivot);
    drag.target.setFrom(press);
    drag._pressAngle = math.atan2(press.y - pivot.y, press.x - pivot.x);
    return drag;
  }

  /// A reshape of [key]'s leaf by [grip]; its base is the grip, exactly.
  static GripDrag? reshape(
      DraftDocument document, SelectionKey key, Grip grip) {
    if (grip.role == GripRole.move) return null;
    final slot = document.entities.slotOf(key.target);
    if (slot == null) return null;
    final kind = document.entities.kindAt(slot);
    if (kind == EntityKind.fill || kind == EntityKind.attrib) return null;
    final capture = _LeafCapture(key.target, kind,
        document.geometry.read(document.entities.geomIndexAt(slot)));
    final drag = GripDrag._(document, DragKind.reshape, [capture], grip);
    drag.base.setValues(grip.x, grip.y);
    drag.target.setValues(grip.x, grip.y);
    return drag;
  }

  /// In ascending target handle order: that is the members' order (D4).
  static List<_Capture> _capture(
      DraftDocument document, Iterable<SelectionKey> keys) {
    final sorted = keys.toList()
      ..sort((a, b) => a.target.value.compareTo(b.target.value));
    final out = <_Capture>[];
    for (final key in sorted) {
      final node = document.tree[key.target];
      if (node != null) {
        out.add(_NodeCapture(key.target, node));
        continue;
      }
      final slot = document.entities.slotOf(key.target);
      if (slot == null) continue;
      final kind = document.entities.kindAt(slot);
      if (kind == EntityKind.fill || kind == EntityKind.attrib) continue;
      out.add(_LeafCapture(key.target, kind,
          document.geometry.read(document.entities.geomIndexAt(slot))));
    }
    return out;
  }

  final DraftDocument document;
  final DragKind kind;
  final List<_Capture> _captures;

  /// The grabbed grip; non-null only for a reshape.
  final Grip? grip;

  /// World. A move's or a reshape's base point; a rotate's pivot.
  final Vector2 base = Vector2.zero();

  /// World. The resolved target; for a rotate, the pointer.
  final Vector2 target = Vector2.zero();

  double _pressAngle = 0;
  double _theta = 0;
  Transform2? _transform;
  GeometryPayload? _preview;

  /// A rotate's angle, radians, in (−π, π] (Ruling 03-14).
  double get theta => _theta;

  /// A move's or a rotate's world `T`; cached per event, so a painter's
  /// per-frame read allocates nothing.
  Transform2? get transform => _transform;

  /// A reshape's payload at the current target; null when degenerate.
  GeometryPayload? get previewPayload => _preview;

  /// A reshape's entity kind; null otherwise.
  EntityKind? get leafKind => kind == DragKind.reshape
      ? (_captures.single as _LeafCapture).entityKind
      : null;

  /// A leaf needs `geometry`; a group or an instance needs `transform`
  /// (D2).
  Set<Capability> get capabilities => {
        for (final c in _captures)
          c is _NodeCapture ? Capability.transform : Capability.geometry,
      };

  bool permittedBy(DraftPermissions permissions) =>
      capabilities.every(permissions.allows);

  /// A move or a reshape follows [world].
  void moveTo(Vector2 world) {
    target.setFrom(world);
    switch (kind) {
      case DragKind.move:
        _transform = Transform2.translation(target.x - base.x, target.y - base.y);
      case DragKind.reshape:
        final c = _captures.single as _LeafCapture;
        _preview = reshapeLeaf(c.entityKind, c.payload, grip!, target);
      case DragKind.rotate:
      case DragKind.band:
        throw StateError('moveTo on a ${kind.name} drag');
    }
  }

  /// A rotate follows [pointer]. With [step], θ rounds to the nearest
  /// multiple of [kRotationStep] (D8).
  void rotateTo(Vector2 pointer, {required bool step}) {
    if (kind != DragKind.rotate) {
      throw StateError('rotateTo on a ${kind.name} drag');
    }
    target.setFrom(pointer);
    var theta =
        math.atan2(pointer.y - base.y, pointer.x - base.x) - _pressAngle;
    if (theta > math.pi) {
      theta -= 2 * math.pi;
    } else if (theta <= -math.pi) {
      theta += 2 * math.pi;
    }
    if (step) theta = (theta / kRotationStep).roundToDouble() * kRotationStep;
    _theta = theta;
    _transform = Transform2.translation(base.x, base.y)
        .multiply(Transform2.rotation(theta))
        .multiply(Transform2.translation(-base.x, -base.y));
  }

  /// The one command release dispatches, or null for none (spec D4).
  DraftCommand? command(DraftPermissions permissions) {
    // The backstop for any document change mid-drag, whatever its source.
    if (!_revalidate()) return null;
    final members = <DraftCommand>[];
    switch (kind) {
      case DragKind.reshape:
        final c = _captures.single as _LeafCapture;
        final next = _preview;
        if (next == null || next == c.payload) return null;
        members.add(SetEntityGeometryCommand(c.handle, next));
      case DragKind.move:
      case DragKind.rotate:
        final t = _transform;
        if (t == null) return null;
        if (kind == DragKind.move &&
            target.x - base.x == 0 &&
            target.y - base.y == 0) {
          return null;
        }
        if (kind == DragKind.rotate && _theta == 0) return null;
        for (final c in _captures) {
          switch (c) {
            case _LeafCapture(:final handle, :final entityKind, :final payload):
              members.add(SetEntityGeometryCommand(
                  handle, rigidTransformLeaf(entityKind, payload, t)));
            case _NodeCapture(:final handle, :final node):
              // After the node's own transform (D4); world is root space,
              // so there is no conjugation.
              members.add(TransformNodeCommand(handle, t.multiply(node.transform)));
          }
        }
      case DragKind.band:
        throw StateError('a band has no command');
    }
    // All or nothing: a move that leaves some objects behind breaks the
    // alignment the user was dragging for (D4).
    if (members.any((m) => !m.capabilities.every(permissions.allows))) {
      return null;
    }
    return CompoundCommand(members,
        label: switch (kind) {
          DragKind.move => 'Move',
          DragKind.rotate => 'Rotate',
          DragKind.reshape || DragKind.band => 'Stretch',
        });
  }

  bool _revalidate() {
    for (final c in _captures) {
      switch (c) {
        case _LeafCapture(:final handle, :final entityKind, :final payload):
          final slot = document.entities.slotOf(handle);
          if (slot == null || document.entities.kindAt(slot) != entityKind) {
            return false;
          }
          if (document.geometry.peek(document.entities.geomIndexAt(slot)) !=
              payload) {
            return false;
          }
        case _NodeCapture(:final handle, :final node):
          if (document.tree[handle] != node) return false;
      }
    }
    return true;
  }
}
```

Add the export to `lib/jet_cad_2d_flutter.dart`, after
`src/grip_cache.dart`:

```dart
export 'src/grip_drag.dart';
```

- [ ] **Step 4: Run it to pass.** `CI=true flutter test
  test/grip_drag_test.dart` → all tests pass. Then run the
  `jet_cad_2d_flutter` gate line.
- [ ] **Step 5: Commit.**

```bash
git add packages/jet_cad_2d_flutter/lib/src/grip_drag.dart packages/jet_cad_2d_flutter/lib/jet_cad_2d_flutter.dart packages/jet_cad_2d_flutter/test/grip_drag_test.dart
git commit -m "$(cat <<'EOF'
feat(render): GripDrag -- captures, T, one CompoundCommand, revalidation

Spec 03 D4: one CompoundCommand labelled Move, Rotate or Stretch, members in
ascending handle order; leaves by rigidTransformLeaf, nodes by
T.multiply(node.transform); fills skipped; press-time captures revalidated
at release; permissions all or nothing; no-op drags dispatch nothing.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

---
### Task 7: `SelectTool` — press classes, the three drags, the camera listener, keys, cancel paths

**Files:**
- Modify: `lib/src/select_tool.dart`
- Rewrite: `test/support/grip_fixture.dart` (adds the rig, the pointer
  helpers and the layer pump; keeps everything from Task 4)
- Modify: `test/select_tool_test.dart` (the one D12 test, Ruling 03-21)
- Test: `test/select_tool_drag_test.dart` (T1–T17, W1–W3)

**Interfaces:**
- Consumes:
  - `GripDrag`, `DragKind`, `kRotationStep` (Task 6);
  - `GripCache` (`grips`, `box`, `hot`, `hitTest`, `hitsRotationGrip`) and
    `rotationGripOf` (Task 4);
  - `ToolContext.page/snap/grips`, `Tool.cursor` and
    `selectionPreviewTransform` (Task 5);
  - `resolveDragPoint`, `DragPoint`, `kSnapAperturePixels` and
    `dragGridStepMm` (Task 3).
- Produces:
  - `enum PressClass { rotationGrip, grip, selectedBody, unselectedBody, empty }`
  - on `SelectTool`: `PressClass? get pressClass`, `DragKind? get
    dragKind`, `MouseCursor get cursor`, `Transform2? get
    selectionPreviewTransform`.
  - `bandMode`, `bandScreen` and `bandStart` are unchanged in meaning: they
    are non-null only during a band.
  - fixture:
    - `GripRig`, with fields `document`, `index`, `selection`, `camera`,
      `outlines`, `grips`, `snap`, `page`, `tool`, `context`, `tools`;
    - `GripRig gripRig(DraftDocument, {CameraController? camera, bool objectSnap = false})`;
    - `ToolPointerEvent pointerAt(CameraController, Offset, {int buttons, bool shift, int pointer})`;
    - `void pressAndMove(GripRig, Offset from, Offset to, {bool shift})`;
    - `void release(GripRig, Offset at, {bool shift})`;
    - `void click(GripRig, Offset at, {bool shift})`;
    - `const Size kGripLayerSize`;
    - `Future<void> pumpGripLayer(WidgetTester, GripRig)`;
    - `Offset globalAt(WidgetTester, Offset local)`.

- [ ] **Step 1: Rewrite the fixture.** Replace
  `test/support/grip_fixture.dart` whole with the text below. Everything
  from Task 4 is kept verbatim. The rig and the helpers are new.

```dart
// test/support/grip_fixture.dart
import 'package:flutter/gestures.dart' show kPrimaryButton;
import 'package:flutter/widgets.dart'
    show
        Center,
        CustomPaint,
        Directionality,
        Listenable,
        Offset,
        Positioned,
        RepaintBoundary,
        Size,
        SizedBox,
        Stack,
        TextDirection;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/src/camera_controller.dart';
import 'package:jet_cad_2d_flutter/src/draft_canvas.dart';
import 'package:jet_cad_2d_flutter/src/grip_cache.dart';
import 'package:jet_cad_2d_flutter/src/interaction_layer.dart';
import 'package:jet_cad_2d_flutter/src/outline_cache.dart';
import 'package:jet_cad_2d_flutter/src/page_notifier.dart';
import 'package:jet_cad_2d_flutter/src/select_tool.dart';
import 'package:jet_cad_2d_flutter/src/selection.dart';
import 'package:jet_cad_2d_flutter/src/selection_overlay.dart';
import 'package:jet_cad_2d_flutter/src/snap_settings.dart';
import 'package:jet_cad_2d_flutter/src/tool.dart';
import 'package:jet_cad_2d_flutter/src/viewport_transform.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'selection_fixture.dart';

// ---- Task 4: the scene, the camera, the readers -------------------------

/// The spec's standard 03 fixture (Testing).
///
/// - Everything sits at x ≈ 7000–7550, y ≈ 3000–3330, so the rebase origin
///   is non-zero.
/// - A closed room.
/// - Arcs with a non-zero start, one of them with a negative sweep.
/// - A group whose own transform is a rotation.
/// - Two instances of one definition.
/// - The root stays the identity.
final class GripScene {
  GripScene._(this.document);

  final DraftDocument document;
  late final Handle line, polyline, room, circle, arcPos, arcNeg, point;
  late final Handle group, groupLeaf, def, defLeaf, instA, instB;
}

GripScene gripScene(
    {TextMeasurer measurer = const InsertionPointMeasurer(),
    PageComponent? page}) {
  final doc = DraftDocument.empty(measurer: measurer);
  final s = GripScene._(doc);
  final root = doc.rootHandle;
  s.line = addEntity(doc, root, EntityKind.line, [7010, 3020, 7130, 3060], []);
  s.polyline = addEntity(doc, root, EntityKind.polyline,
      [7010, 3100, 7040, 3130, 7070, 3100, 7100, 3130, 7130, 3100], []);
  s.room = addEntity(doc, root, EntityKind.polyline,
      [7200, 3000, 7400, 3000, 7400, 3150, 7200, 3150, 7200, 3000], []);
  s.circle = addEntity(doc, root, EntityKind.circle, [7300, 3250], [25]);
  s.arcPos = addEntity(doc, root, EntityKind.arc, [7050, 3200], [40, 0.3, 1.9]);
  s.arcNeg =
      addEntity(doc, root, EntityKind.arc, [7150, 3250], [30, 2.2, -1.4]);
  s.point = addEntity(doc, root, EntityKind.point, [7250, 3300], []);
  s.group = addGroup(doc, root,
      Transform2.translation(7400, 3300).multiply(Transform2.rotation(0.6)));
  s.groupLeaf = addEntity(doc, s.group, EntityKind.line, [0, 0, 40, 0], []);
  s.def = addDefinition(doc, 'Table');
  s.defLeaf = addEntity(doc, s.def, EntityKind.line, [0, 0, 30, 10], []);
  s.instA = addInstance(doc, s.def,
      Transform2.translation(7450, 3050).multiply(Transform2.rotation(0.3)));
  s.instB = addInstance(doc, s.def,
      Transform2.translation(7500, 3200).multiply(Transform2.rotation(-0.5)));
  if (page != null) {
    PageComponent.register(doc.components);
    doc.commands.execute(SetComponentCommand<PageComponent>(root, page));
  }
  // `undoDepth` counts the drag under test only.
  doc.commands.clearHistory();
  expect(doc.tree[root]!.transform.isIdentity, isTrue,
      reason: 'spec, Testing: the root stays the identity');
  return s;
}

/// Zoomed (scale ≠ 1), rotated (not 0°, not 90°), y flipped, and panned so
/// [centre] sits in the middle of [viewport].
CameraController gripCamera(
    {Vector2? centre,
    Size viewport = const Size(800, 600),
    double scale = 1.1,
    double rotation = 0.35}) {
  final c = centre ?? Vector2(7270, 3161);
  final linear =
      Transform2.rotation(rotation).multiply(Transform2.scale(scale, -scale));
  final mid = linear.transformPoint(c);
  return CameraController(ViewportTransform(
      worldToScreenMatrix: Transform2.translation(
              viewport.width / 2 - mid.x, viewport.height / 2 - mid.y)
          .multiply(linear)));
}

/// World (x, y) on screen under [camera].
Offset screenOf(CameraController camera, double x, double y) {
  final s = camera.value.worldToScreen(Vector2(x, y));
  return Offset(s.x, s.y);
}

/// The stored payload of [h], as a `read` copy.
GeometryPayload payloadOf(DraftDocument doc, Handle h) =>
    doc.geometry.read(doc.entities.geomIndexAt(doc.entities.slotOf(h)!));

/// The codec's output: equal strings are a byte-identical document
/// (invariant 2).
String snapshot(DraftDocument doc) => DraftDocumentCodec.encodeToString(doc);

// ---- Task 7: the rig, the pointer, the layer ----------------------------

/// Everything a `SelectTool` grip test drives, wired in the shell's order:
/// the selection controller, then the outline cache, then the grip cache
/// (spec D6, Ruling 03-19). Object snap is off unless asked for, so a test
/// that is not about snapping lands on the raw pointer.
final class GripRig {
  GripRig(this.document, {CameraController? camera, bool objectSnap = false})
      : index = SpatialIndex(document),
        selection = SelectionController(document),
        camera = camera ?? gripCamera() {
    outlines = OutlineCache(document, selection);
    grips = GripCache(document, selection, outlines);
    snap = SnapSettings(objectSnap: objectSnap);
    page = PageNotifier(document);
    tool = SelectTool();
    context = ToolContext(
        document: document,
        index: index,
        camera: this.camera,
        selection: selection,
        page: page,
        snap: snap,
        grips: grips);
    tools = ToolController(initial: tool, context: context);
  }

  final DraftDocument document;
  final SpatialIndex index;
  final SelectionController selection;
  final CameraController camera;
  late final OutlineCache outlines;
  late final GripCache grips;
  late final SnapSettings snap;
  late final PageNotifier page;
  late final SelectTool tool;
  late final ToolContext context;
  late final ToolController tools;

  void dispose() {
    tools.dispose();
    grips.dispose();
    outlines.dispose();
    page.dispose();
    snap.dispose();
    camera.dispose();
    selection.dispose();
    index.dispose();
  }
}

GripRig gripRig(DraftDocument document,
    {CameraController? camera, bool objectSnap = false}) {
  final rig = GripRig(document, camera: camera, objectSnap: objectSnap);
  addTearDown(rig.dispose);
  return rig;
}

/// A pointer sample at [screen], resolved through [camera] exactly as
/// `InteractionLayer` does it.
ToolPointerEvent pointerAt(CameraController camera, Offset screen,
        {int buttons = kPrimaryButton, bool shift = false, int pointer = 1}) =>
    ToolPointerEvent(
      screen: screen,
      world: camera.value.screenToWorld(Vector2(screen.dx, screen.dy)),
      pointer: pointer,
      buttons: buttons,
      shift: shift,
      control: false,
      meta: false,
      alt: false,
      pickRadiusWorld: kPickRadiusPixels / camera.value.scale,
    );

/// Press at [from], then one move to [to]: past the slop in one event.
void pressAndMove(GripRig rig, Offset from, Offset to, {bool shift = false}) {
  rig.tool.onPointerDown(pointerAt(rig.camera, from, shift: shift), rig.context);
  rig.tool.onPointerMove(pointerAt(rig.camera, to, shift: shift), rig.context);
}

void release(GripRig rig, Offset at, {bool shift = false}) => rig.tool
    .onPointerUp(pointerAt(rig.camera, at, shift: shift, buttons: 0), rig.context);

void click(GripRig rig, Offset at, {bool shift = false}) {
  rig.tool.onPointerDown(pointerAt(rig.camera, at, shift: shift), rig.context);
  release(rig, at, shift: shift);
}

/// The layer's box under test, centred in the 800 × 600 surface so a drag
/// can leave it and stay on the surface (W2).
const Size kGripLayerSize = Size(600, 450);

/// Pumps an `InteractionLayer` over the canvas and the overlay, both driven
/// by [rig].
///
/// Teardown order: build [rig] (which registers its dispose) **before**
/// calling this. The empty pump registered here then runs first, while the
/// rig is still live.
Future<void> pumpGripLayer(WidgetTester tester, GripRig rig) async {
  addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
  await tester.pumpWidget(Directionality(
    textDirection: TextDirection.ltr,
    child: Center(
      child: SizedBox(
        width: kGripLayerSize.width,
        height: kGripLayerSize.height,
        child: InteractionLayer(
          tools: rig.tools,
          child: Stack(children: [
            RepaintBoundary(
              child: DraftCanvas(
                  document: rig.document, index: rig.index, camera: rig.camera),
            ),
            Positioned.fill(
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: SelectionOverlayPainter(
                    selection: rig.selection,
                    tools: rig.tools,
                    camera: rig.camera,
                    outlines: rig.outlines,
                    repaint: Listenable.merge([
                      rig.selection,
                      rig.tools,
                      rig.camera,
                      rig.outlines,
                      rig.grips,
                    ]),
                  ),
                  size: Size.infinite,
                ),
              ),
            ),
          ]),
        ),
      ),
    ),
  ));
  await tester.pump();
  expect(tester.getSize(find.byType(InteractionLayer)), kGripLayerSize,
      reason: 'a zero-sized layer would receive no pointer events');
}

/// [local] in the layer's box, in the surface's global coordinates.
Offset globalAt(WidgetTester tester, Offset local) =>
    tester.getTopLeft(find.byType(InteractionLayer)) + local;
```

- [ ] **Step 2: Write the failing tests.** In `test/select_tool_test.dart`,
  replace the test `'a 5 px move from empty space starts a band; from a hit
  it does not'`, whole, with the test below (Ruling 03-21). Also add `import
  'package:jet_cad_2d_flutter/src/grip_drag.dart' show DragKind;` to that
  file's imports.

```dart
  test(
      'a 5 px move from empty space starts a band; from an unselected hit it '
      'now selects and moves the object (spec 03 D12)', () {
    final doc = DraftDocument.empty();
    final line = addEntity(
        doc, doc.rootHandle, EntityKind.line, [990, 500, 1010, 500], []);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);
    final selection = SelectionController(doc);
    addTearDown(selection.dispose);
    final camera = cameraAt(2.0, const Offset(-1600, 1300));
    final ctx = ToolContext(
        document: doc, index: index, camera: camera, selection: selection);

    final fromEmpty = SelectTool();
    fromEmpty.onPointerDown(ev(camera, const Offset(50, 50)), ctx);
    fromEmpty.onPointerMove(ev(camera, const Offset(55, 50)), ctx);
    expect(fromEmpty.phase, ToolPhase.dragging);
    expect(fromEmpty.dragKind, DragKind.band);

    // 02 pinned "from a hit it does not" (select_tool.dart line 76). Spec 03
    // D12: past the slop, a press on an unselected body selects it and
    // moves the selection.
    final fromHit = SelectTool();
    fromHit.onPointerDown(ev(camera, const Offset(400, 300)), ctx);
    fromHit.onPointerMove(ev(camera, const Offset(405, 300)), ctx);
    expect(fromHit.phase, ToolPhase.dragging);
    expect(fromHit.dragKind, DragKind.move);
    expect(selection.keys, [SelectionKey.root(line)]);
    fromHit.cancel(ctx);
    expect(doc.commands.undoDepth, 1,
        reason: "only the fixture's own AddEntityCommand; the cancelled move "
            'dispatched nothing');
  });
```

Create `test/select_tool_drag_test.dart`:

```dart
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/gestures.dart' show PointerDeviceKind, kPrimaryButton;
import 'package:flutter/services.dart'
    show
        KeyDownEvent,
        KeyRepeatEvent,
        KeyUpEvent,
        LogicalKeyboardKey,
        PhysicalKeyboardKey,
        SystemMouseCursors;
import 'package:flutter/widgets.dart' show KeyEventResult, Offset, SizedBox;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/src/flutter_text_measurer.dart';
import 'package:jet_cad_2d_flutter/src/grip_cache.dart';
import 'package:jet_cad_2d_flutter/src/grip_drag.dart';
import 'package:jet_cad_2d_flutter/src/select_tool.dart';
import 'package:jet_cad_2d_flutter/src/selection.dart';
import 'package:jet_cad_2d_flutter/src/tool.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'support/grip_fixture.dart';
import 'support/selection_fixture.dart';

SelectionKey k(Handle h) => SelectionKey.root(h);

Vector2 worldOf(GripRig rig, Offset screen) =>
    rig.camera.value.screenToWorld(Vector2(screen.dx, screen.dy));

/// Every coordinate of [after] is [before]'s plus [delta] — a decision
/// about where geometry landed, so within `Tolerance` (spec D8).
void expectMovedBy(
    GeometryPayload after, GeometryPayload before, Vector2 delta) {
  for (var i = 0; i < before.coords.length; i += 2) {
    expect(after.coords[i], closeTo(before.coords[i] + delta.x, 1e-9));
    expect(after.coords[i + 1], closeTo(before.coords[i + 1] + delta.y, 1e-9));
  }
}

Vector2 rotatedAbout(double x, double y, Vector2 p, double theta) => Vector2(
    p.x + math.cos(theta) * (x - p.x) - math.sin(theta) * (y - p.y),
    p.y + math.sin(theta) * (x - p.x) + math.cos(theta) * (y - p.y));

double normalised(double a) => a > math.pi
    ? a - 2 * math.pi
    : (a <= -math.pi ? a + 2 * math.pi : a);

/// The line's body, 30% along: 38 world units from each end and 25 from
/// its midpoint, so no snap point is within the aperture.
const double bodyX = 7046, bodyY = 3032;

void main() {
  test('a click on a grip or on the rotation grip changes nothing (D12, '
      'M-03as); the cursor says what a press would do', () {
    final s = gripScene();
    final rig = gripRig(s.document);
    rig.selection.replace([k(s.line), k(s.polyline)]);
    final vertex = screenOf(rig.camera, 7130, 3060);

    rig.tool.onPointerMove(
        pointerAt(rig.camera, vertex, buttons: 0), rig.context);
    expect(rig.tool.cursor, SystemMouseCursors.precise);
    expect(rig.grips.hot, isNonNegative);

    rig.tool.onPointerDown(pointerAt(rig.camera, vertex), rig.context);
    expect(rig.tool.pressClass, PressClass.grip);
    release(rig, vertex);
    expect(rig.selection.keys, {k(s.line), k(s.polyline)},
        reason: '02 replace-selected the line here; a grip click does nothing');

    final rotation = rotationGripOf(
            rig.grips.box!, rig.camera.value.worldToScreenMatrix)
        .centre;
    rig.tool.onPointerMove(
        pointerAt(rig.camera, rotation, buttons: 0), rig.context);
    expect(rig.tool.cursor, SystemMouseCursors.grab);
    rig.tool.onPointerDown(pointerAt(rig.camera, rotation), rig.context);
    expect(rig.tool.pressClass, PressClass.rotationGrip);
    release(rig, rotation);
    expect(rig.selection.length, 2);

    rig.tool.onPointerMove(
        pointerAt(rig.camera, screenOf(rig.camera, bodyX, bodyY), buttons: 0),
        rig.context);
    expect(rig.tool.cursor, SystemMouseCursors.move);
    expect(rig.document.commands.undoDepth, 0);
  });

  test('a body drag moves the selection under a rotated camera (M-03a)', () {
    final s = gripScene();
    final rig = gripRig(s.document);
    expect(rig.camera.value.worldToScreenMatrix.b, isNot(closeTo(0, 1e-3)));
    expect(rig.camera.value.scale, isNot(closeTo(1, 1e-3)));
    rig.selection.replace([k(s.line)]);
    final before = payloadOf(rig.document, s.line);
    final from = screenOf(rig.camera, bodyX, bodyY);
    final to = from + const Offset(37, -21);
    pressAndMove(rig, from, to);
    expect(rig.tool.dragKind, DragKind.move);
    expect(rig.tool.cursor, SystemMouseCursors.move);
    release(rig, to);
    expectMovedBy(payloadOf(rig.document, s.line), before,
        worldOf(rig, to) - worldOf(rig, from));
  });

  test('no command during a drag; release adds exactly one Compound "Move" '
      '(M-03d, invariants 1 and 4)', () async {
    final s = gripScene();
    final rig = gripRig(s.document);
    final doc = rig.document;
    final labels = <String>[];
    final sub = doc.changes.listen((c) {
      if (c is CommandApplied) labels.add(c.label);
    });
    addTearDown(sub.cancel);
    rig.selection.replace([k(s.line), k(s.instA)]);
    final seed = doc.handleSeed.current;
    final live = doc.entities.liveCount;
    final from = screenOf(rig.camera, bodyX, bodyY);
    pressAndMove(rig, from, from + const Offset(20, 5));
    for (final step in const [Offset(30, 9), Offset(44, 12), Offset(51, 17)]) {
      rig.tool.onPointerMove(pointerAt(rig.camera, from + step), rig.context);
      expect(doc.commands.undoDepth, 0,
          reason: 'nothing is dispatched during a drag');
    }
    release(rig, from + const Offset(51, 17));
    expect(doc.commands.undoDepth, 1);
    await Future<void>.delayed(Duration.zero);
    expect(labels, ['Move']);
    expect(doc.handleSeed.current, seed, reason: 'invariant 4');
    expect(doc.entities.liveCount, live);
    expect(doc.tree[doc.rootHandle]!.transform.isIdentity, isTrue,
        reason: 'the root transform is never written');
  });

  test('a drag back to the press pixel, or snapped back onto its base, adds '
      'nothing (M-03p)', () {
    final s = gripScene();
    final rig = gripRig(s.document, objectSnap: true);
    rig.selection.replace([k(s.line)]);
    final from = screenOf(rig.camera, bodyX, bodyY);
    pressAndMove(rig, from, from + const Offset(40, 0));
    rig.tool.onPointerMove(pointerAt(rig.camera, from), rig.context);
    release(rig, from);
    expect(rig.document.commands.undoDepth, 0,
        reason: 'the same pixel under the same camera is a bit-identical '
            'world point, so Δ == 0');

    // 8 world units along the line from its start: 8.8 px, outside the grip
    // (7 px), inside the aperture (10 px). The base snaps onto the endpoint,
    // and a release 3 px from the endpoint snaps the target onto it too.
    final along = Vector2(7010, 3020) + Vector2(120, 40).normalized() * 8.0;
    final nearEnd = screenOf(rig.camera, along.x, along.y);
    pressAndMove(rig, nearEnd, nearEnd + const Offset(60, -30));
    expect(rig.tool.dragKind, DragKind.move);
    release(rig, screenOf(rig.camera, 7010, 3020) + const Offset(3, 0));
    expect(rig.document.commands.undoDepth, 0,
        reason: 'target == base: Δ is exactly zero');
  });

  test('with grid snap on, on-grid geometry stays on the grid (M-03s)', () {
    final s = gripScene(
        page: PageComponent(originX: 7000, originY: 3000, gridStepMm: 10));
    final rig = gripRig(s.document);
    rig.selection.replace([k(s.line)]);
    final from = screenOf(rig.camera, bodyX, bodyY);
    final to = from + const Offset(53, 29);
    pressAndMove(rig, from, to);
    release(rig, to);
    final after = payloadOf(rig.document, s.line);
    expect(after.coords[0], isNot(7010.0), reason: 'the line really moved');
    for (var i = 0; i < 4; i++) {
      final v = after.coords[i] - (i.isEven ? 7000 : 3000);
      expect(Tolerance.standard.isZero(v - (v / 10).roundToDouble() * 10),
          isTrue,
          reason: 'coordinate $i = ${after.coords[i]} left the 10 mm lattice');
    }
  });

  test('a shift-press-drag on an unselected object adds it and moves ortho '
      'in world axes (M-03f)', () {
    final s = gripScene();
    final rig = gripRig(s.document);
    rig.selection.replace([k(s.line)]);
    final line0 = payloadOf(rig.document, s.line);
    final poly0 = payloadOf(rig.document, s.polyline);
    final from = screenOf(rig.camera, 7025, 3115); // the polyline's body
    final to = screenOf(rig.camera, 7065, 3122);
    pressAndMove(rig, from, to, shift: true);
    expect(rig.selection.keys, {k(s.line), k(s.polyline)},
        reason: 'shift at the press toggles the object in (D2, class 3b)');
    release(rig, to, shift: true);
    final dx = worldOf(rig, to).x - worldOf(rig, from).x;
    for (final (after, before) in [
      (payloadOf(rig.document, s.line), line0),
      (payloadOf(rig.document, s.polyline), poly0),
    ]) {
      for (var i = 0; i < before.coords.length; i += 2) {
        expect(after.coords[i], closeTo(before.coords[i] + dx, 1e-9));
        expect(after.coords[i + 1], before.coords[i + 1],
            reason: 'shift during the drag is ortho: the minor world axis '
                'is pinned exactly');
      }
    }
  });

  test('a centre grip moves the whole selection from the grip itself '
      '(M-03at, Ruling 03-9)', () {
    final s = gripScene();
    final rig = gripRig(s.document);
    rig.selection.replace([k(s.circle), k(s.line)]);
    final circle0 = payloadOf(rig.document, s.circle);
    final line0 = payloadOf(rig.document, s.line);
    final centre = screenOf(rig.camera, 7300, 3250);
    final to = centre + const Offset(-31, 17);
    pressAndMove(rig, centre, to);
    expect(rig.tool.pressClass, PressClass.grip);
    expect(rig.tool.dragKind, DragKind.move);
    release(rig, to);
    final delta = worldOf(rig, to) - Vector2(7300, 3250);
    expectMovedBy(payloadOf(rig.document, s.circle), circle0, delta);
    expectMovedBy(payloadOf(rig.document, s.line), line0, delta);
    expect(payloadOf(rig.document, s.circle).scalars, [25]);
  });

  test('a stretch released near an endpoint lands on it exactly (M-03au)',
      () {
    final s = gripScene();
    final rig = gripRig(s.document, objectSnap: true);
    rig.selection.replace([k(s.line)]);
    final vertex = screenOf(rig.camera, 7130, 3060);
    final drop = screenOf(rig.camera, 7130, 3100) + const Offset(2, -3);
    pressAndMove(rig, vertex, drop);
    expect(rig.tool.dragKind, DragKind.reshape);
    expect(rig.tool.cursor, SystemMouseCursors.precise);
    release(rig, drop);
    final after = payloadOf(rig.document, s.line);
    expect([after.coords[2], after.coords[3]], [7130, 3100],
        reason: "== : the polyline's endpoint, exactly (spec D8)");
    expect([after.coords[0], after.coords[1]], [7010, 3020]);
  });

  test("coincident grips: the greater handle's end moves, the other object "
      'stays (M-03ai)', () {
    final s = gripScene();
    final doc = s.document;
    final wallA = addEntity(
        doc, doc.rootHandle, EntityKind.line, [7600, 3400, 7650, 3400], []);
    final wallB = addEntity(
        doc, doc.rootHandle, EntityKind.line, [7650, 3400, 7650, 3450], []);
    doc.commands.clearHistory();
    final rig = gripRig(doc, camera: gripCamera(centre: Vector2(7640, 3420)));
    rig.selection.replace([k(wallA), k(wallB)]);
    final corner = screenOf(rig.camera, 7650, 3400);
    pressAndMove(rig, corner, corner + const Offset(15, 20));
    release(rig, corner + const Offset(15, 20));
    expect(payloadOf(doc, wallA).coords, [7600, 3400, 7650, 3400]);
    final b = payloadOf(doc, wallB);
    expect(b.coords[0], isNot(7650.0));
    expect(b.coords.sublist(2), [7650, 3450]);
  });

  test('a rotation turns about the selection box centre, far from the '
      'origin (M-03j)', () {
    final s = gripScene();
    final rig = gripRig(s.document);
    rig.selection.replace([k(s.line)]);
    final before = payloadOf(rig.document, s.line);
    // The line's world box, by hand: (7010, 3020)–(7130, 3060).
    final pivot = Vector2(7070, 3040);
    final grip = rotationGripOf(
            rig.grips.box!, rig.camera.value.worldToScreenMatrix)
        .centre;
    final to = grip + const Offset(-45, 38);
    pressAndMove(rig, grip, to);
    expect(rig.tool.pressClass, PressClass.rotationGrip);
    expect(rig.tool.dragKind, DragKind.rotate);
    expect(rig.tool.cursor, SystemMouseCursors.grabbing);
    release(rig, to);
    final w0 = worldOf(rig, grip) - pivot;
    final w1 = worldOf(rig, to) - pivot;
    final theta =
        normalised(math.atan2(w1.y, w1.x) - math.atan2(w0.y, w0.x));
    final after = payloadOf(rig.document, s.line);
    for (var i = 0; i < 4; i += 2) {
      final r = rotatedAbout(before.coords[i], before.coords[i + 1], pivot, theta);
      expect(after.coords[i], closeTo(r.x, 1e-9));
      expect(after.coords[i + 1], closeTo(r.y, 1e-9));
    }
  });

  test('shift steps the rotation by 15° (M-03w)', () {
    final s = gripScene();
    final rig = gripRig(s.document);
    rig.selection.replace([k(s.line)]);
    final before = payloadOf(rig.document, s.line);
    final pivot = Vector2(7070, 3040);
    final grip = rotationGripOf(
            rig.grips.box!, rig.camera.value.worldToScreenMatrix)
        .centre;
    final w0 = worldOf(rig, grip) - pivot;
    final a0 = math.atan2(w0.y, w0.x);
    // 0.30 rad from the press: 15° steps round it to π/12; 30° steps would
    // round it to π/6.
    final aim = pivot + Vector2(math.cos(a0 + 0.30), math.sin(a0 + 0.30)) * 70;
    final to = screenOf(rig.camera, aim.x, aim.y);
    pressAndMove(rig, grip, to, shift: true);
    final t = rig.tool.selectionPreviewTransform!;
    expect(math.atan2(t.b, t.a), closeTo(math.pi / 12, 1e-12));
    release(rig, to, shift: true);
    final after = payloadOf(rig.document, s.line);
    for (var i = 0; i < 4; i += 2) {
      final r = rotatedAbout(
          before.coords[i], before.coords[i + 1], pivot, math.pi / 12);
      expect(after.coords[i], closeTo(r.x, 1e-9));
      expect(after.coords[i + 1], closeTo(r.y, 1e-9));
    }
  });

  test('permissions at press: no leaf grips, a refused move stays a click, '
      'an instance still moves (M-03ad, M-03av)', () {
    final s = gripScene();
    final rig = gripRig(s.document);
    final doc = rig.document;
    doc.commands.permissions = DraftPermissions.runtime;
    rig.selection.replace([k(s.line), k(s.instA)]);
    final vertex = screenOf(rig.camera, 7130, 3060);
    rig.tool.onPointerDown(pointerAt(rig.camera, vertex), rig.context);
    expect(rig.tool.pressClass, PressClass.selectedBody,
        reason: "no leaf grip is live, so the press lands on the line's body");
    final away = vertex + const Offset(30, 10);
    rig.tool.onPointerMove(pointerAt(rig.camera, away), rig.context);
    expect(rig.tool.phase, ToolPhase.pressed,
        reason: 'a move of a selection holding a leaf needs geometry; the '
            'press stays a click (Ruling 03-6)');
    release(rig, away);
    expect(rig.selection.keys, {k(s.line)},
        reason: 'released as a click: replace-select');
    expect(doc.commands.undoDepth, 0);

    rig.selection.replace([k(s.instA)]);
    final a0 = doc.tree[s.instA]! as InstanceNode;
    final body = a0.transform.transformPoint(Vector2(15, 5));
    final from = screenOf(rig.camera, body.x, body.y);
    final to = from + const Offset(-25, 14);
    pressAndMove(rig, from, to);
    release(rig, to);
    expect(doc.commands.undoDepth, 1,
        reason: 'runtime allows transform: a table moves, a wall cannot');
    final a1 = doc.tree[s.instA]! as InstanceNode;
    final delta = worldOf(rig, to) - worldOf(rig, from);
    expect(a1.transform.e, closeTo(a0.transform.e + delta.x, 1e-9));
    expect(a1.transform.f, closeTo(a0.transform.f + delta.y, 1e-9));
  });

  test('a camera change mid-drag re-resolves the target from the last '
      'screen point (M-03ac)', () {
    final s = gripScene();
    final rig = gripRig(s.document);
    rig.selection.replace([k(s.line)]);
    final from = screenOf(rig.camera, bodyX, bodyY);
    final to = from + const Offset(40, 25);
    final base = worldOf(rig, from);
    pressAndMove(rig, from, to);
    // A trackpad zoom about another point: no pointer event arrives.
    rig.camera.zoomAt(const Offset(10, 10), 1.5);
    final target = worldOf(rig, to);
    final t = rig.tool.selectionPreviewTransform!;
    expect(t.e, closeTo(target.x - base.x, 1e-9));
    expect(t.f, closeTo(target.y - base.y, 1e-9));
    release(rig, to);
    rig.camera.panBy(const Offset(7, 7));
    expect(rig.tool.selectionPreviewTransform, isNull,
        reason: 'the listener left with the drag (Ruling 03-7)');
  });

  test("every key-down and repeat is the drag's; Escape cancels "
      'byte-identically (M-03aa, M-03l)', () {
    final s = gripScene();
    final rig = gripRig(s.document);
    rig.selection.replace([k(s.line), k(s.instA)]);
    final bytes = snapshot(rig.document);
    final from = screenOf(rig.camera, bodyX, bodyY);
    pressAndMove(rig, from, from + const Offset(40, 25));
    const zDown = KeyDownEvent(
        physicalKey: PhysicalKeyboardKey.keyZ,
        logicalKey: LogicalKeyboardKey.keyZ,
        timeStamp: Duration.zero);
    const zRepeat = KeyRepeatEvent(
        physicalKey: PhysicalKeyboardKey.keyZ,
        logicalKey: LogicalKeyboardKey.keyZ,
        timeStamp: Duration.zero);
    const zUp = KeyUpEvent(
        physicalKey: PhysicalKeyboardKey.keyZ,
        logicalKey: LogicalKeyboardKey.keyZ,
        timeStamp: Duration.zero);
    expect(rig.tool.onKey(zDown, rig.context), KeyEventResult.handled);
    expect(rig.tool.onKey(zRepeat, rig.context), KeyEventResult.handled,
        reason: 'Ruling 03-8: a held cmd+Z repeats');
    expect(rig.tool.onKey(zUp, rig.context), KeyEventResult.ignored);
    expect(rig.tool.phase, ToolPhase.dragging);
    const escape = KeyDownEvent(
        physicalKey: PhysicalKeyboardKey.escape,
        logicalKey: LogicalKeyboardKey.escape,
        timeStamp: Duration.zero);
    expect(rig.tool.onKey(escape, rig.context), KeyEventResult.handled);
    expect(rig.tool.phase, ToolPhase.idle);
    expect(snapshot(rig.document), bytes);
    expect(rig.document.commands.undoDepth, 0);
    expect(rig.selection.length, 2,
        reason: 'Escape during a drag cancels the drag, not the selection');
  });

  test('tool activation cancels a drag byte-identically (M-03ao)', () {
    final s = gripScene();
    final rig = gripRig(s.document);
    rig.selection.replace([k(s.line)]);
    final bytes = snapshot(rig.document);
    final from = screenOf(rig.camera, bodyX, bodyY);
    pressAndMove(rig, from, from + const Offset(40, 25));
    final other = SelectTool();
    addTearDown(other.dispose);
    rig.tools.activate(other);
    expect(rig.tool.phase, ToolPhase.idle);
    expect(snapshot(rig.document), bytes);
    rig.tools.activate(rig.tool);
  });

  test('a document change mid-drag: release dispatches nothing (M-03t)', () {
    final s = gripScene();
    final rig = gripRig(s.document);
    rig.selection.replace([k(s.line)]);
    final from = screenOf(rig.camera, bodyX, bodyY);
    final to = from + const Offset(40, 25);
    pressAndMove(rig, from, to);
    final edited = GeometryPayload(
        coords: Float64List.fromList([7010, 3020, 7140, 3080]),
        scalars: Float64List(0));
    rig.document.commands.execute(SetEntityGeometryCommand(s.line, edited));
    release(rig, to);
    expect(rig.document.commands.undoDepth, 1, reason: 'the external edit only');
    expect(payloadOf(rig.document, s.line), edited);
  });

  testWidgets('a pointer cancel leaves the document byte-identical (M-03ao)',
      (tester) async {
    final measurer = FlutterTextMeasurer();
    addTearDown(measurer.clear);
    final s = gripScene(measurer: measurer);
    final rig = gripRig(s.document,
        camera: gripCamera(viewport: kGripLayerSize, centre: Vector2(7070, 3040)));
    await pumpGripLayer(tester, rig);
    rig.selection.replace([k(s.line)]);
    await tester.pump();
    final bytes = snapshot(rig.document);
    final gesture = await tester.createGesture(
        kind: PointerDeviceKind.mouse, buttons: kPrimaryButton);
    final from = globalAt(tester, screenOf(rig.camera, bodyX, bodyY));
    await gesture.down(from);
    await gesture.moveTo(from + const Offset(30, 20));
    expect(rig.tool.dragKind, DragKind.move);
    await gesture.cancel();
    await tester.pump();
    expect(rig.tool.phase, ToolPhase.idle);
    expect(snapshot(rig.document), bytes);
  });

  testWidgets("a move dragged past the layer's edge continues and lands "
      '(M-03ap)', (tester) async {
    final measurer = FlutterTextMeasurer();
    addTearDown(measurer.clear);
    final s = gripScene(measurer: measurer);
    final rig = gripRig(s.document,
        camera: gripCamera(viewport: kGripLayerSize, centre: Vector2(7070, 3040)));
    await pumpGripLayer(tester, rig);
    rig.selection.replace([k(s.line)]);
    await tester.pump();
    final before = payloadOf(rig.document, s.line);
    final fromLocal = screenOf(rig.camera, bodyX, bodyY);
    final outside = Offset(kGripLayerSize.width + 50, fromLocal.dy);
    final gesture = await tester.createGesture(
        kind: PointerDeviceKind.mouse, buttons: kPrimaryButton);
    await gesture.down(globalAt(tester, fromLocal));
    await gesture.moveTo(globalAt(tester, fromLocal + const Offset(30, 0)));
    await gesture.moveTo(globalAt(tester, outside));
    await tester.pump();
    expect(rig.tool.dragKind, DragKind.move,
        reason: 'pointer exit is not a cancel path (spec D5, 02 amended)');
    await gesture.up();
    await tester.pump();
    expectMovedBy(payloadOf(rig.document, s.line), before,
        worldOf(rig, outside) - worldOf(rig, fromLocal));
  });

  testWidgets('removing the layer mid-drag cancels byte-identically (M-03ao)',
      (tester) async {
    final measurer = FlutterTextMeasurer();
    addTearDown(measurer.clear);
    final s = gripScene(measurer: measurer);
    final rig = gripRig(s.document,
        camera: gripCamera(viewport: kGripLayerSize, centre: Vector2(7070, 3040)));
    await pumpGripLayer(tester, rig);
    rig.selection.replace([k(s.line)]);
    await tester.pump();
    final bytes = snapshot(rig.document);
    final gesture = await tester.createGesture(
        kind: PointerDeviceKind.mouse, buttons: kPrimaryButton);
    final from = globalAt(tester, screenOf(rig.camera, bodyX, bodyY));
    await gesture.down(from);
    await gesture.moveTo(from + const Offset(30, 20));
    expect(rig.tool.dragKind, DragKind.move);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(rig.tool.phase, ToolPhase.idle,
        reason: "the layer's deactivate/dispose cancels the tool");
    expect(snapshot(rig.document), bytes);
    // The captured pointer's up still reaches the unmounted layer's
    // Listener callback; the idle tool ignores it.
    await gesture.up();
  });
}
```

- [ ] **Step 3: Run them to fail.** `CI=true flutter test
  test/select_tool_drag_test.dart test/select_tool_test.dart` → compile
  errors: `PressClass`, `pressClass` and `dragKind` are undefined on
  `SelectTool`.

- [ ] **Step 4: Implement.** In `lib/src/select_tool.dart`, make three
  edits. Line numbers are at the branch point.
  - **Replace lines 1–109** (the imports through `onPointerUp`'s closing
    brace) with block A below.
  - **Keep lines 111–194 unchanged** (`_bandKeys`, `_everyLeafIn`,
    `_topmostGroup`).
  - **Replace lines 196–236** (`_reset` through `onKey`) with block B.
  - **Keep lines 238–386 unchanged** (`_deleteSelection`, `_groupCascade`,
    `paintOverlay`, `_drawDashedRect`). `paintOverlay` reads `bandScreen`,
    which now answers only for a band.

Block A:

```dart
import 'dart:math' as math;
import 'dart:ui' show Canvas, Offset, Paint, Path, PaintingStyle, Rect, Size;

import 'package:flutter/services.dart'
    show
        KeyDownEvent,
        KeyEvent,
        KeyRepeatEvent,
        LogicalKeyboardKey,
        MouseCursor,
        SystemMouseCursors;
import 'package:flutter/widgets.dart' show KeyEventResult;
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'grip_drag.dart';
import 'selection.dart';
import 'selection_style.dart';
import 'tool.dart';
import 'viewport_transform.dart';

/// A press that moves less than this many screen pixels stays a click
/// (M-02f); past it, a press becomes the drag its class names (spec 03 D2).
const double kBandSlopPixels = 4.0;

/// What a press landed on (spec 03 D2). The first class that hits wins.
enum PressClass { rotationGrip, grip, selectedBody, unselectedBody, empty }

/// Hover, click, shift-click and rubber-band selection (spec 02 D1, D2, D7,
/// D8), Escape and Delete/Backspace (02 D3, D10) — and, since 03, grips:
/// - press classes;
/// - move, rotate and reshape drags with object and grid snap;
/// - one command on release (spec 03 D2, D4, D5).
class SelectTool extends Tool {
  SelectTool();

  @override
  String get name => 'Select';
  ToolPhase _phase = ToolPhase.idle;
  @override
  ToolPhase get phase => _phase;

  final HitPath _hit = HitPath();
  Offset _start = Offset.zero;
  final Vector2 _pressWorld = Vector2.zero();
  bool _pressShift = false;
  PressClass _class = PressClass.empty;
  SelectionKey? _downKey;
  int _pressGrip = -1;

  /// Set when a drag was refused at the slop (Ruling 03-6): the press stays
  /// a click, and later moves do nothing.
  bool _clickOnly = false;
  Offset _end = Offset.zero;
  BandMode? _bandMode;
  int _pointer = -1;

  DragKind? _dragKind;
  GripDrag? _drag;
  ToolContext? _dragCtx;
  Offset _lastScreen = Offset.zero;
  bool _lastShift = false;
  final DragPoint _dragPoint = DragPoint();
  final SnapResult _snapScratch = SnapResult();
  MouseCursor _cursor = MouseCursor.defer;

  /// What the press landed on; null while idle.
  PressClass? get pressClass => _phase == ToolPhase.idle ? null : _class;

  /// The live drag's kind; null unless dragging.
  DragKind? get dragKind => _phase == ToolPhase.dragging ? _dragKind : null;

  /// Non-null only while a band drag is in progress, for the overlay.
  BandMode? get bandMode => dragKind == DragKind.band ? _bandMode : null;

  /// The band rectangle in screen space, for the overlay test.
  Rect? get bandScreen =>
      dragKind == DragKind.band ? Rect.fromPoints(_start, _end) : null;

  /// The band's drag-start corner, for the overlay.
  Offset? get bandStart => dragKind == DragKind.band ? _start : null;

  @override
  MouseCursor get cursor => _cursor;

  @override
  Transform2? get selectionPreviewTransform {
    final kind = dragKind;
    return kind == DragKind.move || kind == DragKind.rotate
        ? _drag?.transform
        : null;
  }

  SelectionKey? _pick(ToolPointerEvent e, ToolContext ctx) {
    if (!ctx.index.pickInto(
        e.world, e.pickRadiusWorld, const QueryFilter.picking(), _hit)) {
      return null;
    }
    return resolveHit(_hit, ctx.document);
  }

  @override
  void onPointerDown(ToolPointerEvent e, ToolContext ctx) {
    if (_phase != ToolPhase.idle) return;
    _phase = ToolPhase.pressed;
    _pointer = e.pointer;
    _start = e.screen;
    _pressWorld.setFrom(e.world);
    _pressShift = e.shift;
    _class = _classify(e, ctx);
    notifyListeners();
  }

  /// Spec D2: the rotation grip, then a grip, then the single pick
  /// (selected or not), then empty space.
  PressClass _classify(ToolPointerEvent e, ToolContext ctx) {
    _downKey = null;
    _pressGrip = -1;
    final grips = ctx.grips;
    if (grips != null) {
      final m = ctx.camera.value.worldToScreenMatrix;
      if (grips.hitsRotationGrip(e.screen, m)) return PressClass.rotationGrip;
      final i = grips.hitTest(e.screen, m);
      if (i >= 0) {
        _pressGrip = i;
        return PressClass.grip;
      }
    }
    final key = _pick(e, ctx);
    _downKey = key;
    if (key == null) return PressClass.empty;
    // The single pick decides: an unselected object drawn above a selected
    // one wins the press, exactly as it wins a click in 02.
    return ctx.selection.contains(key)
        ? PressClass.selectedBody
        : PressClass.unselectedBody;
  }

  @override
  void onPointerMove(ToolPointerEvent e, ToolContext ctx) {
    switch (_phase) {
      case ToolPhase.idle:
        if (e.buttons != 0) return;
        _hoverAt(e, ctx);
      case ToolPhase.pressed:
        if (e.pointer != _pointer || _clickOnly) return;
        if ((e.screen - _start).distance < kBandSlopPixels) return;
        _beginDrag(e, ctx);
      case ToolPhase.dragging:
        if (e.pointer != _pointer) return;
        if (_dragKind == DragKind.band) {
          _end = e.screen;
          _bandMode =
              _end.dx >= _start.dx ? BandMode.window : BandMode.crossing;
        } else {
          _follow(e, ctx);
        }
        notifyListeners();
    }
  }

  /// 02's object hover, plus the hot grip and the cursor (spec 03 D5).
  /// Notifies only when the cursor or the hot grip changed.
  void _hoverAt(ToolPointerEvent e, ToolContext ctx) {
    final key = _pick(e, ctx);
    ctx.selection.setHover(key);
    var cursor = MouseCursor.defer;
    var hot = -1;
    final grips = ctx.grips;
    if (grips != null) {
      final m = ctx.camera.value.worldToScreenMatrix;
      if (grips.hitsRotationGrip(e.screen, m)) {
        cursor = SystemMouseCursors.grab;
      } else {
        hot = grips.hitTest(e.screen, m);
        if (hot >= 0) cursor = SystemMouseCursors.precise;
      }
    }
    if (cursor == MouseCursor.defer &&
        key != null &&
        ctx.selection.contains(key)) {
      cursor = SystemMouseCursors.move;
    }
    final hotChanged = grips != null && grips.hot != hot;
    if (grips != null) grips.hot = hot;
    if (cursor == _cursor && !hotChanged) return;
    _cursor = cursor;
    notifyListeners();
  }

  /// Spec D2, past the slop. A drag whose capability is refused never
  /// starts; the press stays a click (Ruling 03-6).
  void _beginDrag(ToolPointerEvent e, ToolContext ctx) {
    switch (_class) {
      case PressClass.empty:
        _phase = ToolPhase.dragging;
        _dragKind = DragKind.band;
        ctx.selection.setHover(null);
        _end = e.screen;
        _bandMode = _end.dx >= _start.dx ? BandMode.window : BandMode.crossing;
        notifyListeners();
      case PressClass.selectedBody:
        final drag = GripDrag.move(ctx.document, ctx.selection.keys);
        if (!_permitted(drag, ctx)) {
          _clickOnly = true;
          return;
        }
        _moveBase(ctx, drag!);
        _enter(drag, e, ctx);
      case PressClass.unselectedBody:
        final key = _downKey!;
        final next = _pressShift
            ? <SelectionKey>{...ctx.selection.keys, key}
            : <SelectionKey>{key};
        final drag = GripDrag.move(ctx.document, next);
        if (!_permitted(drag, ctx)) {
          _clickOnly = true;
          return;
        }
        // Class 3b: select (shift at the press toggles in), then move. The
        // selection change is selection state; it stands after a cancel.
        _pressShift ? ctx.selection.toggle([key]) : ctx.selection.replace([key]);
        _moveBase(ctx, drag!);
        _enter(drag, e, ctx);
      case PressClass.grip:
        final grips = ctx.grips!;
        final ref = grips.grips[_pressGrip];
        // Ruling 03-9: a centre grip moves the whole selection.
        final drag = ref.grip.role == GripRole.move
            ? GripDrag.move(ctx.document, ctx.selection.keys)
            : GripDrag.reshape(ctx.document, ref.key, ref.grip);
        if (!_permitted(drag, ctx)) {
          _clickOnly = true;
          return;
        }
        // Spec D8: a grip's base is the grip's own world point, exactly.
        drag!.base.setValues(ref.grip.x, ref.grip.y);
        grips.hot = _pressGrip;
        _enter(drag, e, ctx);
      case PressClass.rotationGrip:
        final box = ctx.grips!.box!;
        final pivot =
            Vector2((box.minX + box.maxX) / 2, (box.minY + box.maxY) / 2);
        final drag = GripDrag.rotate(
            ctx.document, ctx.selection.keys, pivot, _pressWorld);
        if (!_permitted(drag, ctx)) {
          _clickOnly = true;
          return;
        }
        _enter(drag!, e, ctx);
    }
  }

  /// Spec D2: a drag needs its capability before it starts.
  static bool _permitted(GripDrag? drag, ToolContext ctx) =>
      drag != null && drag.permittedBy(ctx.document.commands.permissions);

  /// Spec D8: a body drag's base is the press point, resolved by the same
  /// chain as the target but without ortho. With grid snap on, a move from
  /// on-grid geometry is then a lattice vector (M-03s).
  void _moveBase(ToolContext ctx, GripDrag drag) {
    _resolve(ctx, _pressWorld, null);
    drag.base.setFrom(_dragPoint.point);
  }

  void _enter(GripDrag drag, ToolPointerEvent e, ToolContext ctx) {
    _drag = drag;
    _dragKind = drag.kind;
    _dragCtx = ctx;
    _phase = ToolPhase.dragging;
    ctx.selection.setHover(null);
    // Ruling 03-7: a trackpad zoom or a middle-button pan moves the camera
    // with no pointer event; the target follows from the last screen point.
    ctx.camera.addListener(_onCamera);
    _cursor = switch (drag.kind) {
      DragKind.move => SystemMouseCursors.move,
      DragKind.rotate => SystemMouseCursors.grabbing,
      DragKind.reshape || DragKind.band => SystemMouseCursors.precise,
    };
    _follow(e, ctx);
    notifyListeners();
  }

  /// Spec D5: world from screen, every event — `e.world` is the layer's
  /// inverse camera at this event, never a scaled screen delta.
  void _follow(ToolPointerEvent e, ToolContext ctx) {
    _lastScreen = e.screen;
    _lastShift = e.shift;
    _retarget(ctx, e.world, e.shift);
  }

  void _retarget(ToolContext ctx, Vector2 world, bool shift) {
    final drag = _drag!;
    if (drag.kind == DragKind.rotate) {
      // Spec D8: a rotate snaps to nothing; shift steps it by 15°.
      drag.rotateTo(world, step: shift);
      return;
    }
    _resolve(ctx, world, shift ? drag.base : null);
    drag.moveTo(_dragPoint.point);
  }

  void _resolve(ToolContext ctx, Vector2 raw, Vector2? orthoBase) {
    final cam = ctx.camera.value;
    final page = ctx.page?.value;
    resolveDragPoint(
      raw: raw,
      orthoBase: orthoBase,
      index: ctx.index,
      apertureWorld: kSnapAperturePixels / cam.scale,
      objectSnap: ctx.snap?.objectSnap ?? true,
      page: page,
      gridStepMm: dragGridStepMm(page, cam.scale),
      scratch: _snapScratch,
      out: _dragPoint,
    );
  }

  void _onCamera() {
    final ctx = _dragCtx;
    if (ctx == null || _drag == null) return;
    final world = ctx.camera.value
        .screenToWorld(Vector2(_lastScreen.dx, _lastScreen.dy));
    _retarget(ctx, world, _lastShift);
    notifyListeners();
  }

  @override
  void onPointerUp(ToolPointerEvent e, ToolContext ctx) {
    if (e.pointer != _pointer) return;
    switch (_phase) {
      case ToolPhase.idle:
        return;
      case ToolPhase.pressed:
        // A press that never left the slop is a click. On a grip or on the
        // rotation grip it does nothing (spec 03 D2, D12).
        switch (_class) {
          case PressClass.selectedBody:
          case PressClass.unselectedBody:
            final key = _downKey!;
            e.shift
                ? ctx.selection.toggle([key])
                : ctx.selection.replace([key]);
          case PressClass.empty:
            if (!e.shift) ctx.selection.clear();
          case PressClass.grip:
          case PressClass.rotationGrip:
            break;
        }
      case ToolPhase.dragging:
        if (_dragKind == DragKind.band) {
          final keys = _bandKeys(ctx, e);
          e.shift ? ctx.selection.toggle(keys) : ctx.selection.replace(keys);
        } else {
          // Ruling 03-13: the up carries the final position.
          _follow(e, ctx);
          final command = _drag!.command(ctx.document.commands.permissions);
          _endDrag(ctx);
          _reset();
          notifyListeners();
          // Spec D4: one command or none — never one per move
          // (invariant 1).
          if (command != null) ctx.execute(command);
          return;
        }
    }
    _reset();
    notifyListeners();
  }
```

Block B:

```dart
  void _reset() {
    _phase = ToolPhase.idle;
    _pointer = -1;
    _class = PressClass.empty;
    _downKey = null;
    _pressGrip = -1;
    _clickOnly = false;
    _bandMode = null;
    _dragKind = null;
  }

  /// The single way out of a move, rotate or reshape (Ruling 03-7).
  void _endDrag(ToolContext ctx) {
    if (_drag == null) return;
    (_dragCtx ?? ctx).camera.removeListener(_onCamera);
    ctx.grips?.hot = -1;
    _drag = null;
    _dragCtx = null;
    _dragPoint.reset();
    _cursor = MouseCursor.defer;
  }

  @override
  void onPointerExit(ToolContext ctx) {
    ctx.selection.setHover(null);
    if (_phase == ToolPhase.dragging) cancel(ctx);
  }

  /// Every cancel path — Escape, pointer cancel, `ToolController.activate`,
  /// the layer's deactivate/dispose — leaves the document byte-identical
  /// (spec D5, invariant 2). A selection change made at drag start stands.
  @override
  void cancel(ToolContext ctx) {
    if (_phase == ToolPhase.idle) return;
    _endDrag(ctx);
    _reset();
    notifyListeners();
  }

  @override
  KeyEventResult onKey(KeyEvent event, ToolContext ctx) {
    if (_phase == ToolPhase.dragging &&
        (event is KeyDownEvent || event is KeyRepeatEvent)) {
      if (event is KeyDownEvent &&
          event.logicalKey == LogicalKeyboardKey.escape) {
        cancel(ctx);
      }
      // Spec D5 and Ruling 03-8: every key-down and repeat is the drag's,
      // so the shell's cmd+Z never lands mid-drag.
      return KeyEventResult.handled;
    }
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape) {
      if (_phase == ToolPhase.idle) ctx.selection.clear();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.delete ||
        key == LogicalKeyboardKey.backspace) {
      if (_phase != ToolPhase.idle) return KeyEventResult.ignored;
      _deleteSelection(ctx);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }
```

- [ ] **Step 5: Run them to pass.** `CI=true flutter test
  test/select_tool_drag_test.dart test/select_tool_test.dart
  test/interaction_layer_test.dart test/selection_overlay_test.dart` → all
  tests pass. Then run the `jet_cad_2d_flutter` gate line: only the five
  goldens fail. If any other 02 test goes red, stop and report it. It is
  either a D12 change the plan missed, or a defect.
- [ ] **Step 6: Commit.**

```bash
git add packages/jet_cad_2d_flutter/lib/src/select_tool.dart packages/jet_cad_2d_flutter/test/support/grip_fixture.dart packages/jet_cad_2d_flutter/test/select_tool_test.dart packages/jet_cad_2d_flutter/test/select_tool_drag_test.dart
git commit -m "$(cat <<'EOF'
feat(render): SelectTool drags -- press classes, move, rotate, reshape

Spec 03 D2, D5, D8, D12: the four press classes and the capability check
before a drag starts; body and centre-grip moves, the rotation grip about
the box centre with 15 degree shift steps, grip reshapes; world from screen
every event, a camera listener for zooms mid-drag; every key-down and repeat
consumed while dragging; one command on release, none on any cancel path.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

---
### Task 8: The overlay — grips, the rotation grip, the preview, the reshape path, snap markers

**Files:**
- Create: `lib/src/snap_marker.dart`
- Modify: `lib/src/selection_overlay.dart` (replaced whole; text below)
- Modify: `lib/src/select_tool.dart` (paint members; the Task 7 file plus
  the edits below)
- Modify: `lib/jet_cad_2d_flutter.dart`: add `export
  'src/snap_marker.dart';` before `src/snap_settings.dart`.
- Test: `test/snap_marker_test.dart` (K1),
  `test/selection_overlay_grips_test.dart` (P1, P2, P4, P5, P6, P8)

**Interfaces:**
- Consumes:
  - `GripCache` (`grips`, `stretchCount`, `moveCount`, `hot`, `box`,
    `rotatable`, `leafGripsLive`) and `rotationGripOf` (Task 4);
  - `Tool.paintWorldOverlay` and `selectionPreviewTransform` (Task 5);
  - `SelectTool`'s `_drag`, `_dragPoint` and `_lastScreen` (Task 7);
  - `GripDrag.base`, `target`, `previewPayload` and `leafKind` (Task 6).
- Produces:
  - `void drawSnapMarker(Canvas canvas, Offset at, SnapKind? kind, {required bool grid, required Paint paint})`
  - `SelectionOverlayPainter` paints, in order:
    1. the rebased world pass: outlines, then `tool.paintWorldOverlay`;
    2. the preview pass through `worldToScreen ∘ T ∘ translate(origin)`;
    3. the screen pass: point crosses, preview crosses at `T(p)`, grips
       (`drawRawPoints`), the hot grip, the rotation grip, then
       `tool.paintOverlay`.
  - `SelectTool.paintOverlay` draws the guide line and the marker during a
    move, rotate or reshape. `SelectTool.paintWorldOverlay` draws the
    reshape preview path.

- [ ] **Step 1: Write the failing tests.**

```dart
// test/snap_marker_test.dart
import 'dart:ui' show Offset, Paint, Path, Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart' show SnapKind;
import 'package:jet_cad_2d_flutter/src/snap_marker.dart';

import 'support/spy_canvas.dart';

void main() {
  test('each snap kind draws its own marker; the raw point draws nothing '
      '(spec D9, M-03ag)', () {
    const at = Offset(300, 200);
    final paint = Paint();
    List<RecordedCall> draw(SnapKind? kind, {bool grid = false}) {
      final spy = SpyCanvas();
      drawSnapMarker(spy, at, kind, grid: grid, paint: paint);
      return spy.calls;
    }

    List<String> names(List<RecordedCall> calls) =>
        [for (final c in calls) c.name];

    final endpoint = draw(SnapKind.endpoint);
    expect(names(endpoint), ['drawRect']);
    expect(endpoint.single.args[0],
        Rect.fromCenter(center: at, width: 10, height: 10));

    final midpoint = draw(SnapKind.midpoint);
    expect(names(midpoint), ['drawPath']);
    final triangle = midpoint.single.args[0] as Path;
    expect(triangle.contains(at + const Offset(0, 4)), isTrue,
        reason: 'the base is at the bottom');
    expect(triangle.contains(at + const Offset(-4, -4)), isFalse,
        reason: 'apex up: the top corners are outside');

    final center = draw(SnapKind.center);
    expect(names(center), ['drawCircle']);
    expect(center.single.args[1], 5.0);

    final quadrant = draw(SnapKind.quadrant);
    expect(names(quadrant), ['drawPath']);
    final diamond = quadrant.single.args[0] as Path;
    expect(diamond.contains(at), isTrue);
    expect(diamond.contains(at + const Offset(4, 4)), isFalse);

    expect(names(draw(SnapKind.insertion)), ['drawRect', 'drawLine', 'drawLine']);

    final x = draw(SnapKind.intersection);
    expect(names(x), ['drawLine', 'drawLine']);
    expect(x[0].args[0], at + const Offset(-5, -5));
    expect(x[0].args[1], at + const Offset(5, 5));

    final grid = draw(null, grid: true);
    expect(names(grid), ['drawLine', 'drawLine']);
    expect(((grid[0].args[1] as Offset) - (grid[0].args[0] as Offset)).distance,
        6.0);

    expect(draw(null), isEmpty, reason: 'nothing when the raw point won');
    for (final kind in [
      SnapKind.perpendicular,
      SnapKind.tangent,
      SnapKind.nearest,
    ]) {
      expect(draw(kind), isEmpty, reason: '${kind.name} is not in kDragSnapMask');
    }
  });
}
```

```dart
// test/selection_overlay_grips_test.dart
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Offset, Paint, Path, PointMode, Rect, Size, StrokeCap;

import 'package:flutter/widgets.dart' show Listenable;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/src/camera_controller.dart'
    show rebaseOriginFor;
import 'package:jet_cad_2d_flutter/src/grip_cache.dart';
import 'package:jet_cad_2d_flutter/src/grip_drag.dart';
import 'package:jet_cad_2d_flutter/src/selection.dart';
import 'package:jet_cad_2d_flutter/src/selection_overlay.dart';
import 'package:jet_cad_2d_flutter/src/selection_style.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'support/grip_fixture.dart';
import 'support/selection_fixture.dart';
import 'support/spy_canvas.dart';

const Size kView = Size(800, 600);

SelectionKey k(Handle h) => SelectionKey.root(h);

SelectionOverlayPainter overlayOf(GripRig rig) => SelectionOverlayPainter(
      selection: rig.selection,
      tools: rig.tools,
      camera: rig.camera,
      outlines: rig.outlines,
      repaint: Listenable.merge(
          [rig.selection, rig.tools, rig.camera, rig.outlines, rig.grips]),
    );

/// `(x, y)` mapped through a recorded column-major 4x4.
Offset through(Float64List m, double x, double y) =>
    Offset(m[0] * x + m[4] * y + m[12], m[1] * x + m[5] * y + m[13]);

Offset rotationGripCentre(GripRig rig) =>
    rotationGripOf(rig.grips.box!, rig.camera.value.worldToScreenMatrix)
        .centre;

void main() {
  test('the move/rotate preview is drawn through worldToScreen ∘ T ∘ '
      'translate(origin) (M-03u)', () {
    final s = gripScene();
    final rig = gripRig(s.document);
    rig.selection.replace([k(s.line)]);
    final grip = rotationGripCentre(rig);
    pressAndMove(rig, grip, grip + const Offset(-45, 38));
    final t = rig.tool.selectionPreviewTransform!;
    expect(t.b.abs(), greaterThan(1e-3),
        reason: 'a rotation: a translation commutes with the rebase and '
            'could not tell the two orders apart');
    final spy = SpyCanvas();
    overlayOf(rig).paint(spy, kView);
    final origin = rebaseOriginFor(rig.camera.value.visibleWorld(kView));
    expect(origin.x, isNot(0.0), reason: 'the rebase origin is non-zero');
    final transforms = spy.named('transform').toList();
    expect(transforms, hasLength(2),
        reason: 'the outline pass, then the preview pass');
    final preview = Float64List.fromList(transforms[1].args[0] as Float64List);
    for (final (x, y) in const [(7010.0, 3020.0), (7130.0, 3060.0)]) {
      final expected =
          rig.camera.value.worldToScreen(t.transformPoint(Vector2(x, y)));
      final got = through(preview, x - origin.x, y - origin.y);
      expect(got.dx, closeTo(expected.x, 1e-6));
      expect(got.dy, closeTo(expected.y, 1e-6));
    }
    expect(spy.named('drawPath').where((c) => c.color == kPreviewColor),
        hasLength(1));
  });

  test('grips are one drawRawPoints per colour at 10 grips and at 300, and '
      'the hot grip one more (invariant 6, M-03v, M-03aq)', () {
    (List<RecordedCall>, GripRig) frame(int vertices, {int hot = -1}) {
      final doc = DraftDocument.empty();
      final poly = addEntity(doc, doc.rootHandle, EntityKind.polyline, [
        for (var i = 0; i < vertices; i++)
          ...[7000.0 + i * 0.5, i.isEven ? 3000.0 : 3002.0],
      ], []);
      final circle =
          addEntity(doc, doc.rootHandle, EntityKind.circle, [7060, 3030], [8]);
      final rig = gripRig(doc, camera: gripCamera(centre: Vector2(7050, 3010)));
      rig.selection.replace([k(poly), k(circle)]);
      rig.grips.hot = hot;
      final spy = SpyCanvas();
      overlayOf(rig).paint(spy, kView);
      return (spy.calls, rig);
    }

    List<String> names(List<RecordedCall> calls) =>
        [for (final c in calls) c.name];
    final (small, _) = frame(5); // 5 vertices + 5 circle grips = 10
    final (large, _) = frame(295); // 295 + 5 = 300
    expect(names(large), names(small),
        reason: 'the draw calls do not depend on the grip count');
    expect(names(large), isNot(contains('drawRect')));
    final raw = [
      for (final c in large)
        if (c.name == 'drawRawPoints') c,
    ];
    expect(raw, hasLength(2));
    expect(raw[0].args[0], PointMode.points);
    expect((raw[0].args[1] as Float32List).length, 2 * 299,
        reason: 'the stretch and radius grips');
    expect(raw[0].color, kGripColor);
    expect(raw[0].strokeWidth, kGripPixels);
    expect((raw[0].args[2] as Paint).strokeCap, StrokeCap.square);
    expect((raw[1].args[1] as Float32List).length, 2, reason: 'one centre');
    expect(raw[1].color, kGripMoveColor);

    final (hot, rig) = frame(5, hot: 2);
    final hotCalls = [
      for (final c in hot)
        if (c.name == 'drawRawPoints') c,
    ];
    expect(hotCalls, hasLength(3));
    expect(hotCalls[2].color, kGripHotColor);
    final pts = hotCalls[2].args[1] as Float32List;
    final third = screenOf(rig.camera, 7001, 3000); // the polyline's vertex 2
    expect(pts[0], closeTo(third.dx, 1e-3));
    expect(pts[1], closeTo(third.dy, 1e-3));
  });

  test('no leaf grips are drawn under a geometry denial; the rotation grip '
      'still is (M-03ad)', () {
    final s = gripScene();
    final rig = gripRig(s.document);
    rig.selection.replace([k(s.line), k(s.circle)]);
    s.document.commands.permissions = DraftPermissions.runtime;
    final spy = SpyCanvas();
    overlayOf(rig).paint(spy, kView);
    expect(spy.named('drawRawPoints'), isEmpty);
    expect(spy.named('drawCircle'), hasLength(1), reason: 'the rotation grip');
  });

  test("a selected point's preview cross sits at T(p) (M-03ae)", () {
    final s = gripScene();
    final rig = gripRig(s.document);
    rig.selection.replace([k(s.point), k(s.line)]);
    final grip = rotationGripCentre(rig);
    pressAndMove(rig, grip, grip + const Offset(-60, 30));
    final t = rig.tool.selectionPreviewTransform!;
    final spy = SpyCanvas();
    overlayOf(rig).paint(spy, kView);
    // The cross's arms are 6 · kSelectionStrokePixels = 12 px long; the
    // guide line in the same colour is not.
    final arms = [
      for (final c in spy.named('drawLine'))
        if (c.color == kPreviewColor &&
            (((c.args[1] as Offset) - (c.args[0] as Offset)).distance - 12)
                    .abs() <
                1e-6)
          c,
    ];
    expect(arms, hasLength(2));
    final moved =
        rig.camera.value.worldToScreen(t.transformPoint(Vector2(7250, 3300)));
    for (final arm in arms) {
      final mid = ((arm.args[0] as Offset) + (arm.args[1] as Offset)) / 2;
      expect(mid.dx, closeTo(moved.x, 1e-6));
      expect(mid.dy, closeTo(moved.y, 1e-6));
    }
  });

  test('the reshape preview is a rebased path under the world matrix '
      '(M-03aj)', () {
    final s = gripScene();
    final rig = gripRig(s.document);
    rig.selection.replace([k(s.line)]);
    final vertex = screenOf(rig.camera, 7130, 3060);
    final to = vertex + const Offset(25, -18);
    pressAndMove(rig, vertex, to);
    expect(rig.tool.dragKind, DragKind.reshape);
    final target = rig.camera.value.screenToWorld(Vector2(to.dx, to.dy));
    final spy = SpyCanvas();
    overlayOf(rig).paint(spy, kView);
    final origin = rebaseOriginFor(rig.camera.value.visibleWorld(kView));
    final names = [for (final c in spy.calls) c.name];
    final at = spy.calls.indexWhere(
        (c) => c.name == 'drawPath' && c.color == kPreviewColor);
    expect(at, greaterThan(names.indexOf('transform')));
    expect(at, lessThan(names.indexOf('restore')),
        reason: 'drawn under the rebased world matrix');
    final bounds = (spy.calls[at].args[0] as Path).getBounds();
    expect(bounds.left, closeTo(7010 - origin.x, 1e-3));
    expect(bounds.right, closeTo(target.x - origin.x, 1e-3));
    expect(bounds.top, closeTo(math.min(3020, target.y) - origin.y, 1e-3));
    expect(bounds.bottom, closeTo(math.max(3020, target.y) - origin.y, 1e-3));
    expect(spy.calls[at].strokeWidth,
        closeTo(kPreviewStrokePixels / rig.camera.value.scale, 1e-12));
  });

  test('a stretch draws its guide and the snap marker at the resolved '
      'target (spec D7, D9, M-03ar)', () {
    final s = gripScene();
    final rig = gripRig(s.document, objectSnap: true);
    rig.selection.replace([k(s.line)]);
    final vertex = screenOf(rig.camera, 7130, 3060);
    final endpoint = screenOf(rig.camera, 7130, 3100);
    final drop = endpoint + const Offset(3, -2);
    pressAndMove(rig, vertex, drop);
    final spy = SpyCanvas();
    overlayOf(rig).paint(spy, kView);
    final markers = [
      for (final c in spy.named('drawRect'))
        if (c.color == kSnapMarkerColor) c,
    ];
    expect(markers, hasLength(1), reason: 'an endpoint won: a square');
    final r = markers.single.args[0] as Rect;
    expect(r.center.dx, closeTo(endpoint.dx, 1e-6));
    expect(r.center.dy, closeTo(endpoint.dy, 1e-6));
    expect(r.width, kSnapMarkerPixels);
    final guide = spy.named('drawLine').where((c) => c.color == kPreviewColor);
    expect(guide, hasLength(1));
    expect((guide.single.args[0] as Offset).dx, closeTo(vertex.dx, 1e-6));
    expect((guide.single.args[1] as Offset).dx, closeTo(endpoint.dx, 1e-6));
  });
}
```

- [ ] **Step 2: Run them to fail.** `CI=true flutter test
  test/snap_marker_test.dart test/selection_overlay_grips_test.dart` →
  compile error in `snap_marker.dart`, and the overlay tests fail: no
  `drawRawPoints`, and only one `transform`.

- [ ] **Step 3: Implement.** Create `lib/src/snap_marker.dart`:

```dart
import 'dart:ui' show Canvas, Offset, Paint, Path, Rect;

import 'package:jet_cad_2d/jet_cad_2d.dart' show SnapKind;

import 'selection_style.dart';

/// Spec D9's marker at [at], in screen space: a fixed, small number of draw
/// calls. [kind] non-null means an object snap won; otherwise [grid] draws
/// the grid's `+`, and nothing is drawn when the raw point won.
void drawSnapMarker(Canvas canvas, Offset at, SnapKind? kind,
    {required bool grid, required Paint paint}) {
  const h = kSnapMarkerPixels / 2;
  if (kind == null) {
    if (!grid) return;
    const g = kGridMarkerPixels / 2;
    canvas.drawLine(at.translate(-g, 0), at.translate(g, 0), paint);
    canvas.drawLine(at.translate(0, -g), at.translate(0, g), paint);
    return;
  }
  switch (kind) {
    case SnapKind.endpoint:
      canvas.drawRect(
          Rect.fromCenter(
              center: at, width: kSnapMarkerPixels, height: kSnapMarkerPixels),
          paint);
    case SnapKind.midpoint:
      // Apex up: screen y grows downward.
      canvas.drawPath(
          Path()
            ..moveTo(at.dx, at.dy - h)
            ..lineTo(at.dx + h, at.dy + h)
            ..lineTo(at.dx - h, at.dy + h)
            ..close(),
          paint);
    case SnapKind.center:
      canvas.drawCircle(at, h, paint);
    case SnapKind.quadrant:
      canvas.drawPath(
          Path()
            ..moveTo(at.dx, at.dy - h)
            ..lineTo(at.dx + h, at.dy)
            ..lineTo(at.dx, at.dy + h)
            ..lineTo(at.dx - h, at.dy)
            ..close(),
          paint);
    case SnapKind.insertion:
      canvas.drawRect(
          Rect.fromCenter(
              center: at, width: kSnapMarkerPixels, height: kSnapMarkerPixels),
          paint);
      canvas.drawLine(at.translate(-h, 0), at.translate(h, 0), paint);
      canvas.drawLine(at.translate(0, -h), at.translate(0, h), paint);
    case SnapKind.intersection:
      canvas.drawLine(at.translate(-h, -h), at.translate(h, h), paint);
      canvas.drawLine(at.translate(-h, h), at.translate(h, -h), paint);
    case SnapKind.perpendicular:
    case SnapKind.tangent:
    case SnapKind.nearest:
      // Not in kDragSnapMask: a drag never produces them.
      return;
  }
}
```

Replace `lib/src/selection_overlay.dart` whole. The class doc and every
line not named below are kept as they are; the new members are marked.

```dart
import 'dart:typed_data';
import 'dart:ui'
    show Canvas, Offset, Paint, PaintingStyle, PointMode, Size, StrokeCap;

import 'package:flutter/rendering.dart' show CustomPainter;
import 'package:jet_cad_2d/jet_cad_2d.dart' show GripRole, Transform2;
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'camera_controller.dart';
import 'grip_cache.dart';
import 'outline_cache.dart';
import 'selection.dart';
import 'selection_style.dart';
import 'tool.dart';

/// Draws the selected and hovered outlines, then lets the active tool draw
/// its own overlay — and never touches the drawing underneath.
///
/// Named `…Painter` rather than the spec's `SelectionOverlay`: Flutter's own
/// `SelectionOverlay` (text selection) is exported from
/// `package:flutter/widgets.dart`, so an app that imports Material and this
/// package's barrel would have to `hide` one of them at every consumer.
///
/// The overlay is a **second** `CustomPaint` inside its own
/// `RepaintBoundary`, over `Listenable.merge([selection, tools, camera])`.
/// That is the whole point of the split (spec criterion 6): a hover at
/// pointer rate repaints this painter and leaves the drawing's layer alone,
/// so the cost of moving the mouse over a large document is one overlay
/// frame, not one full re-render.
///
/// Three things keep the frame path allocation-free. The outlines come from
/// [OutlineCache] already built — the document walk happens at
/// selection-change rate, not per frame. The two [Paint]s and the matrix are
/// fields, re-stroked and refilled in place. And the origin the cache rebases
/// by is carried by the matrix rather than by the paths, so no absolute world
/// coordinate reaches `dart:ui`: at the generated corpus's x = 4.5e6 a
/// float32 `ui.Path` would sit visibly beside the entity it outlines.
///
/// Since 03 it also draws, reading the grips from `tools.context.grips`
/// (Ruling 03-4):
/// - the move/rotate preview through a second reused matrix;
/// - the grips, with `drawRawPoints` from reused buffers, in O(1) draw calls
///   (invariant 6);
/// - the rotation grip.
class SelectionOverlayPainter extends CustomPainter {
  SelectionOverlayPainter({
    required this.selection,
    required this.tools,
    required this.camera,
    required this.outlines,
    super.repaint,
    this.onPaintForTest,
  });

  final SelectionController selection;
  final ToolController tools;
  final CameraController camera;
  final OutlineCache outlines;

  /// Counts frames in a widget test — the seam criterion 6 is measured on.
  final void Function()? onPaintForTest;

  /// `worldToScreen ∘ translate(origin)`, column-major, refilled per frame.
  /// `[10]` and `[15]` are the untouched z and w diagonal entries.
  final Float64List _matrix = Float64List(16)
    ..[10] = 1.0
    ..[15] = 1.0;

  /// New in 03: `worldToScreen ∘ T ∘ translate(origin)` for the move/rotate
  /// preview (spec D7), refilled per frame. The paths hold `world − origin`,
  /// so T sits between the camera and the rebase (M-03u).
  final Float64List _preview = Float64List(16)
    ..[10] = 1.0
    ..[15] = 1.0;

  final Paint _selected = Paint()
    ..color = kSelectionColor
    ..style = PaintingStyle.stroke;

  final Paint _hover = Paint()
    ..color = kHoverColor
    ..style = PaintingStyle.stroke;

  // New in 03.
  final Paint _previewPaint = Paint()
    ..color = kPreviewColor
    ..style = PaintingStyle.stroke;

  final Paint _gripPaint = Paint()
    ..color = kGripColor
    ..strokeCap = StrokeCap.square
    ..strokeWidth = kGripPixels;

  final Paint _gripMovePaint = Paint()
    ..color = kGripMoveColor
    ..strokeCap = StrokeCap.square
    ..strokeWidth = kGripPixels;

  final Paint _gripHotPaint = Paint()
    ..color = kGripHotColor
    ..strokeCap = StrokeCap.square
    ..strokeWidth = kGripPixels;

  final Paint _stem = Paint()
    ..color = kGripColor
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.0;

  /// Screen positions, exact-size, reallocated only when the count changes
  /// (Ruling 03-10).
  Float32List _stretchPoints = Float32List(0);
  Float32List _movePoints = Float32List(0);
  final Float32List _hotPoint = Float32List(2);

  @override
  void paint(Canvas canvas, Size size) {
    onPaintForTest?.call();
    // A zero-size paint is a real state, not a theoretical one — see
    // `ViewportTransform.fit`'s note on the layout passes that produce it.
    // It must return *before* the rebase, because `visibleWorld(Size.zero)`
    // collapses to a point, `rebaseOriginFor` answers the origin for a zero
    // span, and `pathFor(key, zero)` would then rebuild every cached path in
    // **absolute** world space and hand x = 4.5e6 to float32 `ui.Path` —
    // undoing the rebase the cache exists for, and re-doing the rebuild on
    // the next real frame.
    if (size.isEmpty) return;
    final cam = camera.value;
    final origin = rebaseOriginFor(cam.visibleWorld(size));
    final m = cam.worldToScreenMatrix;
    _matrix[0] = m.a;
    _matrix[1] = m.b;
    _matrix[4] = m.c;
    _matrix[5] = m.d;
    _matrix[12] = m.a * origin.x + m.c * origin.y + m.e;
    _matrix[13] = m.b * origin.x + m.d * origin.y + m.f;
    // The stroke rides the world→screen matrix, so the world width is the
    // screen width divided by the scale; that is what holds the outline at
    // two pixels through a zoom.
    final scale = cam.scale;
    _selected.strokeWidth = kSelectionStrokePixels / scale;
    _hover.strokeWidth = kHoverStrokePixels / scale;
    final tool = tools.active;

    final hover = selection.hover;
    // A hovered key that is also selected is drawn once, by the selected
    // pass: stroking it twice would read as a third, brighter state.
    final hoverOnly =
        hover != null && !selection.contains(hover) ? hover : null;

    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.transform(_matrix);
    for (final key in selection.keys) {
      final path = outlines.pathFor(key, origin);
      if (path != null) canvas.drawPath(path, _selected);
    }
    if (hoverOnly != null) {
      final path = outlines.pathFor(hoverOnly, origin);
      if (path != null) canvas.drawPath(path, _hover);
    }
    // New in 03: the reshape preview, in rebased world, under this same
    // matrix (spec D7, Ruling 03-3).
    tool.paintWorldOverlay(canvas, origin, scale);
    canvas.restore();

    // New in 03: the move/rotate preview (spec D7).
    final preview = tool.selectionPreviewTransform;
    if (preview != null) {
      _paintPreview(canvas, size, m, preview, origin, scale);
    }

    // Back in screen space, under its **own** clip: `restore` above popped
    // the first one, and neither the point crosses nor the tool's overlay is
    // bounded by the viewport on its own — a selected point just off screen
    // puts its cross over whatever sibling widget sits beside the canvas.
    //
    // A `point` entity has no extent, so its path is a lone `moveTo` and
    // strokes nothing; its marker is a cross whose size is in pixels and
    // therefore cannot live in the world-space cache. The two paints are
    // re-stroked rather than replaced — `Canvas` serialises a paint at call
    // time, so the world-space strokes above are already recorded at their
    // own widths.
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    _selected.strokeWidth = kSelectionStrokePixels;
    _hover.strokeWidth = kHoverStrokePixels;
    for (final key in selection.keys) {
      _drawPointCross(canvas, key, m, _selected, 3 * kSelectionStrokePixels);
    }
    if (hoverOnly != null) {
      _drawPointCross(canvas, hoverOnly, m, _hover, 3 * kHoverStrokePixels);
    }
    if (preview != null) {
      // A point has no path; its preview is its cross at T(p) (spec D7).
      _previewPaint.strokeWidth = kPreviewStrokePixels;
      for (final key in selection.keys) {
        _drawPointCross(canvas, key, m, _previewPaint,
            3 * kSelectionStrokePixels, preview);
      }
    }
    final grips = tools.context.grips;
    if (grips != null) _paintGrips(canvas, grips, m);
    tool.paintOverlay(canvas, cam, size);
    canvas.restore();
  }

  void _paintPreview(Canvas canvas, Size size, Transform2 m, Transform2 t,
      Vector2 origin, double scale) {
    // T ∘ translate(origin): the rebase first, then the drag. Composed in
    // doubles, with no Transform2 allocated per frame.
    final pe = t.a * origin.x + t.c * origin.y + t.e;
    final pf = t.b * origin.x + t.d * origin.y + t.f;
    _preview[0] = m.a * t.a + m.c * t.b;
    _preview[1] = m.b * t.a + m.d * t.b;
    _preview[4] = m.a * t.c + m.c * t.d;
    _preview[5] = m.b * t.c + m.d * t.d;
    _preview[12] = m.a * pe + m.c * pf + m.e;
    _preview[13] = m.b * pe + m.d * pf + m.f;
    // T is rigid, so the camera's scale is still the whole scale.
    _previewPaint.strokeWidth = kPreviewStrokePixels / scale;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.transform(_preview);
    for (final key in selection.keys) {
      final path = outlines.pathFor(key, origin);
      if (path != null) canvas.drawPath(path, _previewPaint);
    }
    canvas.restore();
  }

  /// Spec D6: one `drawRawPoints` per colour, whatever the grip count;
  /// projected in doubles, and only screen coordinates are narrowed
  /// (Ruling 03-10).
  void _paintGrips(Canvas canvas, GripCache grips, Transform2 m) {
    if (grips.leafGripsLive) {
      final list = grips.grips;
      if (_stretchPoints.length != 2 * grips.stretchCount) {
        _stretchPoints = Float32List(2 * grips.stretchCount);
      }
      if (_movePoints.length != 2 * grips.moveCount) {
        _movePoints = Float32List(2 * grips.moveCount);
      }
      var s = 0, mv = 0;
      for (var i = 0; i < list.length; i++) {
        final g = list[i].grip;
        final x = m.a * g.x + m.c * g.y + m.e;
        final y = m.b * g.x + m.d * g.y + m.f;
        if (g.role == GripRole.move) {
          _movePoints[mv++] = x;
          _movePoints[mv++] = y;
        } else {
          _stretchPoints[s++] = x;
          _stretchPoints[s++] = y;
        }
      }
      if (s > 0) {
        canvas.drawRawPoints(PointMode.points, _stretchPoints, _gripPaint);
      }
      if (mv > 0) {
        canvas.drawRawPoints(PointMode.points, _movePoints, _gripMovePaint);
      }
      final hot = grips.hot;
      if (hot >= 0 && hot < list.length) {
        final g = list[hot].grip;
        _hotPoint[0] = m.a * g.x + m.c * g.y + m.e;
        _hotPoint[1] = m.b * g.x + m.d * g.y + m.f;
        canvas.drawRawPoints(PointMode.points, _hotPoint, _gripHotPaint);
      }
    }
    final box = grips.box;
    if (grips.rotatable && box != null) {
      final g = rotationGripOf(box, m);
      canvas.drawLine(g.anchor,
          g.centre.translate(0, kRotationGripPixels / 2), _stem);
      canvas.drawCircle(g.centre, kRotationGripPixels / 2, _gripPaint);
    }
  }

  /// A cross of half-length [half] **screen pixels** centred on [key]'s world
  /// position — or, with [moved], on `moved(position)` — or nothing at all
  /// when [key] is not a lone point.
  ///
  /// [worldToScreen] is the camera's own matrix, not [_matrix]: the position
  /// [OutlineCache.worldPointOf] hands back is absolute world, and this pass
  /// runs after the rebased transform has been popped. It never reaches
  /// `dart:ui` — only the screen coordinates derived from it do.
  void _drawPointCross(Canvas canvas, SelectionKey key,
      Transform2 worldToScreen, Paint paint, double half,
      [Transform2? moved]) {
    final p = outlines.worldPointOf(key);
    if (p == null) return;
    var px = p.x, py = p.y;
    if (moved != null) {
      final tx = moved.a * px + moved.c * py + moved.e;
      final ty = moved.b * px + moved.d * py + moved.f;
      px = tx;
      py = ty;
    }
    final x = worldToScreen.a * px + worldToScreen.c * py + worldToScreen.e;
    final y = worldToScreen.b * px + worldToScreen.d * py + worldToScreen.f;
    canvas.drawLine(Offset(x - half, y), Offset(x + half, y), paint);
    canvas.drawLine(Offset(x, y - half), Offset(x, y + half), paint);
  }

  /// Always false: every reason to repaint is in the `repaint` listenable the
  /// caller merged. Answering true would repaint on every ancestor rebuild,
  /// which is exactly the cost the boundary split exists to avoid.
  @override
  bool shouldRepaint(covariant SelectionOverlayPainter oldDelegate) => false;
}
```

In `lib/src/select_tool.dart`:
- add `import 'snap_marker.dart';`;
- add three paint fields after `_cursor`;
- replace the first two lines of `paintOverlay`'s body (`final rect =
  bandScreen; if (rect == null) return;`) with the drag branch below;
- add `paintWorldOverlay`, `_paintGuide` and `_reshapePath` after
  `_drawDashedRect`.

```dart
  // After `MouseCursor _cursor = MouseCursor.defer;`:
  final Paint _guidePaint = Paint()
    ..color = kPreviewColor
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.0;
  final Paint _markerPaint = Paint()
    ..color = kSnapMarkerColor
    ..style = PaintingStyle.stroke
    ..strokeWidth = kSnapMarkerStrokePixels;
  final Paint _previewPaint = Paint()
    ..color = kPreviewColor
    ..style = PaintingStyle.stroke;
```

```dart
  // The head of paintOverlay's body:
    final drag = _drag;
    if (drag != null && _phase == ToolPhase.dragging) {
      _paintGuide(canvas, camera.worldToScreenMatrix, drag);
      return;
    }
    final rect = bandScreen;
    if (rect == null) return;
```

```dart
  /// Spec D7: a 1 px line from the base (a rotate's pivot) to the target,
  /// and D9's marker at the target. A rotate snaps to nothing, so it has no
  /// marker.
  void _paintGuide(Canvas canvas, Transform2 m, GripDrag drag) {
    final from = drag.base, to = drag.target;
    final a = Offset(
        m.a * from.x + m.c * from.y + m.e, m.b * from.x + m.d * from.y + m.f);
    final b =
        Offset(m.a * to.x + m.c * to.y + m.e, m.b * to.x + m.d * to.y + m.f);
    canvas.drawLine(a, b, _guidePaint);
    if (drag.kind == DragKind.rotate) return;
    drawSnapMarker(canvas, b, _dragPoint.objectKind,
        grid: _dragPoint.grid, paint: _markerPaint);
  }

  /// Spec D7: the reshape preview, drawn by the overlay under its rebased
  /// world matrix (Ruling 03-3). One path per frame, independent of the
  /// document and the selection size.
  @override
  void paintWorldOverlay(Canvas canvas, Vector2 origin, double scale) {
    final drag = _drag;
    if (drag == null || drag.kind != DragKind.reshape) return;
    final payload = drag.previewPayload;
    final kind = drag.leafKind;
    // A degenerate reshape: the canvas still shows the object unchanged.
    if (payload == null || kind == null) return;
    _previewPaint.strokeWidth = kPreviewStrokePixels / scale;
    canvas.drawPath(_reshapePath(kind, payload, origin), _previewPaint);
  }

  /// [p] in rebased world, `world − origin`: no absolute world coordinate
  /// reaches float32. Arc angles go in unchanged, because the camera's
  /// y-flip and rotation are the matrix's business.
  static Path _reshapePath(EntityKind kind, GeometryPayload p, Vector2 origin) {
    final path = Path();
    final c = p.coords;
    final ox = origin.x, oy = origin.y;
    switch (kind) {
      case EntityKind.line:
      case EntityKind.polyline:
        if (c.length < 2) return path;
        path.moveTo(c[0] - ox, c[1] - oy);
        for (var i = 2; i + 1 < c.length; i += 2) {
          path.lineTo(c[i] - ox, c[i + 1] - oy);
        }
      case EntityKind.circle:
        path.addOval(Rect.fromCircle(
            center: Offset(c[0] - ox, c[1] - oy), radius: p.scalars[0]));
      case EntityKind.arc:
        path.addArc(
            Rect.fromCircle(
                center: Offset(c[0] - ox, c[1] - oy), radius: p.scalars[0]),
            p.scalars[1],
            p.scalars[2]);
      case EntityKind.point:
      case EntityKind.text:
      case EntityKind.attrib:
      case EntityKind.fill:
        break;
    }
    return path;
  }
```

Add the export to `lib/jet_cad_2d_flutter.dart`, before
`src/snap_settings.dart`:

```dart
export 'src/snap_marker.dart';
```

- [ ] **Step 4: Run them to pass.** `CI=true flutter test
  test/snap_marker_test.dart test/selection_overlay_grips_test.dart
  test/selection_overlay_test.dart test/select_tool_drag_test.dart` → all
  tests pass. Every 02 overlay test must pass unedited: with the tool idle
  and the 02 rig's `grips == null`, the new passes draw nothing. Then run
  the `jet_cad_2d_flutter` gate line.
- [ ] **Step 5: Commit.**

```bash
git add packages/jet_cad_2d_flutter/lib/src/snap_marker.dart packages/jet_cad_2d_flutter/lib/src/selection_overlay.dart packages/jet_cad_2d_flutter/lib/src/select_tool.dart packages/jet_cad_2d_flutter/lib/jet_cad_2d_flutter.dart packages/jet_cad_2d_flutter/test/snap_marker_test.dart packages/jet_cad_2d_flutter/test/selection_overlay_grips_test.dart
git commit -m "$(cat <<'EOF'
feat(render): overlay grips, rotation grip, preview, snap markers

Spec 03 D6, D7, D9: grips via drawRawPoints from exact-size reused buffers
(O(1) draw calls), the hot grip, the rotation grip hung screen-up, the
move/rotate preview through worldToScreen o T o translate(origin), point
crosses at T(p), the reshape path in rebased world, and the guide line with
its snap marker.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 9: The app — the shell owns the caches, F3, `osnap-text`, the test seam, end to end

**Files:**
- Modify: `lib/main.dart`, `lib/planner_view.dart`
- Test: `test/planner_grips_test.dart` (A1–A4)

**Interfaces:**
- Consumes: `OutlineCache`, `GripCache`, `SnapSettings` and `ToolContext`'s
  new fields (Tasks 4–5); everything through the barrel.
- Produces:
  - `PlannerShell({Key? key, DraftDocument? document, ViewportTransform? initialCamera})`
  - `PlannerView({…, required OutlineCache outlines, required GripCache grips})`
  - the top bar's `Text(key: Key('osnap-text'))`, reading `OSNAP` or
    `osnap off`;
  - F3 bound with `includeRepeats: false`.

- [ ] **Step 1: Write the failing test.**

```dart
// test/planner_grips_test.dart
import 'dart:typed_data';

import 'package:floor_planner/main.dart';
import 'package:floor_planner/planner_view.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind, kPrimaryButton;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

Handle addLine(DraftDocument doc, List<double> coords) {
  final handle = doc.handleSeed.next();
  doc.commands.execute(AddEntityCommand(
    record: EntityRecord(
      handle: handle,
      owner: doc.rootHandle,
      kind: EntityKind.line,
      layer: ReservedHandles.layerZero,
      linetype: ReservedHandles.byLayerLinetype,
      linetypeScale: 1.0,
      geomIndex: 0,
      color: const ByLayerColor(),
      lineweight: kByLayer,
      transparency: kByLayer,
      flags: 0,
    ),
    payload: GeometryPayload(
        coords: Float64List.fromList(coords), scalars: Float64List(0)),
  ));
  return handle;
}

/// Two lines off the origin on a page whose grid is a fixed 100 mm anchored
/// at (7000, 3000). `other`'s start is off the lattice, so an object snap
/// and a grid snap land in different places.
({DraftDocument doc, Handle line, Handle other}) shellScene(
    FlutterTextMeasurer measurer) {
  final doc = DraftDocument.empty(measurer: measurer);
  PageComponent.register(doc.components);
  doc.commands.execute(SetComponentCommand<PageComponent>(doc.rootHandle,
      PageComponent(originX: 7000, originY: 3000, gridStepMm: 100)));
  final line = addLine(doc, [7010, 3020, 7130, 3060]);
  final other = addLine(doc, [7137.3, 3161.7, 7300.9, 3190.1]);
  doc.commands.clearHistory();
  return (doc: doc, line: line, other: other);
}

GeometryPayload payloadOf(DraftDocument doc, Handle h) =>
    doc.geometry.read(doc.entities.geomIndexAt(doc.entities.slotOf(h)!));

/// Pumps the shell through its test seam on a 1440 × 900 surface, then
/// sets a zoomed, panned, rotated camera.
Future<PlannerView> pumpShell(WidgetTester tester, DraftDocument doc) async {
  await tester.binding.setSurfaceSize(const Size(1440, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(MaterialApp(home: PlannerShell(document: doc)));
  await tester.pump();
  // Set after the first pump: PlannerView fits the camera once, at the end
  // of its first frame (Ruling 04-16), and would overwrite one set before.
  final view = tester.widget<PlannerView>(find.byType(PlannerView));
  final size = tester.getSize(find.byType(InteractionLayer));
  final linear =
      Transform2.rotation(0.35).multiply(Transform2.scale(2.0, -2.0));
  final mid = linear.transformPoint(Vector2(7150, 3110));
  view.camera.value = ViewportTransform(
      worldToScreenMatrix:
          Transform2.translation(size.width / 2 - mid.x, size.height / 2 - mid.y)
              .multiply(linear));
  await tester.pump();
  return view;
}

Offset globalOf(WidgetTester tester, PlannerView view, double x, double y) {
  final s = view.camera.value.worldToScreen(Vector2(x, y));
  return tester.getTopLeft(find.byType(InteractionLayer)) + Offset(s.x, s.y);
}

Future<void> mouseDrag(WidgetTester tester, Offset from, Offset to) async {
  final gesture = await tester.createGesture(
      kind: PointerDeviceKind.mouse, buttons: kPrimaryButton);
  await gesture.down(from);
  await gesture.moveTo(from + const Offset(12, 0));
  await gesture.moveTo(to);
  await gesture.up();
  await gesture.removePointer();
  await tester.pump();
}

Future<void> cmdZ(WidgetTester tester) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
  await tester.sendKeyDownEvent(LogicalKeyboardKey.keyZ);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.keyZ);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
  await tester.pump();
}

String osnapText(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const Key('osnap-text'))).data!;

/// Selects the line with a click on its body, a third of the way along.
Future<void> selectLine(WidgetTester tester, PlannerView view) async {
  await tester.tapAt(globalOf(tester, view, 7050, 3020 + 40 / 3));
  await tester.pump();
}

void main() {
  testWidgets('a stretch through the shell lands exactly on an endpoint, and '
      'cmd+Z restores it with == (A1, M-03au)', (tester) async {
    final measurer = FlutterTextMeasurer();
    addTearDown(measurer.clear);
    final s = shellScene(measurer);
    final view = await pumpShell(tester, s.doc);
    final before = payloadOf(s.doc, s.line);
    await selectLine(tester, view);
    expect(view.selection.keys, [SelectionKey.root(s.line)]);

    // Grab vertex 1; drop it 3 px from the other line's start. Object snap
    // is on by default, so it lands there exactly (spec D8).
    await mouseDrag(tester, globalOf(tester, view, 7130, 3060),
        globalOf(tester, view, 7137.3, 3161.7) + const Offset(3, -2));
    final after = payloadOf(s.doc, s.line);
    expect([after.coords[2], after.coords[3]], [7137.3, 3161.7]);
    expect([after.coords[0], after.coords[1]], [7010, 3020]);
    expect(s.doc.commands.undoDepth, 1);

    await cmdZ(tester);
    expect(payloadOf(s.doc, s.line), before,
        reason: 'undo restores the stored payload with == (spec D11)');
    expect(s.doc.commands.undoDepth, 0);
  });

  testWidgets('F3 turns object snap off: osnap-text says so and the drag '
      'lands on the grid (A2, M-03x)', (tester) async {
    final measurer = FlutterTextMeasurer();
    addTearDown(measurer.clear);
    final s = shellScene(measurer);
    final view = await pumpShell(tester, s.doc);
    expect(osnapText(tester), 'OSNAP');
    await tester.sendKeyEvent(LogicalKeyboardKey.f3);
    await tester.pump();
    expect(osnapText(tester), 'osnap off');

    await selectLine(tester, view);
    await mouseDrag(tester, globalOf(tester, view, 7130, 3060),
        globalOf(tester, view, 7137.3, 3161.7) + const Offset(3, -2));
    final after = payloadOf(s.doc, s.line);
    expect([after.coords[2], after.coords[3]], [7100, 3200],
        reason: 'the nearest lattice point of the fixed 100 mm grid');
  });

  testWidgets('F3 held down toggles once (A3, M-03af)', (tester) async {
    final measurer = FlutterTextMeasurer();
    addTearDown(measurer.clear);
    final s = shellScene(measurer);
    await pumpShell(tester, s.doc);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.f3);
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.f3);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.f3);
    await tester.pump();
    expect(osnapText(tester), 'osnap off',
        reason: 'includeRepeats: false — a repeat would have toggled it back');
  });

  testWidgets("cmd+Z pressed mid-drag is the drag's, not the shell's (A4, "
      'M-03aa)', (tester) async {
    final measurer = FlutterTextMeasurer();
    addTearDown(measurer.clear);
    final s = shellScene(measurer);
    final view = await pumpShell(tester, s.doc);
    // One finished drag first, so a stray undo would have something to take.
    await selectLine(tester, view);
    await mouseDrag(tester, globalOf(tester, view, 7130, 3060),
        globalOf(tester, view, 7137.3, 3161.7) + const Offset(3, -2));
    expect(s.doc.commands.undoDepth, 1);
    final landed = payloadOf(s.doc, s.line);

    final gesture = await tester.createGesture(
        kind: PointerDeviceKind.mouse, buttons: kPrimaryButton);
    final from = globalOf(tester, view, 7137.3, 3161.7);
    await gesture.down(from);
    await gesture.moveTo(from + const Offset(20, 10));
    await gesture.moveTo(from + const Offset(35, 18));
    expect(view.tools.active.phase, ToolPhase.dragging);

    await cmdZ(tester);
    expect(s.doc.commands.undoDepth, 1,
        reason: 'the Z never reached the shell (spec D5)');
    expect(payloadOf(s.doc, s.line), landed);
    expect(view.tools.active.phase, ToolPhase.dragging,
        reason: 'the drag is still live');

    await gesture.up();
    await gesture.removePointer();
    await tester.pump();
    expect(s.doc.commands.undoDepth, 2);
  });
}
```

- [ ] **Step 2: Run it to fail.** `cd apps/floor_planner && CI=true flutter
  test test/planner_grips_test.dart` → compile error: `PlannerShell` has no
  named parameter `document`.

- [ ] **Step 3: Implement.** In `lib/main.dart`:

```dart
/// Owns the document, the index, the camera and — since 03 — the outline
/// cache, the grip cache and the snap settings for the window's lifetime.
/// It lays out the chrome slots.
///
/// [document] and [initialCamera] are a test seam (spec 03, Architecture;
/// Ruling 03-18).
/// - [document] replaces the startup plan, and must carry a
///   `FlutterTextMeasurer`.
/// - [initialCamera] replaces the nominal fit.
/// - `PlannerView` still fits once after its first frame, so a test sets a
///   camera of its own after the first pump.
class PlannerShell extends StatefulWidget {
  const PlannerShell({super.key, this.document, this.initialCamera});

  final DraftDocument? document;
  final ViewportTransform? initialCamera;

  @override
  State<PlannerShell> createState() => _PlannerShellState();
}
```

In `_PlannerShellState`:
- `late final DraftDocument _document = widget.document ??
  startupPlan(_measurer);`
- `_camera`'s first argument becomes `widget.initialCamera ??
  _nominalFit()`, with this method:

```dart
  /// Fitted to the nominal window; PlannerView re-fits once at the real
  /// size. A document without a page fits its extents.
  ViewportTransform _nominalFit() {
    final page = _page.value;
    return page != null
        ? fitToPage(page, const Size(1440, 900))
        : ViewportTransform.fit(_document.extents, const Size(1440, 900));
  }
```

- after `_policy`, add `final SnapSettings _snap = SnapSettings();`
- after `_selection`, add:

```dart
  // Spec 03 D6, moved from PlannerView. The order is load-bearing.
  // - The outline cache is built after the selection controller, so the
  //   controller prunes a dead key before the cache walks it.
  // - The grip cache is built after the outline cache, so on a selection
  //   change its listener runs after the outlines have been rebuilt.
  late final OutlineCache _outlines = OutlineCache(_document, _selection);
  late final GripCache _grips = GripCache(_document, _selection, _outlines);
```

- `_context` becomes `ToolContext(document: _document, index: _index,
  camera: _camera, selection: _selection, page: _page, snap: _snap, grips:
  _grips)`;
- `dispose` becomes:

```dart
  @override
  void dispose() {
    _tools.dispose();
    _grips.dispose();
    _outlines.dispose();
    _selection.dispose();
    _snap.dispose();
    _page.dispose();
    _camera.dispose();
    _index.dispose();
    _measurer.clear();
    super.dispose();
  }
```

- the `CallbackShortcuts` bindings gain F3:

```dart
          const SingleActivator(LogicalKeyboardKey.keyZ, meta: true): _undo,
          const SingleActivator(LogicalKeyboardKey.keyZ, control: true): _undo,
          // Spec 03 D10: one toggle per press, never per key repeat.
          const SingleActivator(LogicalKeyboardKey.f3, includeRepeats: false):
              _snap.toggleObjectSnap,
```

- in the top bar's `Row`, between `const Spacer(),` and the zoom-text
  `ListenableBuilder`:

```dart
                    ListenableBuilder(
                      listenable: _snap,
                      builder: (_, __) => Text(
                          _snap.objectSnap ? 'OSNAP' : 'osnap off',
                          key: const Key('osnap-text')),
                    ),
                    const SizedBox(width: 16),
```

- `PlannerView(...)` gains `outlines: _outlines, grips: _grips,`.

In `lib/planner_view.dart`:
- add the two fields and constructor parameters:

```dart
    required this.outlines,
    required this.grips,
  ...
  /// Owned by the shell since 03 (spec D6).
  final OutlineCache outlines;

  /// The selection's grips. A member of the overlay's repaint merge.
  final GripCache grips;
```

- delete the state's `_outlines` field and its `dispose` override. The
  state then owns nothing to dispose.
- `_repaint` becomes:

```dart
  // The two caches are in the merge because they are the members that hear
  // a `DocChange`: an edit under a selected instance rebuilds the outline
  // and the grips, and nothing else in here would ask for the frame that
  // draws them.
  late final Listenable _repaint = Listenable.merge([
    widget.selection,
    widget.tools,
    widget.camera,
    widget.outlines,
    widget.grips,
  ]);
```

- the overlay's `outlines: _outlines` becomes `outlines: widget.outlines`.

- [ ] **Step 4: Run it to pass.** `CI=true flutter test
  test/planner_grips_test.dart test/planner_shell_test.dart` → all tests
  pass. The existing shell tests pump `const FloorPlannerApp()`, so they
  are unchanged. Then run the `floor_planner` gate line, including both
  builds.
- [ ] **Step 5: Commit.**

```bash
git add apps/floor_planner/lib/main.dart apps/floor_planner/lib/planner_view.dart apps/floor_planner/test/planner_grips_test.dart
git commit -m "$(cat <<'EOF'
feat(app): grips in the shell -- caches, F3, osnap-text, test seam

Spec 03 D6, D10: the shell owns OutlineCache, GripCache and SnapSettings in
listener order and hands them to PlannerView and ToolContext; F3 toggles
object snap once per press; the top bar reads OSNAP / osnap off; PlannerShell
takes an optional document and camera (Ruling 03-18). End-to-end: stretch,
cmd+Z, F3, and cmd+Z mid-drag.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

---
### Task 10: Mutation testing — every named mutant, and M-03e as the designed survivor

**Files:**
- Create: `docs/superpowers/notes/plan-03-mutation-log.md`

**Interfaces:**
- Consumes: every test landed in Tasks 1–9. No code changes survive this
  task.

For each mutant in the table below, in order:
1. `cp` the file to `.superpowers/sdd/2026-09-23-grips-and-transform/mutation-backups/<basename>.<id>`.
2. Apply the one edit by hand.
3. Run **only the named test file(s)**.
4. Paste the failing test names and the summary line.
5. Restore with `cp` back from the backup.
6. Run `diff <backup> <file>` and paste the empty output.

**Never `git checkout --` a `.dart` file.** Log format per mutant:

```
### M-03a — the drag delta from a scaled screen delta, no inverse camera
file: packages/jet_cad_2d_flutter/lib/src/select_tool.dart, in `_follow`
edit: `_retarget(ctx, e.world, e.shift);` → `_retarget(ctx, Vector2(_pressWorld.x + (e.screen.dx - _start.dx) / ctx.camera.value.scale, _pressWorld.y + (e.screen.dy - _start.dy) / ctx.camera.value.scale), e.shift);`
test: CI=true flutter test test/select_tool_drag_test.dart
result: FIRED — `a body drag moves the selection under a rotated camera (M-03a)` [E]; N failed
restored: diff clean
```

- `result:` is `FIRED` (at least one named test red) or `SURVIVED`.
- Only **M-03e** is expected to survive. Any other survivor is a defect in
  a test: stop, fix the test in its own commit on this branch, re-fire the
  mutant, and log both runs.
- A mutant that does not compile does not count as fired: re-express the
  same idea so it compiles, and log both attempts (Ruling 04-18's
  precedent).

**The spec's named mutants.** Paths are under `packages/jet_cad_2d/` for
engine files and `packages/jet_cad_2d_flutter/` for render files; the test
paths are relative to the same package.

| id | file | edit (old → new) | test file → test that must go red |
|---|---|---|---|
| M-03a | `lib/src/select_tool.dart` `_follow` | `_retarget(ctx, e.world, e.shift);` → `_retarget(ctx, Vector2(_pressWorld.x + (e.screen.dx - _start.dx) / ctx.camera.value.scale, _pressWorld.y + (e.screen.dy - _start.dy) / ctx.camera.value.scale), e.shift);` | `test/select_tool_drag_test.dart` → T2 "a body drag moves the selection under a rotated camera" |
| M-03b | engine `lib/src/index/spatial_index.dart` `_considerSnapCandidate` | the `final better = …;` expression → `final better = _bestSnapKind == null \|\| dist < _bestSnapDist \|\| (dist == _bestSnapDist && kindIndex < _bestSnapKind!.index);` | engine `test/index/drag_snap_test.dart` → S5 "kind decides between object snaps through a drag"; also log `snap_test.dart`'s own kind-priority tests, which go red too |
| M-03c | `lib/src/grip_drag.dart` `command`, the `_NodeCapture` case | the body → `if (node is InstanceNode) { for (final slot in document.leavesByOwner()[node.definition] ?? const <int>[]) { members.add(SetEntityGeometryCommand(document.entities.handleAt(slot), rigidTransformLeaf(document.entities.kindAt(slot), document.geometry.read(document.entities.geomIndexAt(slot)), t))); } } else { members.add(TransformNodeCommand(handle, t.multiply(node.transform))); }` | `test/grip_drag_test.dart` → D3 "an instance move rewrites the instance node, never the definition" |
| M-03d | `lib/src/select_tool.dart` `_follow` | append after `_retarget(…);`: `final c = _drag!.command(ctx.document.commands.permissions); if (c != null) ctx.execute(c);` | `test/select_tool_drag_test.dart` → T3 "no command during a drag…" |
| M-03e | `test/grip_drag_test.dart` D10 | `expect(payloadOf(doc, s.line), payloads[s.line]);` → `expect(payloadsClose(payloadOf(doc, s.line), payloads[s.line]!), isTrue);`, and the same for `s.arcNeg` | **must stay green**: log `SURVIVED — designed (spec D11)`. The companion D11 ("the undo assertion enforces ==: one ulp is caught") is green in the unmutated suite and shows `==` failing and `Tolerance` passing on a one-ulp nudge. Paste D11's result beside it. |
| M-03f | engine `lib/src/index/drag_snap.dart` step 1 | swap the two branch bodies: the `>=` branch pins `cx = base.x; pinX = true;` and the else branch pins `cy = base.y; pinY = true;` | `test/index/drag_snap_test.dart` → S2; `test/select_tool_drag_test.dart` → T6 |
| M-03g | engine `lib/src/index/drag_snap.dart` step 2 | inside `if (scratch.found) {`, before the copy, insert: `if (page != null && page.snapToGrid && gridStepMm != null) { final g = snapToGrid(raw, gridStepMm, page); if (g.distanceTo(raw) < scratch.point.distanceTo(raw)) { out.point.setFrom(g); out.grid = true; return; } }` | `test/index/drag_snap_test.dart` → S4 "an object snap beats a nearer grid point" |
| M-03h | engine `lib/src/document/grips.dart` `rigidTransformLeaf`, arc | delete `if (scalars.length >= 2) scalars[1] = scalars[1] + theta;` | `test/document/rigid_transform_test.dart` → R2 and R6 (the differential); render `test/grip_drag_test.dart` → D4 |
| M-03i | `lib/src/grip_drag.dart` `command` | `TransformNodeCommand(handle, t.multiply(node.transform))` → `TransformNodeCommand(handle, node.transform.multiply(t))` | `test/grip_drag_test.dart` → D2 "a rotated group moves by T.multiply(node.transform)" |
| M-03j | `lib/src/select_tool.dart` `_beginDrag`, rotation grip | `final pivot = Vector2((box.minX + box.maxX) / 2, (box.minY + box.maxY) / 2);` → `final pivot = Vector2.zero();` | `test/select_tool_drag_test.dart` → T11 "a rotation turns about the selection box centre…" |
| M-03k | `lib/src/grip_drag.dart` `command` | `if (members.any((m) => !m.capabilities.every(permissions.allows))) { return null; }` → `members.removeWhere((m) => !m.capabilities.every(permissions.allows)); if (members.isEmpty) return null;` | `test/grip_drag_test.dart` → D8 "a refused member cancels the whole drag" |
| M-03l | `lib/src/select_tool.dart` `onKey`, the dragging block | before `cancel(ctx);` insert `final c = _drag?.command(ctx.document.commands.permissions); if (c != null) ctx.execute(c);` | `test/select_tool_drag_test.dart` → T15 "…Escape cancels byte-identically" |
| M-03m | engine `lib/src/document/grips.dart` `rigidTransformLeaf`, text | `scalars[1] = scalarOr(payload, 1, 0) + theta;` → `scalars[1] = scalarOr(payload, 1, 0);` | `test/document/rigid_transform_test.dart` → R3 and R6 |
| M-03n | engine `lib/src/document/grips.dart` `reshapeLeaf`, arc end | `nextSweep = _wrapSweep(a - start, sweep);` → `nextSweep = _wrapSweep(a - start, 1.0);` | `test/document/grips_test.dart` → "an arc end stretch on a negative sweep stays negative" |
| M-03o | engine `lib/src/document/grips.dart` `reshapeLeaf`, line/polyline | `coords[i * 2] = localTarget.x; coords[i * 2 + 1] = localTarget.y;` → `coords[(i + 1) * 2] = localTarget.x; coords[(i + 1) * 2 + 1] = localTarget.y;` | `test/document/grips_test.dart` → "a polyline middle-vertex stretch…" |
| M-03p | `lib/src/grip_drag.dart` `command` | delete the `if (kind == DragKind.move && target.x - base.x == 0 && target.y - base.y == 0) { return null; }` statement | `test/grip_drag_test.dart` → D6; `test/select_tool_drag_test.dart` → T4 |
| M-03q | engine `lib/src/index/drag_snap.dart` step 3 | delete `if (pinY) out.point.y = base!.y;` and `if (pinX) out.point.x = base!.x;` | `test/index/drag_snap_test.dart` → S6 "a grid snap re-pins the ortho axis afterwards" |
| M-03r | engine `lib/src/document/grips.dart` `reshapeLeaf` | delete the `if (i == 0 && kind == EntityKind.polyline && isClosedPolyline(payload)) { … }` block | `test/document/grips_test.dart` → "a closed room corner moves as one…" |
| M-03s | `lib/src/select_tool.dart` `_moveBase` | `_resolve(ctx, _pressWorld, null);` → `resolveDragPoint(raw: _pressWorld, orthoBase: null, index: ctx.index, apertureWorld: kSnapAperturePixels / ctx.camera.value.scale, objectSnap: ctx.snap?.objectSnap ?? true, page: null, gridStepMm: null, scratch: _snapScratch, out: _dragPoint);` | `test/select_tool_drag_test.dart` → T5 "with grid snap on, on-grid geometry stays on the grid" |
| M-03t | `lib/src/grip_drag.dart` `command` | delete `if (!_revalidate()) return null;` | `test/grip_drag_test.dart` → D7; `test/select_tool_drag_test.dart` → T17 |
| M-03u | `lib/src/selection_overlay.dart` `_paintPreview` | `final pe = t.a * origin.x + t.c * origin.y + t.e;` → `final pe = t.e + origin.x;` and `final pf = t.b * origin.x + t.d * origin.y + t.f;` → `final pf = t.f + origin.y;` (that is `matrix ∘ T`) | `test/selection_overlay_grips_test.dart` → P1 "the move/rotate preview is drawn through worldToScreen ∘ T ∘ translate(origin)" |
| M-03v | `lib/src/selection_overlay.dart` `_paintGrips` | replace both `drawRawPoints` calls with per-grip loops: `for (var j = 0; j < s; j += 2) { canvas.drawRect(Rect.fromCenter(center: Offset(_stretchPoints[j], _stretchPoints[j + 1]), width: kGripPixels, height: kGripPixels), _gripPaint); }`, and the same over `_movePoints`/`mv` with `_gripMovePaint` (add `Rect` to the `dart:ui` show list) | `test/selection_overlay_grips_test.dart` → P2 "grips are one drawRawPoints per colour at 10 grips and at 300…" |
| M-03w | `lib/src/grip_drag.dart` | `const double kRotationStep = math.pi / 12;` → `math.pi / 6` | `test/select_tool_drag_test.dart` → T12 "shift steps the rotation by 15°" |
| M-03x | engine `lib/src/index/drag_snap.dart` step 2 | `if (objectSnap) {` → `if (true) {` | engine `test/index/drag_snap_test.dart` → S7; app `test/planner_grips_test.dart` → A2 |
| M-03y | engine `lib/src/document/grips.dart` `leafGrips`, circle | `for (var q = 0; q < 4; q++)` → `q < 3` | `test/document/grips_test.dart` → "the grip set per kind…"; render `test/grip_cache_test.dart` → C1 |
| M-03z | `lib/src/grip_cache.dart` `_rebuild` | `if (_grips.length > kMaxGrips)` → `>= kMaxGrips` | `test/grip_cache_test.dart` → C4 "the cap…" |
| M-03aa | `lib/src/select_tool.dart` `onKey` | delete the `return KeyEventResult.handled;` that ends the dragging block | `test/select_tool_drag_test.dart` → T15; app `test/planner_grips_test.dart` → A4 |

**The plan's mutants (Ruling 03-17).** They are recorded in the spec's
Testing section at Task 12.

| id | file | edit (old → new) | test that must go red |
|---|---|---|---|
| M-03ab | `lib/src/interaction_layer.dart` `build` | replace the `ListenableBuilder(…)` with `MouseRegion(cursor: _tool.cursor, onExit: _onExit, child: Listener(…the same Listener…))` | `test/interaction_cursor_test.dart` → I1 |
| M-03ac | `lib/src/select_tool.dart` `_enter` | delete `ctx.camera.addListener(_onCamera);` | `test/select_tool_drag_test.dart` → T14 |
| M-03ad | `lib/src/grip_cache.dart` | `bool get leafGripsLive => document.commands.permissions.allows(Capability.geometry);` → `bool get leafGripsLive => true;` | `test/grip_cache_test.dart` → C5; `test/select_tool_drag_test.dart` → T13; `test/selection_overlay_grips_test.dart` → P4 |
| M-03ae | `lib/src/selection_overlay.dart` `_drawPointCross` | delete `px = tx;` and `py = ty;` | `test/selection_overlay_grips_test.dart` → P5 |
| M-03af | app `lib/main.dart` | `SingleActivator(LogicalKeyboardKey.f3, includeRepeats: false)` → `SingleActivator(LogicalKeyboardKey.f3)` | app `test/planner_grips_test.dart` → A3 |
| M-03ag | `lib/src/snap_marker.dart` | swap the bodies of `case SnapKind.endpoint:` and `case SnapKind.midpoint:` | `test/snap_marker_test.dart` → K1 |
| M-03ah | `lib/src/outline_cache.dart` `worldBoundsOf` | `box = box.union(arcBounds(Vector2(cx, cy), r, start, sweep));` → `box = box.union(Aabb2.raw(cx - r, cy - r, cx + r, cy + r));` | `test/outline_cache_test.dart` → O1; `test/grip_cache_test.dart` → C2 |
| M-03ah′ | `lib/src/outline_cache.dart` `worldBoundsOf` | the `_Point` case's body → `break;` | `test/outline_cache_test.dart` → O1; `test/grip_cache_test.dart` → C2 |
| M-03ai | `lib/src/grip_cache.dart` `hitTest` | `(h > bestHandle \|\|` → `(h < bestHandle \|\|` | `test/grip_cache_test.dart` → C6; `test/select_tool_drag_test.dart` → T10 |
| M-03aj | `lib/src/select_tool.dart` `_reshapePath` | `final ox = origin.x, oy = origin.y;` → `final ox = 0.0, oy = 0.0;` | `test/selection_overlay_grips_test.dart` → P6 |
| M-03ak | `lib/src/grip_cache.dart` `rotationGripOf` | `minY - kRotationGripOffset` → `minY + kRotationGripOffset` | `test/grip_cache_test.dart` → C7 |
| M-03al | `lib/src/grip_cache.dart` constructor | delete `outlines.addListener(_rebuild);` | `test/grip_cache_test.dart` → C3 |
| M-03am | `lib/src/grip_drag.dart` `_capture` | `if (kind == EntityKind.fill \|\| kind == EntityKind.attrib) continue;` → `if (kind == EntityKind.attrib) continue;` | `test/grip_drag_test.dart` → D9 |
| M-03an | `lib/src/grip_drag.dart` `_capture` | delete `..sort((a, b) => a.target.value.compareTo(b.target.value))` | `test/grip_drag_test.dart` → D1 |
| M-03ao | `lib/src/select_tool.dart` `cancel` | before `_endDrag(ctx);` insert `final pending = _drag?.command(ctx.document.commands.permissions); if (pending != null) ctx.execute(pending);` | `test/select_tool_drag_test.dart` → T16, W1 and W3 |
| M-03ap | `lib/src/interaction_layer.dart` `_onExit` | delete `if (_activePointer != -1) return;` | `test/select_tool_drag_test.dart` → W2; also log 02's `interaction_layer_test.dart` "a drag that leaves the box keeps its captured pointer" |
| M-03aq | `lib/src/selection_overlay.dart` `_paintGrips` | delete the `if (hot >= 0 && hot < list.length) { … }` block | `test/selection_overlay_grips_test.dart` → P2 |
| M-03ar | `lib/src/select_tool.dart` `_paintGuide` | `drawSnapMarker(canvas, b, …)` → `drawSnapMarker(canvas, _lastScreen, …)` | `test/selection_overlay_grips_test.dart` → P8 |
| M-03as | `lib/src/select_tool.dart` `_classify` | `if (i >= 0) { _pressGrip = i; return PressClass.grip; }` → `if (i >= 0) { _pressGrip = i; }` | `test/select_tool_drag_test.dart` → T1 |
| M-03at | `lib/src/select_tool.dart` `_beginDrag`, grip branch | `GripDrag.move(ctx.document, ctx.selection.keys)` → `GripDrag.move(ctx.document, [ref.key])` | `test/select_tool_drag_test.dart` → T8 |
| M-03au | `lib/src/select_tool.dart` `_retarget` | `drag.moveTo(_dragPoint.point);` → `drag.moveTo(drag.kind == DragKind.reshape ? world : _dragPoint.point);` | `test/select_tool_drag_test.dart` → T9; app `test/planner_grips_test.dart` → A1 |
| M-03av | `lib/src/select_tool.dart` `_permitted` | `drag != null && drag.permittedBy(ctx.document.commands.permissions)` → `drag != null` | `test/select_tool_drag_test.dart` → T13 |
| M-03aw | engine `lib/src/index/drag_snap.dart` `dragGridStepMm` | delete `if (fixed != null) return fixed;` | engine `test/index/drag_snap_test.dart` → S8 |
| M-03ax | engine `lib/src/document/grips.dart` `rigidTransformLeaf` | delete the `if (!isRigidTransform(t)) { throw … }` statement | engine `test/document/rigid_transform_test.dart` → R5 |

- [ ] **Step 1: Fire the spec's twenty-seven.** Work through M-03a…M-03aa
  in table order and write each one into the log. After M-03e, paste D11's
  green result.
- [ ] **Step 2: Fire the plan's twenty-three.** Work through
  M-03ab…M-03ax, including `ah′`.
- [ ] **Step 3: The tally.** At the log's head, record: fired N, killed N
  − 1, survived 1 (M-03e, designed), equivalent 0. Then check the tree is
  clean of mutations: `git status --short` must list only the new log.
- [ ] **Step 4: Commit.**

```bash
git add docs/superpowers/notes/plan-03-mutation-log.md
git commit -m "$(cat <<'EOF'
docs: Plan 03 mutation log -- 27 named and 23 plan mutants

Every spec mutant M-03a..aa fired and killed except M-03e, the designed
survivor, whose one-ulp companion shows == is what the undo test enforces;
the plan's M-03ab..ax (Ruling 03-17) each killed by the test it guards.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 11: The allocation invariants, and the greps

**Files:**
- Modify: `docs/superpowers/notes/plan-03-mutation-log.md` (append the
  outputs under `## Invariants and greps`)

**Interfaces:**
- Consumes: the whole branch. It produces no code.

- [ ] **Step 1: Run the two allocation gates.** Both must pass unchanged
  (invariant 5):

```sh
cd packages/jet_cad_2d && CI=true dart test test/invariants/query_allocation_test.dart
cd ../jet_cad_2d_flutter && CI=true flutter test test/invariants/paint_allocation_test.dart
```

- [ ] **Step 2: Run the greps**, from the worktree root, and paste every
  output:

```sh
# The invariants' tests are unedited; the frame path's files are untouched.
git diff --stat main..HEAD -- packages/jet_cad_2d/test/invariants packages/jet_cad_2d_flutter/test/invariants                    # empty
git diff --stat main..HEAD -- apps/dev_harness_2d packages/jet_cad_2d/lib/src/index/spatial_index.dart \
  packages/jet_cad_2d_flutter/lib/src/draft_canvas.dart packages/jet_cad_2d_flutter/lib/src/draft_painter.dart \
  packages/jet_cad_2d_flutter/lib/src/camera_gesture_detector.dart packages/jet_cad_2d_flutter/lib/src/tile_cache.dart   # empty
# The engine stays pure Dart.
grep -n "dart:ui\|package:flutter" packages/jet_cad_2d/lib/src/document/grips.dart packages/jet_cad_2d/lib/src/index/drag_snap.dart   # nothing
# World is root space: nothing in the drag path reads the root node's transform.
grep -n "rootHandle\|accumulatedTransform" packages/jet_cad_2d_flutter/lib/src/grip_drag.dart   # nothing
grep -n "accumulatedTransform" packages/jet_cad_2d_flutter/lib/src/select_tool.dart packages/jet_cad_2d_flutter/lib/src/grip_cache.dart   # nothing
# No per-grip Rect or Offset in the grip path; one drawRawPoints per colour.
awk '/void _paintGrips/,/^  }$/' packages/jet_cad_2d_flutter/lib/src/selection_overlay.dart | grep -n "drawRect\|Rect\.\|drawRawPoints"   # three drawRawPoints, no Rect
# No SnapResult.point is held: it is read only through setFrom.
grep -n "scratch.point" packages/jet_cad_2d/lib/src/index/drag_snap.dart   # one line: out.point.setFrom(scratch.point)
# Transform2 is never compared with == in the new tests.
grep -n "transform ==\|transform, same\|\.transform)\s*;\s*$" packages/jet_cad_2d_flutter/test/grip_drag_test.dart packages/jet_cad_2d_flutter/test/select_tool_drag_test.dart   # nothing
```

- [ ] **Step 3: Commit.**

```bash
git add docs/superpowers/notes/plan-03-mutation-log.md
git commit -m "$(cat <<'EOF'
docs: Plan 03 allocation gates and greps

query_allocation_test and paint_allocation_test pass unchanged; the frame
path's files and the harness are untouched; the engine stays pure Dart; the
drag path never reads the root's transform; the grip path draws with
drawRawPoints only.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 12: Gates, the results note, the spec amendments, STATUS, the owed look

**Files:**
- Create: `docs/superpowers/notes/2026-09-23-plan-03-results.md`
- Modify: the spec
- Modify: `roadmap/03-grips-and-transform.md` (status line)
- Modify: `roadmap/00-README.md` (status row)
- Modify: `STATUS.md` (a Plan 03 section in the shape of Plan 04's; the
  header; the Resume paragraph)

**Interfaces:**
- Consumes: every earlier task's result, the mutation log, and the
  differential's printed line.

- [ ] **Step 1: The gate commands, all four lines.** Paste each output into
  the results note, with exit codes. Name the five golden failures.
  Expected counts, by adding the tests this plan lands to the branch
  point's:
  - engine: branch point + 11 (grips) + 6 (rigid) + 9 (drag snap);
  - render layer: branch point + 1 (O1) + 7 (C) + 1 (I1) + 11 (D) + 19
    (T and W: T7 was folded away, so the T numbers skip it) + 6 (P) + 1 (K1), and 1 skip;
  - harness: 82;
  - app: 21 + 4, with both builds `✓ Built`.

  Report what ran, not these sums: a difference means a test was not
  counted as planned. Explain it in the note.

- [ ] **Step 2: The results note.** Include:
  - One row per exit criterion 1–16, each with its witness (test file and
    test name, the mutation log, or the pasted gate line; see "Exit gate"
    below).
  - The differential: seed `0x5EED0003`, 200 trials, and the worst residual
    per kind, pasted from the test's printed line.
  - The mutation tally.
  - Every Ruling 03-1…03-21, one line each.
  - The debt: the root-transform disagreement (spec Open questions, still
    open); grips as widgets (accessibility, 12); snapping to the dragged
    object's ghost; move exactness is within one rounding; the unfillable
    room's preview; F3 in a browser.
  - **Criterion 16 marked OWED — not looked at; the human looks after this
    branch is presented**, with these items itemised per platform (macOS,
    Chrome, Firefox from `build/web`):
    1. Grips on a selected wall, a room, an arc and the door swing: squares
       of 8 px, the centre grips in the move colour, the hover's hot grip.
    2. A wall end stretched onto another wall's end with the endpoint
       marker showing, and landing on it.
    3. A body move of three objects with grid snap on: they stay on the
       grid.
    4. The rotation grip above the selection box. A rotate, then a shift
       rotate in 15° steps.
    5. Escape mid-drag: the preview vanishes and nothing changes.
    6. Undo after each drag: cmd+Z on macOS, ctrl+Z in a browser, one step
       per drag.
    7. F3 toggles `osnap-text`. **In Chrome and Firefox: does the browser's
       find-next also fire?** If it does, the finding picks another key
       (spec Open questions).
    8. The cursor: precise over a grip, grab over the rotation grip, move
       over a selected body, grabbing while rotating.
    9. A room corner stretched so the room self-intersects: the preview
       shows the outline, and the fill drops on release.
    10. Whether snapping to the dragged object's own ghost feels sticky.
    11. A drag carried past the canvas edge continues.
    12. Grid snap with a fixed `gridStepMm` skipping the drawn minor lines:
        **not reachable from the app** (04's panel does not expose it).
        Recorded, not looked at.

- [ ] **Step 3: The spec amendments.** Add these "Amended at execution
  (Plan 03)" paragraphs. None rewrites the original text; each cites its
  ruling.
  - D2: Rulings 03-6 and 03-9.
  - D3: Ruling 03-1, for the end angle modulo 2π and exit criterion 2's
    wording.
  - D5: Ruling 03-8.
  - D6: Rulings 03-10 and 03-15.
  - D7: Ruling 03-3.
  - D8: Ruling 03-11.
  - Invariant 5: Ruling 03-12.
  - Testing: Ruling 03-16 for the differential's scale, and Ruling 03-17's
    M-03ab…M-03ax table with ids, mutation and test.

- [ ] **Step 4: STATUS and the roadmap.** Follow Plan 04's shape:
  - In `STATUS.md`, add a "Plan 03 — grips and transform (executed on
    `plan-03/grips-and-transform`, not merged)" section with the task
    table and each task's head commit.
  - Add "What Plan 03 measured": the four counts, the mutations, the
    differential, the allocation gates, and the look OWED.
  - Update the header and the Resume paragraph.
  - Set `roadmap/03-grips-and-transform.md`'s status to "executed, not
    merged", with links to the spec, the plan and the results.
  - Update the matching row of `roadmap/00-README.md`.

- [ ] **Step 5: Commit, then archive the ledger.**

```bash
git add docs/superpowers/notes/2026-09-23-plan-03-results.md docs/superpowers/specs/2026-09-23-grips-and-transform-design.md roadmap/03-grips-and-transform.md roadmap/00-README.md STATUS.md
git commit -m "$(cat <<'EOF'
docs: Plan 03 results, spec amendments, STATUS and roadmap

Exit gate 15 of 16; criterion 16 (the human's look on macOS, Chrome and
Firefox) is OWED. Spec amended at execution for Rulings 03-1, 03-3, 03-6,
03-8, 03-9, 03-10, 03-11, 03-12, 03-15, 03-16 and 03-17.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

Then archive the ledger as the branch's **last commit before the merge**:

```bash
mkdir -p docs/superpowers/ledgers/2026-09-23-grips-and-transform
cp -R .superpowers/sdd/2026-09-23-grips-and-transform/. docs/superpowers/ledgers/2026-09-23-grips-and-transform/
git add docs/superpowers/ledgers/2026-09-23-grips-and-transform
git commit -m "$(cat <<'EOF'
docs: archive the Plan 03 ledger

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

Hand over to `superpowers:finishing-a-development-branch`. **The merge is
the human's decision.** If the auto-mode classifier refuses the merge, try
once from the main checkout. If it is refused again, give the human the
exact command (memory: `sandbox-blocks-git-merge`).

---

## Exit gate

The spec's sixteen criteria, each with the task and test that witnesses it:

| # | criterion (short) | witness |
|---|---|---|
| 1 | `leafGrips` returns D3's set, closed-polyline rule | Task 1: "the grip set per kind, in owner space", "isClosedPolyline is an exact stored-value test"; Task 4: C1 |
| 2 | a stretch moves only the grabbed coordinate; the arc's derived end within `Tolerance` | Task 1: the line, middle-vertex, room-corner, both arc ends (both signs) and radius tests (the end angle modulo 2π, Ruling 03-1) |
| 3 | `rigidTransformLeaf` passes the differential | Task 2: R6 (seed `0x5EED0003`, 200 trials, scaled tolerance) |
| 4 | a body drag and a centre grip move the whole selection; on-grid stays on-grid | Task 7: T2, T8, T5 |
| 5 | a rotated group and an instance compose `T.multiply(node.transform)`; the definition and the other instance are untouched | Task 6: D2, D3 |
| 6 | rotation about the box centre (arcs by `arcBounds`, points by position); shift 15° | Task 4: O1, C2; Task 7: T11, T12 |
| 7 | one drag is one `CompoundCommand` labelled Move, Rotate or Stretch; a no-op adds none | Task 6: D1, D4, D5, D6; Task 7: T3, T4 |
| 8 | undo restores with `==`; M-03e is the survivor, with its 1-ulp check | Task 6: D10, D11; Task 10: M-03e's log entry |
| 9 | Escape, pointer cancel, activation and revalidation are byte-identical; a drag past the edge continues | Task 7: T15, W1, T16, W3, T17, W2 |
| 10 | a stretch lands exactly on an endpoint; object beats grid; ortho is overridden and re-pinned; F3 off | Task 3: S3, S4, S6, S7; Task 7: T9; Task 9: A1, A2 |
| 11 | permissions at press and all-or-nothing at release | Task 4: C5; Task 7: T13; Task 8: P4; Task 6: D8 |
| 12 | grips in O(1) draw calls; the cap at `kMaxGrips` | Task 8: P2; Task 4: C4 |
| 13 | every named mutant fired and killed, except M-03e | Task 10's log: fifty-one entries (27 spec, 23 plan, plus `ah′`) |
| 14 | the allocation invariants pass unchanged | Task 11 |
| 15 | the four gate lines, the five goldens only, both builds | Task 12, step 1 |
| 16 | a human looked on macOS, Chrome and Firefox | **OWED** to the human; Task 12's note itemises it |

## Self-review

**Spec coverage.** Each decision, invariant and exit criterion, with the
tasks that carry it:

| spec item | task(s) |
|---|---|
| D1: move, rotate, reshape, rigid only | 1, 2 (`isRigidTransform`), 6 |
| D2: `GripDrag` in `SelectTool`; press classes; slop; shift's two meanings; capability at press | 6, 7 (T1, T6, T13); Rulings 03-2, 03-6 |
| D3: the grip set, closedness, reshape, `rigidTransformLeaf` | 1, 2 |
| D4: one `CompoundCommand`; `T`; `T.multiply(node.transform)`; order; fills; permissions; revalidation; no-ops | 6 (D1–D10) |
| D5: phases and kinds; world per event; camera listener; cancel paths; keys; cursor; hover | 5 (I1), 7 (T2, T14, T15, T16, W1–W3); Rulings 03-7, 03-8 |
| D6: `GripCache`; `worldBoundsOf`; the cap; the shell owns the caches; `drawRawPoints`; hot grip; rotation grip | 4, 8 (P2, P4), 9; Rulings 03-4, 03-10, 03-15, 03-19 |
| D7: the preview matrix; point crosses at `T(p)`; the reshape path in rebased world; the guide line | 5, 8 (P1, P5, P6, P8); Ruling 03-3 |
| D8: `resolveDragPoint`; precedence; base point; exactness; rotate; the grid step | 3, 7 (T4, T5, T9, T12); Ruling 03-11 |
| D9: snap markers | 8 (K1, P8) |
| D10: `SnapSettings`; `ToolContext` fields; F3 with `includeRepeats: false`; `osnap-text` | 5, 9 (A2, A3) |
| D11: undo is exact; M-03e and its companion | 6 (D10, D11), 10; Ruling 03-20 |
| D12: 02 behaviour changes | 7 (the renamed 02 test, T1, T15); Ruling 03-21 |
| Architecture: the test seam | 9; Ruling 03-18 |
| Invariant 1: no command during a drag | T3, M-03d |
| Invariant 2: cancel paths byte-identical | T15, T16, W1, W3, T17 |
| Invariant 3: undo with `==` | D10, D11 |
| Invariant 4: draw order untouched | T3 (`handleSeed.current`, live count) |
| Invariant 5: frame path unchanged | Task 11; Ruling 03-12 |
| Invariant 6: O(1) grip draw calls | P2, M-03v |
| Invariant 7: no `SnapResult.point` held | S3; Task 11's grep |
| Invariant 8: `==` for stored values, `Tolerance` for decisions | Global Constraints; G2, G10, R5, T2, and G7 (Ruling 03-1) |
| Differential check | R6 |
| Widget tests 1–4 | A1 (1, 2), A2 (3), A4 (4) |
| Exit criteria 1–16 | the Exit gate table above |

Every spec mutant, with the task that kills it:

| mutant | task |
|---|---|
| M-03a | 7 (T2) |
| M-03b | 3 (S5) |
| M-03c | 6 (D3) |
| M-03d | 7 (T3) |
| M-03e | 6 (D10 survives; D11 is its companion) |
| M-03f | 3 (S2), 7 (T6) |
| M-03g | 3 (S4) |
| M-03h | 2 (R2, R6), 6 (D4) |
| M-03i | 6 (D2) |
| M-03j | 7 (T11) |
| M-03k | 6 (D8) |
| M-03l | 7 (T15) |
| M-03m | 2 (R3, R6) |
| M-03n | 1 |
| M-03o | 1 |
| M-03p | 6 (D6), 7 (T4) |
| M-03q | 3 (S6) |
| M-03r | 1 |
| M-03s | 7 (T5) |
| M-03t | 6 (D7), 7 (T17) |
| M-03u | 8 (P1) |
| M-03v | 8 (P2) |
| M-03w | 7 (T12) |
| M-03x | 3 (S7), 9 (A2) |
| M-03y | 1, 4 (C1) |
| M-03z | 4 (C4) |
| M-03aa | 7 (T15), 9 (A4) |

The plan's M-03ab…M-03ax are each tied to the one test they guard in Task
10's second table.

**Fixture rules.**
- The camera is zoomed (1.1 or 2.0), panned, and rotated (0.35 rad). T2
  asserts `b ≠ 0` and `scale ≠ 1`, and C7 asserts the rotation.
- The group's transform is a rotation, and D2 asserts `b ≠ 0`.
- There are two instances of one definition (D3).
- The arcs have non-zero starts, and `arcNeg` sweeps −1.4.
- A closed room.
- Everything sits at x ≈ 7000, and P1 asserts a non-zero origin.
- The root is the identity, asserted in `gripScene` and in T3.

**Placeholder scan.** No TBD, no "similar to Task N", and no test without
its code. Task 7 and Task 8 name exact line ranges and method names to
keep, because they edit an existing file rather than repeat 150 unchanged
lines. The spec is re-derivable from the rulings wherever the plan departs
from it.

**Type and name consistency.**
- `Grip(role, index, x, y)`, `leafGrips`, `reshapeLeaf`,
  `rigidTransformLeaf` and `isRigidTransform` (Tasks 1–2) are used with
  the same signatures in Tasks 4, 6, 7 and 8.
- `resolveDragPoint`'s named parameters and `dragGridStepMm(page,
  pxPerWorldMm)` (Task 3) match `SelectTool._resolve` (Task 7).
- `GripCache.grips`, `hot`, `box`, `rotatable`, `leafGripsLive`,
  `hitTest`, `hitsRotationGrip`, `stretchCount` and `moveCount` (Task 4)
  are read in Tasks 7 and 8.
- `GripRef.key/grip/ordinal` is read in Tasks 4 and 7.
- `rotationGripOf(box, m).anchor/.centre` is used in Tasks 4, 7 and 8.
- `GripDrag.move/rotate/reshape`, `base`, `target`, `transform`,
  `previewPayload`, `leafKind`, `theta`, `capabilities`, `permittedBy`,
  `moveTo`, `rotateTo(…, step:)` and `command(permissions)` (Task 6) are
  used in Tasks 7 and 8.
- `DragKind`, `PressClass`, `SelectTool.dragKind/pressClass` (Tasks 6–7)
  are used in the tests of Tasks 7, 8 and 9.
- `Tool.paintWorldOverlay(Canvas, Vector2, double)` (Task 5) is overridden
  in Task 8.
- `ToolContext.page/snap/grips` (Task 5) is built by `GripRig` (Task 7)
  and by the shell (Task 9).
- `gripRig(DraftDocument, …)` takes a document everywhere; `gripScene()`
  returns a `GripScene` whose `.document` is passed in.

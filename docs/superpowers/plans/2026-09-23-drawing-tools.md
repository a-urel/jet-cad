# Drawing tools (sub-project 05) — implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `apps/floor_planner` gets a tool palette in its left panel, with
the shortcuts V, L, P, R, C, A, T and F. With it a user draws:
- chained lines;
- polylines, open or closed;
- rectangles;
- circles;
- centre–start–end arcs, whose direction follows the pointer;
- single-line text, typed into an inline field.

Every point snaps through 03's chain, and every tool shows a live rubber
band and stays armed after each shape. One finished shape is one command,
so one undo step. With **Fill** on, a rectangle, a circle or a closed
polyline commits as one filled region. Escape drops a shape in progress
with the document byte-identical; with nothing in progress, it returns to
Select. The sample plan's furniture becomes filled regions drawn over the
floor finishes.

**Architecture:** by layer:
- **The engine** gains `document/drafting.dart`:
  - `draftRecord`, `addDrafted` and `addDraftedRegion`, which build commands
    and allocate their handles;
  - the payload builders and the degeneracy predicates;
  - `textHeightMm`;
  - `SweepTracker`, the arc's travelled-angle accumulator.

  All of it is pure Dart and needs no Flutter.
- **The render layer** gains `lib/src/draw/`:
  - an abstract `PlacementTool`, which owns point resolution (self-snap,
    then `resolveDragPoint`), the hover marker, the camera listener, keys
    and committing;
  - six small subclasses.

  `TextTool` owns its `TextEditingController` and exposes a `pending`
  listenable.
- **The app** gains:
  - a `ToolPalette`;
  - a `ShellShortcutGuard` (a `Shortcuts` mapping the shell's letters to
    `DoNothingAndStopPropagationTextIntent`), wrapped around every text
    field under the shell;
  - a `TextEntryOverlay` outside the `InteractionLayer`;
  - one `_activate` method in the shell;
  - the rebuilt sample-plan furniture.

**02's `tool.dart`, `interaction_layer.dart` and `ToolController` are not
edited.**

**Tech Stack:**
- Dart, and Flutter **3.47.2** (the installed SDK sits under a cask directory
  named `3.27.3`);
- `flutter_test`, `package:test` and `vector_math`;
- `jet_cad_2d` and `jet_cad_2d_flutter`.

No new dependency anywhere.

**Spec:** [docs/superpowers/specs/2026-09-23-drawing-tools-design.md](../specs/2026-09-23-drawing-tools-design.md),
**revision 2**. Read it whole before Task 1: the evidence of record,
D1–D14, the six invariants, the fixture rules, the twenty-six mutants
M-05a…z, the differential check, the widget tests and the fourteen exit
criteria.

The review that produced revision 2 is
[docs/superpowers/notes/2026-09-23-drawing-tools-spec-review-r1.md](../notes/2026-09-23-drawing-tools-spec-review-r1.md).
A developer is most likely to undo three of its findings by reflex:
- **#1:** a shell `CallbackShortcuts` takes letters from a focused
  `TextField`, so every text field needs the guard;
- **#3:** a self-intersecting polyline triangulates to an **empty** list,
  not null;
- **#4:** the tool owns the text and commits on a canvas click
  **synchronously**, before focus moves.

**Roadmap input:** [roadmap/05-drawing-tools.md](../../../roadmap/05-drawing-tools.md).

**Branch:** `plan-05/drawing-tools`, cut from local `main` at the commit
that lands this plan, or later, in its own worktree.

**`origin/main` is stale** (memory: `jet-cad-plan-status`), so create the
worktree by hand from local `main`:

```sh
git worktree add .claude/worktrees/plan-05-drawing-tools -b plan-05/drawing-tools main
```

Enter it with `EnterWorktree path=.claude/worktrees/plan-05-drawing-tools`.
While the plan is in flight, the ledger lives at
`.superpowers/sdd/2026-09-23-drawing-tools/` (git-ignored, in the worktree).
As the branch's last commit before the merge, it is archived to
`docs/superpowers/ledgers/2026-09-23-drawing-tools/`.

---

## Rulings made here rather than left to an implementer

Each ruling says what the plan does, why, and what it costs if it is wrong.
The ones marked **(spec amended)** are written into the spec as "Amended at
execution (Plan 05)" paragraphs in Task 11.

- **Ruling 05-1 — `SweepTracker` does not clamp `τ` (spec amended, D8 and
  the differential).**
  - **Why.** Revision 2 clamps `τ` to `±(2π − ε)` at every step. A clamp
    loses the winding, and it flips the sign on an out-and-back beyond a
    full turn. Wind `+3π`: the clamp holds `τ ≈ 2π`. Come back `−2π`: `τ ≈
    0⁻`, clockwise. The true travel is `+π`, counter-clockwise.
  - **The magnitude is already bounded.** `sweepTo`'s magnitude comes from
    `δ ∈ (0, 2π)`, never from `τ`, so the clamp bounds nothing that needs
    bounding.
  - **The rule.** `τ` accumulates unbounded, and only its sign is read.
  - **The differential's skip rule** becomes: skip a trial whose true travel
    is within `1e-6` of 0, or whose `δ` is within `1e-6` of 0 or of `2π`.
    Those are the only cases where the sign or the refusal is a tie.
  - **Cost if wrong:** none. The sweep's magnitude never exceeds `2π`
    either way.
- **Ruling 05-2 — a self-snap's hover marker is `drawSnapMarker(…,
  SnapKind.endpoint, …)` (spec amended, D4).** D4 says "the tool paints its
  own endpoint square". The engine's endpoint marker *is* that square, so
  the base sets `objectKind = SnapKind.endpoint` for a self-snap and draws
  through the one marker function. Cost: none.
- **Ruling 05-3 — `commit` takes a builder closure,
  `commit(ctx, DraftCommand Function() build)`.** The permission check runs
  **before** `build()`, so a denied shape allocates no handle. D2 says "an
  abandoned shape consumes no handle", and a denied one is abandoned. Cost:
  one closure per commit, off the frame path.
- **Ruling 05-4 — the base passes the self-snap's stored `Vector2` itself to
  `accept` and sets `acceptingSelf`; the polyline closes by appending the
  point it was given.**
  - **Which instance.** `selfSnap` returns the stored instance, and the base
    passes that instance on (no copy). While `accept` runs,
    `acceptingSelf` is true.
  - **Closing.** The polyline closes with `polylinePayload([...points,
    p])`, where `p` is by construction the stored first vertex.
  - **Where M-05i lives.** It is the base passing a copy of the **raw**
    pointer instead, which leaves the last pair `!=` the first.
  - **Cost if wrong:** none. The value is the same one D6 names.
- **Ruling 05-5 — M-05k is defined as re-deriving the next chain start
  through a screen round trip.** The spec says "re-resolves the next start
  from the click". The tool has no raw click by the time it commits, so the
  concrete mutant is `points..clear()..add(cam.screenToWorld(
  cam.worldToScreen(p)))`. A float round trip is a realistic way to lose
  exactness.
  - **The fixture's first end is snapped** onto an existing endpoint at
    off-lattice coordinates (7137.3, 3161.7), so the round trip changes the
    bits.
  - **Cost if wrong:** the mutant turns out equivalent at that fixture. The
    mutation log then says so, and the fixture moves.
- **Ruling 05-6 — the palette and the Fill checkbox never take focus: they
  are wrapped in `ExcludeFocus` (spec amended, D5).**
  - **Why.** D5's step 3, "puts focus back on the canvas", has no handle to
    act on. `InteractionLayer`'s `FocusNode` is private, and exposing it
    would edit 02's API (invariant 4).
  - **How the rule holds instead.** The canvas has `autofocus: true` and
    takes focus on every pointer-down (`interaction_layer.dart:132, 227`).
    So "focus stays on the canvas" is the rule, and it holds because
    nothing in the palette ever takes focus.
  - **Cost if wrong:** a keyboard user cannot tab into the palette. That is
    12's accessibility work.
- **Ruling 05-7 — focus leaves the text field with `unfocus(disposition:
  UnfocusDisposition.previouslyFocusedChild)`.**
  - **When.** The overlay calls it on its own `FocusNode` as soon as
    `pending` clears, whether by commit or by cancel.
  - **Where focus goes.** Back to the scope's previous child, which is the
    canvas's `Focus`. No 02 API change.
  - **Cost if wrong:** focus lands on the scope, and the shell's shortcuts
    stop until the next canvas click. A widget test pins it: after Enter,
    `L` activates Line.
- **Ruling 05-8 — the guard also wraps the page panel, and it also maps
  meta+Z and ctrl+Z (spec amended, D5 and D9).**
  - **The page panel.** Its scale field (`page-scale`) is a `TextField`
    under the same shell `CallbackShortcuts`.
  - **The undo keys.** Without them in the guard, cmd+Z typed into either
    field would undo the **document**.
  - **Why the guard is harmless elsewhere.** It maps to
    `DoNothingAndStopPropagationTextIntent`, whose action only
    `EditableText` registers. With focus anywhere else, the lookup finds no
    action and the key bubbles up to the shell as before.
  - **Cost if wrong:** cmd+Z inside a field does not undo the field's own
    text on some platforms. That is acceptable for a one-line field.
- **Ruling 05-9 — M-05v's test asserts that `tester.sendKeyEvent(...)`
  returns `false` and that the tool is unchanged (spec amended, Testing).**
  `flutter_test` does not turn raw key events into `EditableText` input, so
  "the field reads late" cannot be observed with key events. What the guard
  guarantees is observable: the framework does **not** consume the key,
  which is what lets the platform deliver it as text, and the shell does not
  act on it. Without the guard, the shell's `CallbackShortcuts` consumes it
  (`true`) and switches tools. Cost: none; this is the mechanism itself.
- **Ruling 05-10 — M-05u is detected by the identity of `EditableTextState`
  across a pan.** The text lives in the tool's controller and the focus
  node lives in the overlay's `State`, so a remount would lose neither.
  What a remount does lose is the element, meaning the IME connection and
  the composing region. So the test asserts `identical(before, after)` on
  `tester.state<EditableTextState>(…)`, plus focus and text. Cost: none.
- **Ruling 05-11 — the text field is 240 × 32 logical px, and its
  bottom-left corner sits at the insertion point's screen position (spec
  amended, D9).** "Baseline-left" is approximated by the field's
  bottom-left. M-05n's test compares `tester.getBottomLeft` with the
  camera's projection within 0.5 px. Cost: the typed text sits a few pixels
  above the committed text. It is an open question in the spec, and the look
  judges it.
- **Ruling 05-12 — the sample plan's count goes from 523 to 509.**
  - **Measured.** 523 at `5ea98dd` (a throwaway test printed
    `doc.entities.liveCount`).
  - **The arithmetic.** The rebuild turns 30 furniture entities into 8
    regions of 2, which is 16.
  - **The bounds hold.** `startup_plan_test`'s `[500, 1000]` and
    `planner_shell_test`'s `>= 500` still pass, with a margin of 9.
  - **Cost if wrong:** a later sample-plan cut drops below 500. The results
    note records the margin.
- **Ruling 05-13 — a pointer move with the primary button held is a hover,
  not a drag.** Placement is click by click (D3). A pressed move resolves
  the hover and places nothing, and only `onPointerDown` places a point.
  Cost: a press-drag-release draws nothing extra, which is AutoCAD's
  behaviour.
- **Ruling 05-14 — key-ups are always `ignored`, except shift.** Shift down
  or up re-resolves the hover, and `onKey` then returns `handled` mid-shape
  (every key-down is), or `ignored` when idle. Cost: none; this matches 03.
- **Ruling 05-15 — M-05p's mutant is concrete.** `commitShape` executes the
  region's halves as two `AddEntityCommand`s:
  1. the boundary: `AddEntityCommand(record: region.boundary, payload:
     region.boundaryPayload)`;
  2. the fill: `AddEntityCommand(record: region.fill, payload:
     GeometryPayload(coords: Float64List(0), scalars:
     Float64List.fromList([region.boundary.handle.value.toDouble()])))`.

  Cost: none; it is the realistic "two commands" bug.

## Global Constraints

These are copied from `CLAUDE.md` and the spec. This plan's additions are
marked.

- **Pure-Dart engine.** Nothing under `packages/jet_cad_2d` imports Flutter
  or `dart:ui`. Task 10 greps for it.
- **`unused_import` and `unused_element` are errors in
  `jet_cad_2d_flutter`**, test files and fixtures included. Import only the
  names you reference.
- **The frame path allocates nothing per entity in steady state, and O(1)
  per flush.** `query_allocation_test.dart` and `paint_allocation_test.dart`
  stay green and unedited.
  - **This plan adds:** the rubber band reuses one `Path` field,
    `band.reset()`, per tool, and draws it with at most one `drawPath` per
    frame (D12). The overlay's structural test (Task 4) gates it.
- **Draw order is ascending handle value.** A shape's handles come from
  `doc.handleSeed.next()` at commit time only. A region's fill is lower
  than its boundary, by `AddRegionCommand.allocate`.
- **Geometric decisions use `Tolerance`; stored-value comparisons are exact
  `==`.**
  - The decisions: degeneracy (length, size, radius), the zero sweep, and
    the coincident vertex.
  - The stored values: every payload, closedness (`isClosedPolyline`), and
    a snapped start.
- **02's API is unchanged (invariant 4).** Task 10 checks that
  `git diff main -- packages/jet_cad_2d_flutter/lib/src/tool.dart
  packages/jet_cad_2d_flutter/lib/src/interaction_layer.dart` is empty.
- **World is root space.** Never read or write the root's transform, which
  is pinned to the identity by `7c96e11`.
- **Never commit `analysis_options.yaml`.** Run `git status --short` before
  every commit. `git checkout -- <path>` only an `analysis_options.yaml`
  that `pub get` rewrote.
- **Never `git checkout --` a `.dart` file.** Before a mutation, back the
  file up with `cp`, restore from that copy, and `diff` to prove the
  restore.
- **Never synthesize test output.** Run the command and paste what it
  printed, with the summary line and the exit code.
- **Prefix every test command with `CI=true`.**
- **Code, comments and commit messages in English.**
- **Every commit ends with the trailer, exactly:** `Co-Authored-By: Claude
  Opus 5.5 <noreply@anthropic.com>`. Check it with `git log -1 --format=%B |
  grep -c "Opus 5.5"`, which must print `1`.
- **Format before the gate.** Run `dart format <files you touched>` first.
  The code blocks here are not guaranteed to be formatter-exact.
- **Every fixture is off the identity** (spec, Testing).
  - **The render-layer camera** is `gripCamera(centre: Vector2(7200, 3150),
    flipY: flipY)`, run for **both** `flipY` values.
  - **The engine and render scene** sits at x ≈ 7000–7400, y ≈ 3000–3300.
  - **The page** is at scale **1:20**.
  - Never scale 1.0, never 0° or 90°, and never at the origin.
- **Every task ends green.** The gate lines (spec criterion 13):

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
  - **Which lines each task runs:**
    - Tasks 1–2: the `jet_cad_2d` line.
    - Tasks 3–6: the `jet_cad_2d_flutter` line. Task 1 runs it too,
      because the engine barrel grew.
    - Tasks 7–8: the `floor_planner` line as well.
    - Tasks 10–11: all four.
  - **Branch-point counts,** at `5ea98dd`: engine **894**; render layer
    **854** + 1 skip + the five goldens; harness **82**; app **26**.

## Review Focus

Five inputs the spec implies but no exit criterion names. They are the ones
most likely to bite a person using this. Each has a test in the task that
owns the code.

1. **A shortcut letter or cmd+Z typed into the page panel's scale field**
   must not switch tools or undo the document. The guard wraps the page
   panel too (Ruling 05-8). Test: Task 7, `A9`.
2. **Two drawing-tool shortcuts in a row mid-shape** (`L` while a polyline
   is pending): switching must cancel the pending polyline byte-identically
   and arm Line. Test: Task 7, `A10`.
3. **A pan or zoom mid-shape followed by a click:** the click must land at
   the *new* camera's world point, not at a stale hover. Test: Task 3, `B6`.
4. **A polyline closed on a tiny triangle** whose three vertices are all
   inside the aperture of each other: the first vertex (close) wins over the
   last (finish open) exactly when at least three vertices are placed. Test:
   Task 4, `PL7`.
5. **Undo right after a commit, with the tool still armed and nothing
   pending:** cmd+Z must reach the shell and remove exactly that one shape.
   The tool must not swallow it when idle. Test: Task 7, `A11`.

---

## File structure

| file | responsibility |
|---|---|
| `packages/jet_cad_2d/lib/src/document/drafting.dart` | **create**: `kDraftFillColor`, `kDraftTextPaperMm`, `draftRecord`, `addDrafted`, `addDraftedRegion`, the payload builders, the degeneracy predicates, `textHeightMm`, `wrapAngle`, `SweepTracker` |
| `packages/jet_cad_2d/lib/jet_cad_2d.dart` | **modify**: one export |
| `packages/jet_cad_2d/test/document/drafting_test.dart` | **create**: E1–E10 |
| `packages/jet_cad_2d/test/document/sweep_tracker_test.dart` | **create**: S1–S6 and the differential |
| `packages/jet_cad_2d_flutter/lib/src/draw/placement_tool.dart` | **create**: `PlacementTool` |
| `packages/jet_cad_2d_flutter/lib/src/draw/line_tool.dart` | **create**: `LineTool` |
| `packages/jet_cad_2d_flutter/lib/src/draw/polyline_tool.dart` | **create**: `PolylineTool` |
| `packages/jet_cad_2d_flutter/lib/src/draw/rectangle_tool.dart` | **create**: `RectangleTool` |
| `packages/jet_cad_2d_flutter/lib/src/draw/circle_tool.dart` | **create**: `CircleTool` |
| `packages/jet_cad_2d_flutter/lib/src/draw/arc_tool.dart` | **create**: `ArcTool` |
| `packages/jet_cad_2d_flutter/lib/src/draw/text_tool.dart` | **create**: `TextPlacement`, `TextTool` |
| `packages/jet_cad_2d_flutter/lib/jet_cad_2d_flutter.dart` | **modify**: seven exports, plus `SelectTool`, `SnapSettings` if not already exported (check) |
| `packages/jet_cad_2d_flutter/test/support/draw_fixture.dart` | **create**: `drawScene`, `DrawRig`, `drawRig`, `hoverAt`, `clickAt`, `keyDown`, `worldAt` |
| `packages/jet_cad_2d_flutter/test/draw/placement_tool_test.dart` | **create**: B1–B9, via `LineTool` |
| `packages/jet_cad_2d_flutter/test/draw/line_tool_test.dart` | **create**: L1–L6 |
| `packages/jet_cad_2d_flutter/test/draw/polyline_tool_test.dart` | **create**: PL1–PL8 |
| `packages/jet_cad_2d_flutter/test/draw/rectangle_tool_test.dart` | **create**: R1–R5 |
| `packages/jet_cad_2d_flutter/test/draw/draw_overlay_test.dart` | **create**: OV1–OV2 |
| `packages/jet_cad_2d_flutter/test/draw/circle_tool_test.dart` | **create**: C1–C3 |
| `packages/jet_cad_2d_flutter/test/draw/arc_tool_test.dart` | **create**: AR1–AR6 |
| `packages/jet_cad_2d_flutter/test/draw/text_tool_test.dart` | **create**: TX1–TX7 |
| `apps/floor_planner/lib/shortcut_guard.dart` | **create**: `kShellLetterKeys`, `ShellShortcutGuard` |
| `apps/floor_planner/lib/tool_palette.dart` | **create**: `PaletteEntry`, `ToolPalette` |
| `apps/floor_planner/lib/text_entry_overlay.dart` | **create**: `TextEntryOverlay` |
| `apps/floor_planner/lib/main.dart` | **modify**: the tools, `_fill`, `_activate`, the shortcuts, the palette, the guard around the page panel |
| `apps/floor_planner/lib/planner_view.dart` | **modify**: takes `textTool`; the root becomes a `Stack` with the overlay outside the `InteractionLayer` |
| `apps/floor_planner/lib/startup_plan.dart` | **modify**: `_Pen.region` and `_Pen.polygon`; the furniture moves after the finishes as regions |
| `apps/floor_planner/test/planner_draw_test.dart` | **create**: A1–A11 |
| `apps/floor_planner/test/startup_plan_test.dart` | **modify**: SP1–SP2 |
| `docs/superpowers/notes/plan-05-mutation-log.md` | **create** (Task 9) |
| `docs/superpowers/notes/2026-09-23-plan-05-results.md` | **create** (Task 11) |
| the spec, `roadmap/05-drawing-tools.md`, `roadmap/00-README.md`, `STATUS.md` | **modify** (Task 11) |

Paths under `lib/` and `test/` are relative to the package directory each
task names: `packages/jet_cad_2d/` in Tasks 1–2,
`packages/jet_cad_2d_flutter/` in Tasks 3–6, and `apps/floor_planner/` in
Tasks 7–8.

---

### Task 1: `drafting.dart` — records, commands, payloads, text height

Package: `packages/jet_cad_2d`.

**Files:**
- Create: `lib/src/document/drafting.dart`
- Modify: `lib/jet_cad_2d.dart` (one export after
  `src/document/draft_document.dart`)
- Test: `test/document/drafting_test.dart`

**Interfaces:**
- Consumes: `AddEntityCommand` (`commands.dart:35`),
  `AddRegionCommand.allocate` (529), `triangulationFor` (652),
  `EntityRecord`, `GeometryPayload`, `ReservedHandles`, `ByLayerColor`,
  `TrueColor`, `kByLayer`, `kLineweightDefault`, `Tolerance.standard`,
  `PageComponent`, and `DraftDocument` (`handleSeed`, `rootHandle`).
- Produces, all exported from `package:jet_cad_2d/jet_cad_2d.dart`:

  ```dart
  const DraftColor kDraftFillColor = TrueColor(0xE6E1D8);
  const double kDraftTextPaperMm = 2.5;
  EntityRecord draftRecord(Handle handle, Handle owner, EntityKind kind, {String text = ''});
  AddEntityCommand addDrafted(DraftDocument doc, EntityKind kind, GeometryPayload payload, {String text = ''});
  AddRegionCommand? addDraftedRegion(DraftDocument doc, EntityKind boundaryKind, GeometryPayload boundaryPayload,
      {DraftColor fillColor = kDraftFillColor, DraftColor boundaryColor = const ByLayerColor(), int boundaryLineweight = kLineweightDefault});
  GeometryPayload linePayload(Vector2 a, Vector2 b);
  GeometryPayload polylinePayload(List<Vector2> points, {bool closed = false});
  GeometryPayload rectanglePayload(Vector2 c1, Vector2 c2);
  GeometryPayload circlePayload(Vector2 c, double r);
  GeometryPayload arcPayload(Vector2 c, double r, double start, double sweep);
  GeometryPayload textPayload(Vector2 p, double heightMm);
  double textHeightMm(PageComponent? page);
  bool isDegenerateSegment(Vector2 a, Vector2 b);
  bool isDegenerateRectangle(Vector2 c1, Vector2 c2);
  bool isDegenerateRadius(double r);
  ```

- [ ] **Step 1: Write the failing tests.** Create
  `test/document/drafting_test.dart`:

```dart
import 'dart:typed_data';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

DraftDocument _doc() => DraftDocument.empty(measurer: MetricModelMeasurer());

EntityRecord _record(DraftDocument doc, Handle h) =>
    doc.entities.read(doc.entities.slotOf(h)!);

GeometryPayload _payload(DraftDocument doc, Handle h) =>
    doc.geometry.read(doc.entities.geomIndexAt(doc.entities.slotOf(h)!));

// Off-lattice, off-origin corners: a copy error shows in the low bits.
final Vector2 c1 = Vector2(7137.3, 3161.7);
final Vector2 c2 = Vector2(7300.9, 3190.1);

void main() {
  test('E1 draftRecord carries the D2 defaults, owned by the given owner',
      () {
    final r = draftRecord(const Handle(0x51), const Handle(0x11),
        EntityKind.text,
        text: 'Hall');
    expect(r.handle, const Handle(0x51));
    expect(r.owner, const Handle(0x11));
    expect(r.kind, EntityKind.text);
    expect(r.layer, ReservedHandles.layerZero);
    expect(r.linetype, ReservedHandles.byLayerLinetype);
    expect(r.linetypeScale, 1.0);
    expect(r.color, const ByLayerColor());
    expect(r.lineweight, kByLayer);
    expect(r.transparency, kByLayer);
    expect(r.flags, 0);
    expect(r.text, 'Hall');
    expect(r.textStyle, ReservedHandles.standardTextStyle);
    expect(r.textAttrs, 0, reason: 'left, baseline, no override bits (D2)');
  });

  test('E2 addDrafted allocates from the seed when built, and does not run',
      () {
    final doc = _doc();
    final before = doc.handleSeed.current;
    final cmd = addDrafted(doc, EntityKind.line, linePayload(c1, c2));
    expect(cmd.record.handle.value, before.value + 1);
    expect(cmd.record.owner, doc.rootHandle);
    expect(doc.entities.liveCount, 0, reason: 'built, not executed');
    doc.commands.execute(cmd);
    expect(_payload(doc, cmd.record.handle).coords,
        Float64List.fromList([c1.x, c1.y, c2.x, c2.y]));
  });

  test('E3 draw, undo, draw again: the second handle is never the first '
      '(M-05d)', () {
    final doc = _doc();
    final a = addDrafted(doc, EntityKind.line, linePayload(c1, c2));
    doc.commands.execute(a);
    doc.commands.undo();
    final b = addDrafted(doc, EntityKind.line, linePayload(c2, c1));
    doc.commands.execute(b);
    expect(b.record.handle, isNot(a.record.handle),
        reason: 'handles are never reissued');
    expect(b.record.handle.value, greaterThan(a.record.handle.value));
  });

  test('E4 undo removes a drafted entity and redo restores the same handle',
      () {
    final doc = _doc();
    final a = addDrafted(doc, EntityKind.line, linePayload(c1, c2));
    doc.commands.execute(a);
    final b = addDrafted(doc, EntityKind.circle, circlePayload(c2, 40));
    doc.commands.execute(b);
    final full = DraftDocumentCodec.encodeToString(doc);
    doc.commands.undo();
    doc.commands.undo();
    expect(doc.entities.liveCount, 0);
    doc.commands.redo();
    doc.commands.redo();
    expect(DraftDocumentCodec.encodeToString(doc), full,
        reason: 'exit criterion 2: same handles, same bytes');
  });

  test('E5 a rectangle is five exact corners and round-trips closed (M-05b)',
      () {
    final p = rectanglePayload(c1, c2);
    expect(p.coords, Float64List.fromList(
        [c1.x, c1.y, c2.x, c1.y, c2.x, c2.y, c1.x, c2.y, c1.x, c1.y]));
    expect(p.scalars, isEmpty);
    expect(isClosedPolyline(p), isTrue);
    final doc = _doc();
    final cmd = addDrafted(doc, EntityKind.polyline, p);
    doc.commands.execute(cmd);
    final back = DraftDocumentCodec.decodeString(
        DraftDocumentCodec.encodeToString(doc),
        measurer: MetricModelMeasurer());
    final q = _payload(back, cmd.record.handle);
    expect(q, p, reason: 'GeometryPayload == compares exactly');
    expect(isClosedPolyline(q), isTrue);
  });

  test('E6 polylinePayload copies points, and closed repeats the first', () {
    final pts = [c1, Vector2(7200.25, 3000.5), c2];
    final open = polylinePayload(pts);
    expect(open.pointCount, 3);
    expect(isClosedPolyline(open), isFalse);
    final closed = polylinePayload(pts, closed: true);
    expect(closed.pointCount, 4);
    expect(closed.coords[6], c1.x);
    expect(closed.coords[7], c1.y);
    expect(isClosedPolyline(closed), isTrue);
    pts[0].setValues(0, 0);
    expect(open.coords[0], 7137.3, reason: 'a copy, not a view');
  });

  test('E7 text: height is cap height, and width and oblique inherit the '
      'style (M-05c, M-05t)', () {
    final doc = _doc();
    const heightMm = 50.0; // 2.5 paper mm at 1:20
    final cmd = addDrafted(
        doc, EntityKind.text, textPayload(c1, heightMm),
        text: 'Living');
    doc.commands.execute(cmd);
    final r = _record(doc, cmd.record.handle);
    final payload = _payload(doc, cmd.record.handle);
    expect(payload.scalars, Float64List.fromList([heightMm, 0, 1, 0]));
    // Rendered cap height: the text transform maps a capital's height in
    // glyph space onto exactly heightMm in model space.
    final style = doc.textStyleOf(r.textStyle);
    final metrics = doc.textMeasurer.measure(text: r.text, style: style);
    final t = textLocalTransform(
        resolveTextAttributes(payload, r.textAttrs, style), metrics, c1);
    final capTop = t.transformPoint(Vector2(0, metrics.capHeight));
    final base = t.transformPoint(Vector2.zero());
    expect((capTop - base).length, closeTo(heightMm, 1e-9),
        reason: 'DXF height is cap height, not em height (M-05c)');
    // M-05t: with the style's width factor at 0.8, the placed text is 0.8
    // wide — the payload's 1 is padding, not an override.
    doc.tables.textStyles.remove(ReservedHandles.standardTextStyle);
    doc.tables.textStyles.add(const TextStyleRecord(
        handle: ReservedHandles.standardTextStyle,
        name: 'Standard',
        fontFamily: 'Roboto',
        widthFactor: 0.8));
    final resolved = resolveTextAttributes(
        payload, r.textAttrs, doc.textStyleOf(r.textStyle));
    expect(resolved.widthFactor, 0.8);
  });

  test('E8 textHeightMm is 2.5 paper mm at the page scale (M-05j)', () {
    expect(textHeightMm(null), 2.5);
    expect(textHeightMm(PageComponent(scaleDenominator: 20)), 50.0);
    expect(textHeightMm(PageComponent(scaleDenominator: 100)), 250.0);
  });

  test('E9 addDraftedRegion: a rectangle and a circle fill; a bow tie does '
      'not (M-05q)', () {
    final doc = _doc();
    final seed = doc.handleSeed.current;
    final rect = addDraftedRegion(
        doc, EntityKind.polyline, rectanglePayload(c1, c2))!;
    expect(rect.fill.handle.value, lessThan(rect.boundary.handle.value),
        reason: 'the fill draws under its boundary (invariant 6)');
    expect(rect.fill.color, kDraftFillColor);
    expect(rect.boundary.color, const ByLayerColor());
    expect(rect.boundary.lineweight, kLineweightDefault);
    doc.commands.execute(rect);
    expect(doc.fills.fillsOf(rect.boundary.handle), [rect.fill.handle]);
    expect(doc.commands.undoDepth, 1, reason: 'one command, one undo step');

    final circle =
        addDraftedRegion(doc, EntityKind.circle, circlePayload(c2, 40));
    expect(circle, isNotNull,
        reason: "a circle's empty triangulation is its normal case");

    final before = doc.handleSeed.current;
    final bowTie = polylinePayload([
      Vector2(7000, 3000),
      Vector2(7100, 3100),
      Vector2(7100, 3000),
      Vector2(7000, 3100),
    ], closed: true);
    expect(triangulationFor(EntityKind.polyline, bowTie), isEmpty,
        reason: 'empty, not null: why D11 needs its own refusal');
    expect(addDraftedRegion(doc, EntityKind.polyline, bowTie), isNull);
    expect(doc.handleSeed.current, before, reason: 'a refusal allocates none');
    expect(
        addDraftedRegion(
            doc, EntityKind.polyline, polylinePayload([c1, c2, c1 + c2])),
        isNull,
        reason: 'an open polyline cannot fill');
    expect(seed.value, lessThan(doc.handleSeed.current.value));
  });

  test('E10 the degeneracy predicates decide under Tolerance', () {
    final tiny = Vector2(c1.x + 1e-10, c1.y);
    expect(isDegenerateSegment(c1, tiny), isTrue);
    expect(isDegenerateSegment(c1, c2), isFalse);
    expect(isDegenerateRectangle(c1, Vector2(c2.x, c1.y)), isTrue);
    expect(isDegenerateRectangle(c1, Vector2(c1.x, c2.y)), isTrue);
    expect(isDegenerateRectangle(c1, c2), isFalse);
    expect(isDegenerateRadius(0), isTrue);
    expect(isDegenerateRadius(1e-10), isTrue);
    expect(isDegenerateRadius(0.001), isFalse);
  });
}
```

- [ ] **Step 2: Run them and see them fail.**
  Run: `cd packages/jet_cad_2d && CI=true dart test test/document/drafting_test.dart`
  Expected: compile errors, `draftRecord` and the other new names are not
  defined.

- [ ] **Step 3: Implement `lib/src/document/drafting.dart`.** Write the
  whole file. `SweepTracker` and `wrapAngle` land in Task 2 in the same
  file.

```dart
import 'dart:typed_data';

import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../core/handle.dart';
import '../core/tolerance.dart';
import '../store/entity_store.dart';
import '../store/geometry_store.dart';
import 'commands.dart';
import 'draft_document.dart';
import 'page_component.dart';
import 'style.dart';

/// Spec 05 D13: the one fill colour a drawing tool gives a region, an
/// opaque light warm grey. Choosing another belongs to 12.
const DraftColor kDraftFillColor = TrueColor(0xE6E1D8);

/// Spec 05 D9: a placed text is 2.5 mm tall on paper.
const double kDraftTextPaperMm = 2.5;

/// Spec 05 D2: a root-level entity on layer 0, ByLayer everything. A text
/// takes the Standard style, left and baseline, with **no** override bits,
/// so its width factor and oblique angle come from the style.
EntityRecord draftRecord(Handle handle, Handle owner, EntityKind kind,
        {String text = ''}) =>
    EntityRecord(
      handle: handle,
      owner: owner,
      kind: kind,
      layer: ReservedHandles.layerZero,
      linetype: ReservedHandles.byLayerLinetype,
      linetypeScale: 1.0,
      geomIndex: 0,
      color: const ByLayerColor(),
      lineweight: kByLayer,
      transparency: kByLayer,
      flags: 0,
      text: text,
      textStyle: ReservedHandles.standardTextStyle,
      textAttrs: 0,
    );

/// One finished shape's command (spec 05 D2, D11). The handle is taken
/// from [DraftDocument.handleSeed] **now**, when the shape finishes; redo
/// re-executes this same object, so the handle is stable. Not executed.
AddEntityCommand addDrafted(
        DraftDocument doc, EntityKind kind, GeometryPayload payload,
        {String text = ''}) =>
    AddEntityCommand(
      record: draftRecord(doc.handleSeed.next(), doc.rootHandle, kind,
          text: text),
      payload: payload,
    );

/// A filled shape's one command (spec 05 D11, D13), or null when the
/// boundary cannot be filled, and then nothing is allocated.
///
/// `triangulationFor` returns null for anything that is not a circle or a
/// closed polyline, and an **empty** list for a closed polyline that
/// self-intersects or is degenerate. `AddRegionCommand` would accept that
/// empty list and build a region with no triangles, so a polyline's empty
/// triangulation is refused here. A circle's is its normal case.
AddRegionCommand? addDraftedRegion(
  DraftDocument doc,
  EntityKind boundaryKind,
  GeometryPayload boundaryPayload, {
  DraftColor fillColor = kDraftFillColor,
  DraftColor boundaryColor = const ByLayerColor(),
  int boundaryLineweight = kLineweightDefault,
}) {
  final triangles = triangulationFor(boundaryKind, boundaryPayload);
  if (triangles == null) return null;
  if (boundaryKind == EntityKind.polyline && triangles.isEmpty) return null;
  return AddRegionCommand.allocate(
    seed: doc.handleSeed,
    owner: doc.rootHandle,
    boundaryKind: boundaryKind,
    boundaryPayload: boundaryPayload,
    layer: ReservedHandles.layerZero,
    fillColor: fillColor,
    boundaryColor: boundaryColor,
    boundaryLineweight: boundaryLineweight,
  );
}

GeometryPayload _payload(List<double> coords, List<double> scalars) =>
    GeometryPayload(
      coords: Float64List.fromList(coords),
      scalars: Float64List.fromList(scalars),
    );

GeometryPayload linePayload(Vector2 a, Vector2 b) =>
    _payload([a.x, a.y, b.x, b.y], const []);

/// [points] copied in order; [closed] appends the first point again —
/// closedness is that repeated pair under `==` (`isClosedPolyline`).
GeometryPayload polylinePayload(List<Vector2> points, {bool closed = false}) {
  final n = points.length + (closed ? 1 : 0);
  final coords = Float64List(n * 2);
  for (var i = 0; i < points.length; i++) {
    coords[i * 2] = points[i].x;
    coords[i * 2 + 1] = points[i].y;
  }
  if (closed) {
    coords[(n - 1) * 2] = points.first.x;
    coords[(n - 1) * 2 + 1] = points.first.y;
  }
  return GeometryPayload(coords: coords, scalars: Float64List(0));
}

/// Spec 05 D7: axis-aligned in world space, every coordinate copied from
/// [c1] or [c2], closing pair `==` the first.
GeometryPayload rectanglePayload(Vector2 c1, Vector2 c2) => _payload(
    [c1.x, c1.y, c2.x, c1.y, c2.x, c2.y, c1.x, c2.y, c1.x, c1.y], const []);

GeometryPayload circlePayload(Vector2 c, double r) => _payload([c.x, c.y], [r]);

GeometryPayload arcPayload(Vector2 c, double r, double start, double sweep) =>
    _payload([c.x, c.y], [r, start, sweep]);

/// Spec 05 D9: `[height, rotation, widthFactor, oblique]`. The height is
/// the **cap height** (DXF). The last two are padding: with no override
/// bits the style's values apply.
GeometryPayload textPayload(Vector2 p, double heightMm) =>
    _payload([p.x, p.y], [heightMm, 0, 1, 0]);

/// Spec 05 D9: 2.5 paper mm at the page's scale, as model mm; 2.5 with no
/// page.
double textHeightMm(PageComponent? page) => page == null
    ? kDraftTextPaperMm
    : kDraftTextPaperMm * page.scaleDenominator;

bool isDegenerateSegment(Vector2 a, Vector2 b) =>
    a.distanceTo(b) <= Tolerance.standard.linear;

bool isDegenerateRectangle(Vector2 c1, Vector2 c2) =>
    (c2.x - c1.x).abs() <= Tolerance.standard.linear ||
    (c2.y - c1.y).abs() <= Tolerance.standard.linear;

bool isDegenerateRadius(double r) => r <= Tolerance.standard.linear;
```

  Add to `lib/jet_cad_2d.dart`, after `export 'src/document/draft_document.dart';`:

```dart
export 'src/document/drafting.dart';
```

- [ ] **Step 4: Run the tests and see them pass.**
  Run: `cd packages/jet_cad_2d && CI=true dart test test/document/drafting_test.dart`
  Expected: `+10: All tests passed!`. If E5's `decodeString` needs
  `registerComponents`, it does not: the fixture has no page component.

- [ ] **Step 5: Gate and commit.** Run the `jet_cad_2d` gate line (expect
  **904**, which is 894 + 10), then the `jet_cad_2d_flutter` line, because
  the barrel grew (expect **854** + 1 skip + the five goldens).

```bash
git add packages/jet_cad_2d/lib/src/document/drafting.dart packages/jet_cad_2d/lib/jet_cad_2d.dart packages/jet_cad_2d/test/document/drafting_test.dart
git commit -m "$(cat <<'EOF'
feat(engine): drafting builders for the drawing tools

draftRecord, addDrafted and addDraftedRegion build one command per
finished shape, allocating from the handle seed only when the shape
finishes. The payload builders copy their inputs exactly; a rectangle's
closing pair equals its first. addDraftedRegion refuses a polyline whose
triangulation is empty, since triangulateSimplePolygon returns empty,
not null, for a self-intersecting loop. textHeightMm is 2.5 paper mm at
the page scale. Spec 05 D2, D7, D9, D11, D13.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 2: `SweepTracker` — the arc's travelled angle, and the differential

Package: `packages/jet_cad_2d`.

**Files:**
- Modify: `lib/src/document/drafting.dart` (append)
- Test: `test/document/sweep_tracker_test.dart`

**Interfaces:**
- Consumes: `Tolerance.standard.angular`.
- Produces:

  ```dart
  double wrapAngle(double a);            // into (−π, π]
  final class SweepTracker {
    double get start; double get travel;
    void begin(double start);
    void track(double angle);
    double sweepTo(double end);          // 0 = refuse; sign = sign of travel, 0 counts as CCW
  }
  ```

- [ ] **Step 1: Write the failing tests.** Create
  `test/document/sweep_tracker_test.dart`:

```dart
import 'dart:math' as math;

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';

const double tau = 2 * math.pi;

/// The reference (spec 05, Differential check): the true signed angle a
/// straight pointer segment sweeps around (cx, cy), by summing 64
/// sub-sample steps. Each sub-step is far below π, so wrapping it is exact.
double segmentTravel(
    double cx, double cy, double ax, double ay, double bx, double by) {
  var total = 0.0;
  var prev = math.atan2(ay - cy, ax - cx);
  for (var k = 1; k <= 64; k++) {
    final t = k / 64;
    final a = math.atan2(ay + (by - ay) * t - cy, ax + (bx - ax) * t - cx);
    total += wrapAngle(a - prev);
    prev = a;
  }
  return total;
}

void main() {
  test('S1 wrapAngle maps into (−π, π]', () {
    expect(wrapAngle(0), 0);
    expect(wrapAngle(math.pi), closeTo(math.pi, 1e-15));
    expect(wrapAngle(-math.pi), closeTo(math.pi, 1e-15));
    expect(wrapAngle(1.5 * math.pi), closeTo(-0.5 * math.pi, 1e-15));
    expect(wrapAngle(-1.5 * math.pi), closeTo(0.5 * math.pi, 1e-15));
    expect(wrapAngle(7.0), closeTo(7.0 - tau, 1e-15));
  });

  test('S2 counter-clockwise travel gives the positive sweep', () {
    final t = SweepTracker()..begin(0.3);
    t
      ..track(0.8)
      ..track(1.6)
      ..track(2.2);
    expect(t.sweepTo(2.2), closeTo(1.9, 1e-12));
  });

  test('S3 clockwise travel gives the negative sweep (M-05g)', () {
    final t = SweepTracker()..begin(0.3);
    t
      ..track(-0.2)
      ..track(-0.9);
    // The same end angle a CCW path would reach the long way round.
    expect(t.sweepTo(-0.9), closeTo(-1.2, 1e-12));
    expect(t.sweepTo(2.2), closeTo(1.9 - tau, 1e-12),
        reason: 'the direction is the travelled one, not the short way');
  });

  test('S4 travel across the ±π seam keeps its direction (M-05f)', () {
    final t = SweepTracker()..begin(2.9);
    t
      ..track(3.1)
      ..track(-3.1) // just past π: a raw difference would be −6.2
      ..track(-2.8);
    expect(t.travel, greaterThan(0));
    expect(t.sweepTo(-2.8), closeTo(-2.8 + tau - 2.9, 1e-12));
  });

  test('S5 no travel at all is counter-clockwise (M-05z)', () {
    final t = SweepTracker()..begin(0.3);
    expect(t.travel, 0);
    expect(t.sweepTo(1.4), closeTo(1.1, 1e-12),
        reason: 'τ == 0 is the CCW tie-break (spec D8)');
    t
      ..track(0.9)
      ..track(0.3); // out and back, cancelling exactly
    expect(t.travel, 0);
    expect(t.sweepTo(1.4), greaterThan(0));
  });

  test('S6 an end on the start is refused, even after a full turn', () {
    final t = SweepTracker()..begin(0.3);
    for (var a = 0.3; a < 0.3 + tau; a += 0.5) {
      t.track(a);
    }
    expect(t.sweepTo(0.3), 0, reason: 'a full circle is not an arc');
    expect(t.sweepTo(0.3 + tau), 0);
    // Wind past a full turn, then come back part way: the sign follows the
    // cumulative travel, unclamped (Ruling 05-1).
    final u = SweepTracker()..begin(0.0);
    for (var a = 0.0; a <= 3 * math.pi; a += 0.4) {
      u.track(a);
    }
    for (var a = 3 * math.pi; a >= math.pi; a -= 0.4) {
      u.track(a);
    }
    expect(u.travel, greaterThan(0));
    expect(u.sweepTo(math.pi), greaterThan(0));
  });

  test('differential: sweepTo matches the swept reference '
      '(seed 0x5EED0005, 500 trials)', () {
    final rng = math.Random(0x5EED0005);
    var skipped = 0;
    var checked = 0;
    for (var trial = 0; trial < 500; trial++) {
      final cx = 7000 + rng.nextDouble() * 400;
      final cy = 3000 + rng.nextDouble() * 300;
      final steps = 3 + rng.nextInt(18);
      var px = cx + 50 + rng.nextDouble() * 100;
      var py = cy + (rng.nextDouble() - 0.5) * 100;
      final start = math.atan2(py - cy, px - cx);
      final t = SweepTracker()..begin(start);
      var truth = 0.0;
      for (var s = 0; s < steps; s++) {
        final nx = cx + (rng.nextDouble() - 0.5) * 400;
        final ny = cy + (rng.nextDouble() - 0.5) * 400;
        truth += segmentTravel(cx, cy, px, py, nx, ny);
        t.track(math.atan2(ny - cy, nx - cx));
        px = nx;
        py = ny;
      }
      final end = math.atan2(py - cy, px - cx);
      final delta = (end - start) % tau;
      if (truth.abs() < 1e-6 || delta < 1e-6 || tau - delta < 1e-6) {
        skipped++;
        continue;
      }
      checked++;
      final expected = truth >= 0 ? delta : delta - tau;
      final got = t.sweepTo(end);
      expect(got.sign, expected.sign, reason: 'trial $trial');
      expect(got, closeTo(expected, Tolerance.standard.angular),
          reason: 'trial $trial');
    }
    // ignore: avoid_print
    print('SWEEP differential: checked $checked, skipped $skipped');
    expect(checked, greaterThan(450));
  });
}
```

- [ ] **Step 2: Run them and see them fail.**
  Run: `cd packages/jet_cad_2d && CI=true dart test test/document/sweep_tracker_test.dart`
  Expected: compile errors, `wrapAngle` and `SweepTracker` are not defined.

- [ ] **Step 3: Append to `lib/src/document/drafting.dart`.** Add the
  import `import 'dart:math' as math;` at the top, then:

```dart
const double _tau = 2 * math.pi;

/// [a] mapped into (−π, π].
double wrapAngle(double a) {
  final w = a % _tau; // Dart's % is non-negative for a positive divisor
  return w > math.pi ? w - _tau : w;
}

/// Spec 05 D8: the angle the pointer has travelled around an arc's centre
/// since its start, and the signed sweep that direction implies.
///
/// `τ` accumulates **unbounded**: a clamp would lose the winding and flip
/// the sign on an out-and-back beyond a full turn (Ruling 05-1). Only its
/// sign is read; the magnitude of a sweep comes from the end angle alone.
final class SweepTracker {
  double _start = 0;
  double _previous = 0;
  double _travel = 0;

  double get start => _start;
  double get travel => _travel;

  void begin(double start) {
    _start = start;
    _previous = start;
    _travel = 0;
  }

  /// One pointer sample's angle. Each step is wrapped into (−π, π], so no
  /// single step jumps the seam.
  void track(double angle) {
    _travel += wrapAngle(angle - _previous);
    _previous = angle;
  }

  /// The signed sweep from the start to [end], or 0 to refuse (the end is on
  /// the start: a full circle is not an arc). Counter-clockwise when the
  /// travel is **>= 0**; that tie-break is deliberate (spec D8).
  double sweepTo(double end) {
    final delta = (end - _start) % _tau;
    final eps = Tolerance.standard.angular;
    if (delta <= eps || _tau - delta <= eps) return 0;
    return _travel >= 0 ? delta : delta - _tau;
  }
}
```

- [ ] **Step 4: Run the tests and see them pass.**
  Run: `cd packages/jet_cad_2d && CI=true dart test test/document/sweep_tracker_test.dart`
  Expected: `+7: All tests passed!`, and the printed line `SWEEP
  differential: checked N, skipped M` with N > 450. Paste the line; Task 11
  quotes it.

- [ ] **Step 5: Gate and commit.** Run the `jet_cad_2d` line (expect
  **911**, which is 904 + 7).

```bash
git add packages/jet_cad_2d/lib/src/document/drafting.dart packages/jet_cad_2d/test/document/sweep_tracker_test.dart
git commit -m "$(cat <<'EOF'
feat(engine): SweepTracker, the arc's travelled angle

The sign of the sweep is the sign of the unbounded, seam-safe travel, with
0 counting as counter-clockwise; the magnitude comes from the end angle,
and an end on the start is refused. A seeded differential against a
swept reference (0x5EED0005, 500 trials) pins the sign. Spec 05 D8,
Ruling 05-1.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 3: `PlacementTool`, the draw fixture, and `LineTool`

Package: `packages/jet_cad_2d_flutter`.

**Files:**
- Create: `lib/src/draw/placement_tool.dart`
- Create: `lib/src/draw/line_tool.dart`
- Modify: `lib/jet_cad_2d_flutter.dart`. Add `export 'src/draw/placement_tool.dart';` and `export 'src/draw/line_tool.dart';`. Check that `select_tool.dart`, `snap_settings.dart` and `grip_cache.dart` are already exported (the app imports them through the barrel today, so they are).
- Create: `test/support/draw_fixture.dart`
- Test: `test/draw/placement_tool_test.dart` (B1–B9), `test/draw/line_tool_test.dart` (L1–L6)

**Interfaces:**
- Consumes:
  - Task 1: `addDrafted`, `addDraftedRegion`, `linePayload`,
    `isDegenerateSegment`.
  - 03: `resolveDragPoint`, `dragGridStepMm`, `kSnapAperturePixels`,
    `DragPoint`, `SnapResult` and `drawSnapMarker`; the style constants
    `kPreviewColor`, `kPreviewStrokePixels`, `kSnapMarkerColor` and
    `kSnapMarkerStrokePixels`.
  - `grip_fixture.dart`: `gripCamera`, `pointerAt`, `screenOf`, `snapshot`.
  - `selection_fixture.dart`: `addEntity`.
- Produces:

  ```dart
  abstract class PlacementTool extends Tool {
    PlacementTool({ValueListenable<bool>? fill});
    final ValueListenable<bool>? fill;
    final List<Vector2> points;
    bool acceptingSelf;                 // true only inside accept(), for a self-snap (Ruling 05-4)
    final Path band;                    // reset per frame, never reallocated (D12)
    final Paint bandPaint;              // preview colour, stroke; width set per frame
    bool get isPending;                 // points.isNotEmpty; TextTool overrides
    Vector2 get hoverPoint;             // the resolved hover, exact
    bool get hoverVisible;
    SnapKind? get hoverKind;
    Vector2? get orthoBase;             // default: points.last, or null
    Vector2? selfSnap(Vector2 raw, double apertureWorld);   // default null
    void accept(Vector2 point, ToolContext ctx);
    void finish(ToolContext ctx);       // default no-op; Enter while pending
    void hovered(Vector2 raw);          // default no-op; every hover's raw world point
    void clearShape();                  // default points.clear()
    void paintRubberBand(Canvas canvas, Vector2 origin, double scale);
    bool commit(ToolContext ctx, DraftCommand Function() build);
    bool commitShape(ToolContext ctx, EntityKind kind, GeometryPayload payload, {bool fillable = false});
  }
  class LineTool extends PlacementTool { LineTool(); }
  ```

  And the fixture, in `test/support/draw_fixture.dart`: `DrawScene`,
  `drawScene({bool snapToGrid = false})`, `DrawRig`,
  `drawRig(DraftDocument doc, PlacementTool tool, {bool flipY = true, bool objectSnap = true})`,
  `worldAt`, `hoverAt`, `clickAt`, `downAt`, `keyDown`,
  `kAnchorStart = (7137.3, 3161.7)`.

- [ ] **Step 1: The fixture.** Create `test/support/draw_fixture.dart`:

```dart
import 'package:flutter/services.dart'
    show KeyDownEvent, LogicalKeyboardKey, PhysicalKeyboardKey;
import 'package:flutter/widgets.dart' show KeyEventResult, Offset;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/src/camera_controller.dart';
import 'package:jet_cad_2d_flutter/src/draw/placement_tool.dart';
import 'package:jet_cad_2d_flutter/src/outline_cache.dart';
import 'package:jet_cad_2d_flutter/src/page_notifier.dart';
import 'package:jet_cad_2d_flutter/src/selection.dart';
import 'package:jet_cad_2d_flutter/src/snap_settings.dart';
import 'package:jet_cad_2d_flutter/src/tool.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'grip_fixture.dart' show gripCamera, pointerAt;
import 'selection_fixture.dart' show addEntity;

/// The anchor line's start: off every lattice, so a snapped point that went
/// through any arithmetic shows in the low bits (M-05k).
const double kAnchorX = 7137.3, kAnchorY = 3161.7;

final class DrawScene {
  DrawScene._(this.document, this.anchor);
  final DraftDocument document;
  final Handle anchor;
}

/// Spec 05, Testing: a 1:20 page anchored at (7000, 3000), grid snap off
/// unless asked, and one line from ([kAnchorX], [kAnchorY]) to
/// (7300.9, 3190.1). The root stays the identity.
DrawScene drawScene({bool snapToGrid = false}) {
  final doc = DraftDocument.empty(measurer: MetricModelMeasurer());
  PageComponent.register(doc.components);
  doc.commands.execute(SetComponentCommand<PageComponent>(
      doc.rootHandle,
      PageComponent(
          scaleDenominator: 20,
          originX: 7000,
          originY: 3000,
          snapToGrid: snapToGrid)));
  final anchor = addEntity(doc, doc.rootHandle, EntityKind.line,
      [kAnchorX, kAnchorY, 7300.9, 3190.1], []);
  doc.commands.clearHistory();
  expect(doc.tree[doc.rootHandle]!.transform.isIdentity, isTrue);
  return DrawScene._(doc, anchor);
}

/// Everything a drawing tool test drives, wired as the shell wires it.
final class DrawRig {
  DrawRig(this.document, this.tool,
      {required this.camera, bool objectSnap = true})
      : index = SpatialIndex(document),
        selection = SelectionController(document) {
    outlines = OutlineCache(document, selection);
    page = PageNotifier(document);
    snap = SnapSettings(objectSnap: objectSnap);
    context = ToolContext(
        document: document,
        index: index,
        camera: camera,
        selection: selection,
        page: page,
        snap: snap);
    tools = ToolController(initial: tool, context: context);
  }

  final DraftDocument document;
  final PlacementTool tool;
  final CameraController camera;
  final SpatialIndex index;
  final SelectionController selection;
  late final OutlineCache outlines;
  late final PageNotifier page;
  late final SnapSettings snap;
  late final ToolContext context;
  late final ToolController tools;

  void dispose() {
    tools.dispose();
    outlines.dispose();
    page.dispose();
    snap.dispose();
    camera.dispose();
    selection.dispose();
    index.dispose();
  }
}

/// The standard camera (spec 05, Testing): 03's `gripCamera`, centred on
/// the scene. Every tool test runs it for both [flipY] values.
DrawRig drawRig(DraftDocument doc, PlacementTool tool,
    {bool flipY = true, bool objectSnap = true}) {
  final rig = DrawRig(doc, tool,
      camera: gripCamera(centre: Vector2(7200, 3150), flipY: flipY),
      objectSnap: objectSnap);
  addTearDown(rig.dispose);
  return rig;
}

/// The world point the layer would hand the tool for screen [s].
Vector2 worldAt(DrawRig rig, Offset s) =>
    rig.camera.value.screenToWorld(Vector2(s.dx, s.dy));

void hoverAt(DrawRig rig, Offset s, {bool shift = false}) => rig.tool
    .onPointerMove(pointerAt(rig.camera, s, buttons: 0, shift: shift),
        rig.context);

/// A press with no hover before it (AR4, M-05z).
void downAt(DrawRig rig, Offset s, {bool shift = false}) => rig.tool
    .onPointerDown(pointerAt(rig.camera, s, shift: shift), rig.context);

/// Hover, press, release: what a mouse click delivers.
void clickAt(DrawRig rig, Offset s, {bool shift = false}) {
  hoverAt(rig, s, shift: shift);
  downAt(rig, s, shift: shift);
  rig.tool.onPointerUp(
      pointerAt(rig.camera, s, buttons: 0, shift: shift), rig.context);
}

KeyEventResult keyDown(
        DrawRig rig, LogicalKeyboardKey key, PhysicalKeyboardKey physical) =>
    rig.tool.onKey(
        KeyDownEvent(
            physicalKey: physical, logicalKey: key, timeStamp: Duration.zero),
        rig.context);
```

  If `analyze` reports an import as unused once Tasks 3–6 are done (for
  example `KeyEventResult`), remove it then. The fixture must stay clean.

- [ ] **Step 2: Write the failing tests.** Create
  `test/draw/placement_tool_test.dart`:

```dart
import 'dart:ui' show Rect, Size;

import 'package:flutter/services.dart'
    show KeyDownEvent, KeyUpEvent, LogicalKeyboardKey, PhysicalKeyboardKey;
import 'package:flutter/widgets.dart' show KeyEventResult, Offset;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/src/draw/line_tool.dart';
import 'package:jet_cad_2d_flutter/src/select_tool.dart';
import 'package:jet_cad_2d_flutter/src/viewport_transform.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/draw_fixture.dart';
import '../support/grip_fixture.dart' show screenOf, snapshot;
import '../support/spy_canvas.dart';

GeometryPayload payloadOf(DraftDocument doc, Handle h) =>
    doc.geometry.read(doc.entities.geomIndexAt(doc.entities.slotOf(h)!));

/// The newest entity's handle: the tools allocate ascending.
Handle newest(DraftDocument doc) =>
    doc.entities.handleAt(doc.entities.liveSlots.reduce((a, b) =>
        doc.entities.handleAt(a).value > doc.entities.handleAt(b).value
            ? a
            : b));

void main() {
  for (final flipY in const [true, false]) {
    group('flipY $flipY', () {
      test('B1 a point is the layer\'s world point, not the screen (M-05a)',
          () {
        final s = drawScene();
        final rig = drawRig(s.document, LineTool(), flipY: flipY);
        final a = screenOf(rig.camera, 7010.5, 3020.25);
        final b = screenOf(rig.camera, 7090.75, 3070.5);
        clickAt(rig, a);
        clickAt(rig, b);
        final p = payloadOf(s.document, newest(s.document));
        final wa = worldAt(rig, a), wb = worldAt(rig, b);
        expect(p.coords.toList(), [wa.x, wa.y, wb.x, wb.y],
            reason: 'exact: the stored values are the resolved points');
      });

      test('B2 a line started near an endpoint begins exactly on it '
          '(exit criterion 3)', () {
        final s = drawScene();
        final rig = drawRig(s.document, LineTool(), flipY: flipY);
        clickAt(rig,
            screenOf(rig.camera, kAnchorX, kAnchorY) + const Offset(3, -2));
        clickAt(rig, screenOf(rig.camera, 7050, 3050));
        final p = payloadOf(s.document, newest(s.document));
        expect(p.coords[0], kAnchorX);
        expect(p.coords[1], kAnchorY);
      });

      test('B3 the hover marker is drawn at the snapped point, and nothing '
          'when the raw point wins', () {
        final s = drawScene();
        final rig = drawRig(s.document, LineTool(), flipY: flipY);
        final at = screenOf(rig.camera, kAnchorX, kAnchorY);
        hoverAt(rig, at + const Offset(2, 2));
        final spy = SpyCanvas();
        rig.tool.paintOverlay(spy, rig.camera.value, const Size(800, 600));
        final squares = spy.named('drawRect').toList();
        expect(squares, hasLength(1), reason: 'an endpoint: a square');
        final r = squares.single.args[0] as Rect;
        expect(r.center.dx, closeTo(at.dx, 1e-6));
        expect(r.center.dy, closeTo(at.dy, 1e-6));
        hoverAt(rig, screenOf(rig.camera, 7050, 3050));
        final none = SpyCanvas();
        rig.tool.paintOverlay(none, rig.camera.value, const Size(800, 600));
        expect(none.calls, isEmpty, reason: 'grid off, nothing hit');
      });
    });
  }

  test('B4 Escape mid-shape is byte-identical; an idle Escape is ignored '
      '(M-05m)', () {
    final s = drawScene();
    final rig = drawRig(s.document, LineTool());
    final before = snapshot(s.document);
    clickAt(rig, screenOf(rig.camera, 7010, 3020));
    expect(rig.tool.isPending, isTrue);
    expect(
        keyDown(rig, LogicalKeyboardKey.escape, PhysicalKeyboardKey.escape),
        KeyEventResult.handled);
    expect(rig.tool.isPending, isFalse);
    expect(snapshot(s.document), before);
    expect(
        keyDown(rig, LogicalKeyboardKey.escape, PhysicalKeyboardKey.escape),
        KeyEventResult.ignored,
        reason: 'idle: it bubbles to the shell, which returns to Select');
  });

  test('B5 undo keys are swallowed mid-shape and pass through when idle', () {
    final s = drawScene();
    final rig = drawRig(s.document, LineTool());
    expect(keyDown(rig, LogicalKeyboardKey.keyZ, PhysicalKeyboardKey.keyZ),
        KeyEventResult.ignored);
    clickAt(rig, screenOf(rig.camera, 7010, 3020));
    expect(keyDown(rig, LogicalKeyboardKey.keyZ, PhysicalKeyboardKey.keyZ),
        KeyEventResult.handled);
    expect(
        rig.tool.onKey(
            const KeyUpEvent(
                physicalKey: PhysicalKeyboardKey.keyZ,
                logicalKey: LogicalKeyboardKey.keyZ,
                timeStamp: Duration.zero),
            rig.context),
        KeyEventResult.ignored);
  });

  test('B6 a pan mid-shape re-resolves the hover, and the next click lands '
      'at the new camera\'s point (Review Focus 3)', () {
    final s = drawScene();
    final rig = drawRig(s.document, LineTool());
    clickAt(rig, screenOf(rig.camera, 7010, 3020));
    final screen = screenOf(rig.camera, 7060, 3040);
    hoverAt(rig, screen);
    final before = Vector2.copy(rig.tool.hoverPoint);
    var notified = 0;
    rig.tool.addListener(() => notified++);
    rig.camera.value = ViewportTransform(
        worldToScreenMatrix: Transform2.translation(37, -21)
            .multiply(rig.camera.value.worldToScreenMatrix));
    expect(notified, greaterThan(0), reason: 'the camera listener fired');
    expect(rig.tool.hoverPoint, isNot(before));
    downAt(rig, screen);
    final p = payloadOf(s.document, newest(s.document));
    final w = worldAt(rig, screen);
    expect(p.coords[2], w.x);
    expect(p.coords[3], w.y);
  });

  test('B7 shift pins the ortho axis from the last point, and a shift press '
      're-resolves at once', () {
    final s = drawScene();
    final rig = drawRig(s.document, LineTool());
    clickAt(rig, screenOf(rig.camera, 7010.5, 3020.25));
    final first = Vector2.copy(rig.tool.points.last);
    hoverAt(rig, screenOf(rig.camera, 7090, 3031));
    expect(rig.tool.hoverPoint.y, isNot(first.y));
    rig.tool.onKey(
        const KeyDownEvent(
            physicalKey: PhysicalKeyboardKey.shiftLeft,
            logicalKey: LogicalKeyboardKey.shiftLeft,
            timeStamp: Duration.zero),
        rig.context);
    expect(rig.tool.hoverPoint.y, first.y,
        reason: '|dx| > |dy|: y pinned to the base, exactly');
  });

  test('B8 a denied commit drops the shape and allocates no handle', () {
    final s = drawScene();
    final rig = drawRig(s.document, LineTool());
    clickAt(rig, screenOf(rig.camera, 7010, 3020));
    s.document.commands.permissions = DraftPermissions.runtime;
    final seed = s.document.handleSeed.current;
    final before = snapshot(s.document);
    clickAt(rig, screenOf(rig.camera, 7090, 3050));
    expect(snapshot(s.document), before);
    expect(s.document.handleSeed.current, seed);
    expect(rig.tool.isPending, isFalse);
  });

  test('B9 a tool switch mid-shape is byte-identical and detaches the '
      'camera; a pointer exit keeps the shape', () {
    final s = drawScene();
    final line = LineTool();
    final rig = drawRig(s.document, line);
    clickAt(rig, screenOf(rig.camera, 7010, 3020));
    rig.tool.onPointerExit(rig.context);
    expect(line.isPending, isTrue, reason: 'click by click, not a drag');
    expect(line.hoverVisible, isFalse);
    final before = snapshot(s.document);
    rig.tools.activate(SelectTool());
    expect(line.isPending, isFalse);
    expect(snapshot(s.document), before);
    var notified = 0;
    line.addListener(() => notified++);
    rig.camera.value = ViewportTransform(
        worldToScreenMatrix: Transform2.translation(5, 5)
            .multiply(rig.camera.value.worldToScreenMatrix));
    expect(notified, 0, reason: 'the camera listener is detached');
  });
}
```

  Create `test/draw/line_tool_test.dart`:

```dart
import 'dart:ui' show Path, Rect;

import 'package:flutter/services.dart'
    show LogicalKeyboardKey, PhysicalKeyboardKey;
import 'package:flutter/widgets.dart' show Offset;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/src/draw/line_tool.dart';
import 'package:jet_cad_2d_flutter/src/selection_style.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/draw_fixture.dart';
import '../support/grip_fixture.dart' show screenOf, snapshot;
import '../support/spy_canvas.dart';

GeometryPayload payloadOf(DraftDocument doc, Handle h) =>
    doc.geometry.read(doc.entities.geomIndexAt(doc.entities.slotOf(h)!));

List<Handle> linesOf(DraftDocument doc, Handle anchor) {
  final out = <Handle>[
    for (final slot in doc.entities.liveSlots)
      if (doc.entities.kindAt(slot) == EntityKind.line &&
          doc.entities.handleAt(slot) != anchor)
        doc.entities.handleAt(slot),
  ];
  out.sort((a, b) => a.value.compareTo(b.value));
  return out;
}

void main() {
  for (final flipY in const [true, false]) {
    test('L1 flipY $flipY: a chain shares its snapped joint exactly (M-05k)',
        () {
      final s = drawScene();
      final rig = drawRig(s.document, LineTool(), flipY: flipY);
      clickAt(rig, screenOf(rig.camera, 7010, 3020));
      clickAt(rig,
          screenOf(rig.camera, kAnchorX, kAnchorY) + const Offset(2, -3));
      clickAt(rig, screenOf(rig.camera, 7090, 3110));
      final lines = linesOf(s.document, s.anchor);
      expect(lines, hasLength(2));
      final first = payloadOf(s.document, lines[0]);
      final second = payloadOf(s.document, lines[1]);
      expect(first.coords[2], kAnchorX);
      expect(first.coords[3], kAnchorY);
      expect(second.coords[0], first.coords[2]);
      expect(second.coords[1], first.coords[3]);
      expect(s.document.commands.undoDepth, 2, reason: 'one per segment');
    });
  }

  test('L2 clicking the current start again ends the chain', () {
    final s = drawScene();
    final rig = drawRig(s.document, LineTool());
    clickAt(rig, screenOf(rig.camera, 7010, 3020));
    final end = screenOf(rig.camera, 7090, 3050);
    clickAt(rig, end);
    final depth = s.document.commands.undoDepth;
    clickAt(rig, end + const Offset(1, 1));
    expect(s.document.commands.undoDepth, depth);
    expect(rig.tool.isPending, isFalse);
  });

  test('L3 before the first segment, a second click on the start is refused '
      'and the tool stays pending (M-05x)', () {
    final s = drawScene();
    final rig = drawRig(s.document, LineTool());
    final start = screenOf(rig.camera, 7010, 3020);
    clickAt(rig, start);
    final before = snapshot(s.document);
    clickAt(rig, start);
    expect(snapshot(s.document), before);
    expect(rig.tool.isPending, isTrue);
  });

  test('L4 Enter ends the chain, the segments stay, and each undo removes '
      'one', () {
    final s = drawScene();
    final rig = drawRig(s.document, LineTool());
    clickAt(rig, screenOf(rig.camera, 7010, 3020));
    clickAt(rig, screenOf(rig.camera, 7050, 3060));
    clickAt(rig, screenOf(rig.camera, 7090, 3020));
    keyDown(rig, LogicalKeyboardKey.enter, PhysicalKeyboardKey.enter);
    expect(rig.tool.isPending, isFalse);
    expect(linesOf(s.document, s.anchor), hasLength(2));
    s.document.commands.undo();
    expect(linesOf(s.document, s.anchor), hasLength(1));
    s.document.commands.undo();
    expect(linesOf(s.document, s.anchor), isEmpty);
  });

  test('L5 a zero-length segment is refused under Tolerance', () {
    final s = drawScene(snapToGrid: true);
    final rig = drawRig(s.document, LineTool(), objectSnap: false);
    final a = screenOf(rig.camera, 7010.02, 3020.01);
    clickAt(rig, a);
    final before = snapshot(s.document);
    clickAt(rig, a + const Offset(0.5, 0.5)); // same lattice point
    expect(snapshot(s.document), before);
    expect(rig.tool.isPending, isTrue);
  });

  test('L6 the rubber band is one path from the start to the hover', () {
    final s = drawScene();
    final rig = drawRig(s.document, LineTool());
    clickAt(rig, screenOf(rig.camera, 7010, 3020));
    hoverAt(rig, screenOf(rig.camera, 7090, 3060));
    final origin = Vector2(7000, 3000);
    final spy = SpyCanvas();
    rig.tool.paintWorldOverlay(spy, origin, rig.camera.value.scale);
    final paths = spy.named('drawPath').toList();
    expect(paths, hasLength(1));
    expect(paths.single.color?.toARGB32(), kPreviewColor.toARGB32());
    final bounds = (paths.single.args[0] as Path).getBounds();
    final a = rig.tool.points.single, h = rig.tool.hoverPoint;
    final want = Rect.fromPoints(Offset(a.x - origin.x, a.y - origin.y),
        Offset(h.x - origin.x, h.y - origin.y));
    expect(bounds.left, closeTo(want.left, 1e-3));
    expect(bounds.bottom, closeTo(want.bottom, 1e-3));
  });
}
```

- [ ] **Step 3: Run them and see them fail.**
  Run: `cd packages/jet_cad_2d_flutter && CI=true flutter test test/draw/placement_tool_test.dart test/draw/line_tool_test.dart`
  Expected: compile errors, because `placement_tool.dart` and
  `line_tool.dart` do not exist.

- [ ] **Step 4: Implement `lib/src/draw/placement_tool.dart`.**

```dart
import 'dart:ui' show Canvas, Offset, Paint, PaintingStyle, Path, Size;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/gestures.dart' show kPrimaryButton;
import 'package:flutter/services.dart'
    show
        KeyDownEvent,
        KeyEvent,
        KeyRepeatEvent,
        KeyUpEvent,
        LogicalKeyboardKey,
        MouseCursor,
        SystemMouseCursors;
import 'package:flutter/widgets.dart' show KeyEventResult;
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../selection_style.dart';
import '../snap_marker.dart';
import '../tool.dart';
import '../viewport_transform.dart';

/// Spec 05 D3: what every drawing tool shares.
/// - Points resolve through the tool's own placed points first, then 03's
///   `resolveDragPoint` (D4).
/// - The hover marker, and a camera listener while a shape is pending.
/// - Escape, Enter and shift; every other key-down is swallowed mid-shape.
/// - One command per finished shape, checked against the permissions
///   before its handle is allocated (Ruling 05-3).
///
/// Placement is click by click: only a primary press places a point, and a
/// move with the button held is a hover (Ruling 05-13).
abstract class PlacementTool extends Tool {
  PlacementTool({this.fill});

  /// Spec 05 D13: the shell's Fill toggle. Null, or false: outlines only.
  final ValueListenable<bool>? fill;

  /// The placed points, as exact world values (invariant 1).
  final List<Vector2> points = <Vector2>[];

  /// True only while [accept] runs on a self-snap's stored point (Ruling
  /// 05-4).
  bool acceptingSelf = false;

  /// Spec 05 D12: reset each frame, never reallocated.
  final Path band = Path();
  final Paint bandPaint = Paint()
    ..color = kPreviewColor
    ..style = PaintingStyle.stroke;

  final DragPoint _hover = DragPoint();
  final SnapResult _scratch = SnapResult();
  final Paint _markerPaint = Paint()
    ..color = kSnapMarkerColor
    ..style = PaintingStyle.stroke
    ..strokeWidth = kSnapMarkerStrokePixels;
  bool _hoverVisible = false;
  Offset _lastScreen = Offset.zero;
  bool _lastShift = false;
  ToolContext? _listening;

  @override
  ToolPhase get phase => ToolPhase.idle;

  @override
  MouseCursor get cursor => SystemMouseCursors.precise;

  bool get isPending => points.isNotEmpty;
  Vector2 get hoverPoint => _hover.point;
  bool get hoverVisible => _hoverVisible;
  SnapKind? get hoverKind => _hover.objectKind;

  /// Spec 05 D4: the last placed point, or none.
  Vector2? get orthoBase => points.isEmpty ? null : points.last;

  /// A stored placed point this raw point should land on exactly, or null.
  Vector2? selfSnap(Vector2 raw, double apertureWorld) => null;

  void accept(Vector2 point, ToolContext ctx);

  /// Enter while a shape is pending.
  void finish(ToolContext ctx) {}

  /// Every hover's raw world point (the arc tracks it).
  void hovered(Vector2 raw) {}

  void clearShape() => points.clear();

  /// Coordinates handed to [canvas] are `world − origin` (Ruling 03-3).
  void paintRubberBand(Canvas canvas, Vector2 origin, double scale);

  /// Spec 05 D4, in exactly this order: the self-snap wins outright, even
  /// over a nearer entity endpoint; otherwise 03's chain, unchanged.
  /// Returns the self-snap's stored point when one won.
  Vector2? _resolve(ToolContext ctx, Vector2 raw, bool shift) {
    final cam = ctx.camera.value;
    final aperture = kSnapAperturePixels / cam.scale;
    final self = selfSnap(raw, aperture);
    if (self != null) {
      _hover.point.setFrom(self);
      _hover.objectKind = SnapKind.endpoint; // Ruling 05-2
      _hover.grid = false;
      return self;
    }
    final page = ctx.page?.value;
    resolveDragPoint(
      raw: raw,
      orthoBase: shift ? orthoBase : null,
      index: ctx.index,
      apertureWorld: aperture,
      objectSnap: ctx.snap?.objectSnap ?? true,
      page: page,
      gridStepMm: dragGridStepMm(page, cam.scale),
      scratch: _scratch,
      out: _hover,
    );
    return null;
  }

  @override
  void onPointerMove(ToolPointerEvent e, ToolContext ctx) {
    _lastScreen = e.screen;
    _lastShift = e.shift;
    _resolve(ctx, e.world, e.shift);
    _hoverVisible = true;
    hovered(e.world);
    notifyListeners();
  }

  @override
  void onPointerDown(ToolPointerEvent e, ToolContext ctx) {
    if (e.buttons & kPrimaryButton == 0) return;
    _lastScreen = e.screen;
    _lastShift = e.shift;
    // Spec 05 D4: `e.world`, the layer's inverse camera at this event;
    // never `e.screen` (M-05a).
    final self = _resolve(ctx, e.world, e.shift);
    _hoverVisible = true;
    acceptingSelf = self != null;
    try {
      accept(self ?? Vector2.copy(_hover.point), ctx);
    } finally {
      acceptingSelf = false;
    }
    _syncCamera(ctx);
    notifyListeners();
  }

  @override
  void onPointerUp(ToolPointerEvent e, ToolContext ctx) {}

  /// The shape stays: placement is click by click, not a drag.
  @override
  void onPointerExit(ToolContext ctx) {
    _hoverVisible = false;
    notifyListeners();
  }

  @override
  KeyEventResult onKey(KeyEvent event, ToolContext ctx) {
    final key = event.logicalKey;
    if ((key == LogicalKeyboardKey.shiftLeft ||
            key == LogicalKeyboardKey.shiftRight) &&
        event is! KeyRepeatEvent) {
      _lastShift = event is KeyDownEvent;
      if (_hoverVisible) _reresolve(ctx);
    }
    if (event is KeyUpEvent || !isPending) return KeyEventResult.ignored;
    if (event is KeyDownEvent) {
      if (key == LogicalKeyboardKey.escape) {
        cancel(ctx);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.enter ||
          key == LogicalKeyboardKey.numpadEnter) {
        finish(ctx);
        _syncCamera(ctx);
        notifyListeners();
        return KeyEventResult.handled;
      }
    }
    // Every other key-down and repeat mid-shape: undo and redo never land
    // on a half-placed shape (spec 05 D3, as 03 D5 during a drag).
    return KeyEventResult.handled;
  }

  /// Every cancel path (Escape, `ToolController.activate`, the layer's
  /// deactivate and dispose) drops the pending shape and never touches the
  /// document (invariant 3).
  @override
  void cancel(ToolContext ctx) {
    clearShape();
    _syncCamera(ctx);
    notifyListeners();
  }

  /// Ruling 05-3: the permission check runs before [build], so a denied
  /// shape allocates no handle. Returns whether the command ran.
  bool commit(ToolContext ctx, DraftCommand Function() build) {
    if (!ctx.document.commands.permissions.allows(Capability.geometry)) {
      return false;
    }
    ctx.execute(build());
    return true;
  }

  /// Spec 05 D13: with Fill on and a [fillable] shape, one region when the
  /// boundary can fill, and the plain boundary when it cannot.
  bool commitShape(ToolContext ctx, EntityKind kind, GeometryPayload payload,
          {bool fillable = false}) =>
      commit(ctx, () {
        if (fillable && (fill?.value ?? false)) {
          final region = addDraftedRegion(ctx.document, kind, payload);
          if (region != null) return region;
        }
        return addDrafted(ctx.document, kind, payload);
      });

  void _reresolve(ToolContext ctx) {
    final world = ctx.camera.value
        .screenToWorld(Vector2(_lastScreen.dx, _lastScreen.dy));
    _resolve(ctx, world, _lastShift);
    hovered(world);
    notifyListeners();
  }

  void _syncCamera(ToolContext ctx) {
    if (isPending && _listening == null) {
      _listening = ctx;
      ctx.camera.addListener(_onCamera);
    } else if (!isPending && _listening != null) {
      _listening!.camera.removeListener(_onCamera);
      _listening = null;
    }
  }

  void _onCamera() {
    final ctx = _listening;
    if (ctx != null) _reresolve(ctx);
  }

  @override
  void paintOverlay(Canvas canvas, ViewportTransform camera, Size viewport) {
    if (!_hoverVisible) return;
    final m = camera.worldToScreenMatrix;
    final p = _hover.point;
    drawSnapMarker(
        canvas,
        Offset(m.a * p.x + m.c * p.y + m.e, m.b * p.x + m.d * p.y + m.f),
        _hover.objectKind,
        grid: _hover.grid,
        paint: _markerPaint);
  }

  @override
  void paintWorldOverlay(Canvas canvas, Vector2 origin, double scale) {
    bandPaint.strokeWidth = kPreviewStrokePixels / scale;
    paintRubberBand(canvas, origin, scale);
  }

  @override
  void dispose() {
    _listening?.camera.removeListener(_onCamera);
    _listening = null;
    super.dispose();
  }
}
```

  Implement `lib/src/draw/line_tool.dart`:

```dart
import 'dart:ui' show Canvas;

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../tool.dart';
import 'placement_tool.dart';

/// Spec 05 D6: AutoCAD's LINE. Each click commits one segment, and its end
/// is the next segment's start: the same stored values. Fill does not
/// apply.
class LineTool extends PlacementTool {
  LineTool();

  int _segments = 0;

  @override
  String get name => 'Line';

  /// The current start ends the chain, but only once a segment is committed
  /// (M-05x). Before that, a second click on the start is a zero-length
  /// segment and is refused.
  @override
  Vector2? selfSnap(Vector2 raw, double apertureWorld) =>
      _segments > 0 &&
              points.isNotEmpty &&
              raw.distanceTo(points.last) <= apertureWorld
          ? points.last
          : null;

  @override
  void accept(Vector2 point, ToolContext ctx) {
    if (points.isEmpty) {
      points.add(point);
      return;
    }
    if (acceptingSelf) {
      clearShape();
      return;
    }
    final start = points.last;
    if (isDegenerateSegment(start, point)) return;
    if (commit(ctx,
        () => addDrafted(ctx.document, EntityKind.line, linePayload(start, point)))) {
      _segments++;
      points
        ..clear()
        ..add(point);
    } else {
      clearShape();
    }
  }

  @override
  void finish(ToolContext ctx) => clearShape();

  @override
  void clearShape() {
    super.clearShape();
    _segments = 0;
  }

  @override
  void paintRubberBand(Canvas canvas, Vector2 origin, double scale) {
    if (points.isEmpty || !hoverVisible) return;
    final a = points.last, h = hoverPoint;
    band
      ..reset()
      ..moveTo(a.x - origin.x, a.y - origin.y)
      ..lineTo(h.x - origin.x, h.y - origin.y);
    canvas.drawPath(band, bandPaint);
  }
}
```

  Add the two exports to `lib/jet_cad_2d_flutter.dart`, after `export
  'src/draw_sink.dart';`.

- [ ] **Step 5: Run the tests and see them pass.**
  Run: `cd packages/jet_cad_2d_flutter && CI=true flutter test test/draw/`
  Expected: `All tests passed!`: 9 in B, counting the three flipY-grouped
  tests twice (12 test cases), and 7 in L (L1 twice). Paste the count.

- [ ] **Step 6: Gate and commit.** Run the `jet_cad_2d_flutter` line.

```bash
git add packages/jet_cad_2d_flutter/lib/src/draw/placement_tool.dart packages/jet_cad_2d_flutter/lib/src/draw/line_tool.dart packages/jet_cad_2d_flutter/lib/jet_cad_2d_flutter.dart packages/jet_cad_2d_flutter/test/support/draw_fixture.dart packages/jet_cad_2d_flutter/test/draw/placement_tool_test.dart packages/jet_cad_2d_flutter/test/draw/line_tool_test.dart
git commit -m "$(cat <<'EOF'
feat(draw): PlacementTool and the chained line tool

A shared base resolves each point through the tool's own placed points,
then 03's resolveDragPoint; draws the hover marker; follows the camera
while a shape is pending; takes Escape, Enter and shift and swallows
every other key mid-shape; and commits one command, checking permissions
before a handle is allocated. LineTool chains segments on the same stored
joint. 02's Tool API is unchanged. Spec 05 D3, D4, D6.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 4: `PolylineTool`, `RectangleTool`, Fill, and the overlay's structural test

Package: `packages/jet_cad_2d_flutter`.

**Files:**
- Create: `lib/src/draw/polyline_tool.dart`, `lib/src/draw/rectangle_tool.dart`
- Modify: `lib/jet_cad_2d_flutter.dart` (two exports)
- Test: `test/draw/polyline_tool_test.dart` (PL1–PL8),
  `test/draw/rectangle_tool_test.dart` (R1–R5),
  `test/draw/draw_overlay_test.dart` (OV1–OV2)

**Interfaces:**
- Consumes:
  - Task 3: `PlacementTool` and the fixture.
  - Task 1: `polylinePayload`, `rectanglePayload`,
    `isDegenerateRectangle`, `kDraftFillColor`.
  - 03: `SelectionOverlayPainter`.
- Produces:
  - `class PolylineTool extends PlacementTool { PolylineTool({ValueListenable<bool>? fill}); }`
  - `class RectangleTool extends PlacementTool { RectangleTool({ValueListenable<bool>? fill}); }`

- [ ] **Step 1: Write the failing tests.** Create
  `test/draw/polyline_tool_test.dart`:

```dart
import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:flutter/services.dart'
    show KeyDownEvent, LogicalKeyboardKey, PhysicalKeyboardKey;
import 'package:flutter/widgets.dart' show Offset;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/src/draw/polyline_tool.dart';

import '../support/draw_fixture.dart';
import '../support/grip_fixture.dart' show screenOf, snapshot;

GeometryPayload payloadOf(DraftDocument doc, Handle h) =>
    doc.geometry.read(doc.entities.geomIndexAt(doc.entities.slotOf(h)!));

List<Handle> ofKind(DraftDocument doc, EntityKind kind) {
  final out = <Handle>[
    for (final slot in doc.entities.liveSlots)
      if (doc.entities.kindAt(slot) == kind) doc.entities.handleAt(slot),
  ];
  out.sort((a, b) => a.value.compareTo(b.value));
  return out;
}

void main() {
  for (final flipY in const [true, false]) {
    test('PL1 flipY $flipY: three clicks and Enter make an open polyline, '
        'one undo step', () {
      final s = drawScene();
      final rig = drawRig(s.document, PolylineTool(), flipY: flipY);
      final a = screenOf(rig.camera, 7010.5, 3020.25);
      final b = screenOf(rig.camera, 7060.75, 3090.5);
      final c = screenOf(rig.camera, 7120.25, 3030.75);
      clickAt(rig, a);
      clickAt(rig, b);
      clickAt(rig, c);
      keyDown(rig, LogicalKeyboardKey.enter, PhysicalKeyboardKey.enter);
      final h = ofKind(s.document, EntityKind.polyline).single;
      final p = payloadOf(s.document, h);
      final wa = worldAt(rig, a), wb = worldAt(rig, b), wc = worldAt(rig, c);
      expect(p.coords.toList(), [wa.x, wa.y, wb.x, wb.y, wc.x, wc.y]);
      expect(isClosedPolyline(p), isFalse);
      expect(s.document.commands.undoDepth, 1);
    });

    test('PL3 flipY $flipY: clicking the first vertex closes on the stored '
        'point itself (M-05i)', () {
      final s = drawScene();
      final rig = drawRig(s.document, PolylineTool(), flipY: flipY);
      final a = screenOf(rig.camera, 7010.5, 3020.25);
      clickAt(rig, a);
      clickAt(rig, screenOf(rig.camera, 7060.75, 3090.5));
      clickAt(rig, screenOf(rig.camera, 7120.25, 3030.75));
      clickAt(rig, a + const Offset(3, -2));
      final p =
          payloadOf(s.document, ofKind(s.document, EntityKind.polyline).single);
      expect(p.pointCount, 4);
      expect(p.coords[6], p.coords[0]);
      expect(p.coords[7], p.coords[1]);
      expect(isClosedPolyline(p), isTrue);
    });
  }

  test('PL2 clicking the last vertex again finishes it open', () {
    final s = drawScene();
    final rig = drawRig(s.document, PolylineTool());
    clickAt(rig, screenOf(rig.camera, 7010, 3020));
    final b = screenOf(rig.camera, 7060, 3090);
    clickAt(rig, b);
    clickAt(rig, b + const Offset(1, 2));
    final p =
        payloadOf(s.document, ofKind(s.document, EntityKind.polyline).single);
    expect(p.pointCount, 2);
    expect(rig.tool.isPending, isFalse);
  });

  test('PL4 with Fill on, closing commits one region; one undo removes both '
      '(M-05p)', () {
    final s = drawScene();
    final fill = ValueNotifier<bool>(true);
    addTearDown(fill.dispose);
    final rig = drawRig(s.document, PolylineTool(fill: fill));
    final a = screenOf(rig.camera, 7010, 3020);
    clickAt(rig, a);
    clickAt(rig, screenOf(rig.camera, 7060, 3090));
    clickAt(rig, screenOf(rig.camera, 7120, 3030));
    clickAt(rig, a);
    final boundary = ofKind(s.document, EntityKind.polyline).single;
    final fills = s.document.fills.fillsOf(boundary);
    expect(fills, hasLength(1));
    expect(fills.single.value, lessThan(boundary.value));
    expect(s.document.commands.undoDepth, 1);
    s.document.commands.undo();
    expect(ofKind(s.document, EntityKind.polyline), isEmpty);
    expect(ofKind(s.document, EntityKind.fill), isEmpty);
  });

  test('PL5 a bow tie with Fill on still commits, as a plain boundary '
      '(M-05q)', () {
    final s = drawScene();
    final fill = ValueNotifier<bool>(true);
    addTearDown(fill.dispose);
    final rig = drawRig(s.document, PolylineTool(fill: fill),
        objectSnap: false);
    final a = screenOf(rig.camera, 7000, 3000);
    clickAt(rig, a);
    clickAt(rig, screenOf(rig.camera, 7100, 3100));
    clickAt(rig, screenOf(rig.camera, 7100, 3000));
    clickAt(rig, screenOf(rig.camera, 7000, 3100));
    clickAt(rig, a);
    final boundary = ofKind(s.document, EntityKind.polyline).single;
    expect(isClosedPolyline(payloadOf(s.document, boundary)), isTrue);
    expect(ofKind(s.document, EntityKind.fill), isEmpty);
    expect(s.document.fills.fillsOf(boundary), isEmpty);
  });

  test('PL6 shift pins the third vertex to the second, not the first (M-05h)',
      () {
    final s = drawScene();
    final tool = PolylineTool();
    final rig = drawRig(s.document, tool, objectSnap: false);
    clickAt(rig, screenOf(rig.camera, 7010.5, 3020.25));
    clickAt(rig, screenOf(rig.camera, 7100.25, 3090.75));
    clickAt(rig, screenOf(rig.camera, 7180.5, 3101.25), shift: true);
    expect(tool.points, hasLength(3));
    expect(tool.points[2].y, tool.points[1].y,
        reason: '|dx| > |dy| from the last vertex: y pinned to it');
    expect(tool.points[2].y, isNot(tool.points[0].y));
  });

  test('PL7 a tiny triangle closes on its first vertex; two coincident '
      'clicks are ignored (Review Focus 4)', () {
    final s = drawScene();
    final tool = PolylineTool();
    final rig = drawRig(s.document, tool, objectSnap: false);
    // Screen offsets against a 10 px aperture. b is 20 px from a. c is
    // 16.6 px from b, so placing it cannot finish on b; it is 8.6 px from
    // a, but with two vertices the first is not yet a close target. The
    // close click q is 3.6 px from a and 5 px from c: inside both.
    final a = screenOf(rig.camera, 7050, 3050);
    clickAt(rig, a);
    clickAt(rig, a); // coincident with the only vertex: ignored
    expect(tool.points, hasLength(1));
    clickAt(rig, a + const Offset(20, 0));
    clickAt(rig, a + const Offset(5, 7));
    expect(tool.points, hasLength(3));
    clickAt(rig, a + const Offset(2, 3)); // q: near both first and last
    final p =
        payloadOf(s.document, ofKind(s.document, EntityKind.polyline).single);
    expect(isClosedPolyline(p), isTrue, reason: 'first beats last at 3+');
  });

  test('PL8 its own first vertex beats a nearer entity endpoint (M-05w)', () {
    final s = drawScene();
    final rig = drawRig(s.document, PolylineTool());
    // The first vertex sits 6 px from the anchor's start on screen.
    final anchor = screenOf(rig.camera, kAnchorX, kAnchorY);
    final first = anchor + const Offset(6, 0);
    rig.snap.toggleObjectSnap(); // off: place the first vertex raw
    clickAt(rig, first);
    rig.snap.toggleObjectSnap(); // back on
    clickAt(rig, screenOf(rig.camera, 7060, 3090));
    clickAt(rig, screenOf(rig.camera, 7120, 3030));
    // 4 px from the first vertex and 2 px from the anchor: both inside.
    clickAt(rig, anchor + const Offset(2, 0));
    final p =
        payloadOf(s.document, ofKind(s.document, EntityKind.polyline).single);
    expect(isClosedPolyline(p), isTrue);
    expect(p.coords[6], isNot(kAnchorX));
  });

  test('PL9 Escape with three vertices placed is byte-identical (M-05l)', () {
    final s = drawScene();
    final rig = drawRig(s.document, PolylineTool());
    final before = snapshot(s.document);
    clickAt(rig, screenOf(rig.camera, 7010, 3020));
    clickAt(rig, screenOf(rig.camera, 7060, 3090));
    clickAt(rig, screenOf(rig.camera, 7120, 3030));
    rig.tool.onKey(
        const KeyDownEvent(
            physicalKey: PhysicalKeyboardKey.escape,
            logicalKey: LogicalKeyboardKey.escape,
            timeStamp: Duration.zero),
        rig.context);
    expect(snapshot(s.document), before);
  });
}
```

  Create `test/draw/rectangle_tool_test.dart`:

```dart
import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/src/draw/rectangle_tool.dart';

import '../support/draw_fixture.dart';
import '../support/grip_fixture.dart' show screenOf, snapshot;

GeometryPayload payloadOf(DraftDocument doc, Handle h) =>
    doc.geometry.read(doc.entities.geomIndexAt(doc.entities.slotOf(h)!));

List<Handle> ofKind(DraftDocument doc, EntityKind kind) => [
      for (final slot in doc.entities.liveSlots)
        if (doc.entities.kindAt(slot) == kind) doc.entities.handleAt(slot),
    ]..sort((a, b) => a.value.compareTo(b.value));

void main() {
  for (final flipY in const [true, false]) {
    test('R1 flipY $flipY: two corners make a closed world-axis rectangle',
        () {
      final s = drawScene();
      final rig = drawRig(s.document, RectangleTool(),
          flipY: flipY, objectSnap: false);
      final a = screenOf(rig.camera, 7010.5, 3020.25);
      final b = screenOf(rig.camera, 7090.75, 3070.5);
      clickAt(rig, a);
      clickAt(rig, b);
      final p =
          payloadOf(s.document, ofKind(s.document, EntityKind.polyline).single);
      final c1 = worldAt(rig, a), c2 = worldAt(rig, b);
      expect(p.coords.toList(),
          [c1.x, c1.y, c2.x, c1.y, c2.x, c2.y, c1.x, c2.y, c1.x, c1.y]);
      expect(isClosedPolyline(p), isTrue);
    });
  }

  test('R2 a zero-width rectangle is refused', () {
    final s = drawScene(snapToGrid: true);
    final rig = drawRig(s.document, RectangleTool(), objectSnap: false);
    final a = screenOf(rig.camera, 7010, 3020);
    clickAt(rig, a);
    final before = snapshot(s.document);
    clickAt(rig, screenOf(rig.camera, 7010.01, 3090));
    expect(snapshot(s.document), before);
    expect(rig.tool.isPending, isTrue);
  });

  test('R3 with Fill on, one region in the fill colour, one undo step '
      '(M-05o, M-05p)', () {
    final s = drawScene();
    final fill = ValueNotifier<bool>(true);
    addTearDown(fill.dispose);
    final rig = drawRig(s.document, RectangleTool(fill: fill),
        objectSnap: false);
    clickAt(rig, screenOf(rig.camera, 7010, 3020));
    clickAt(rig, screenOf(rig.camera, 7090, 3070));
    final boundary = ofKind(s.document, EntityKind.polyline).single;
    final fillHandle = s.document.fills.fillsOf(boundary).single;
    final record =
        s.document.entities.read(s.document.entities.slotOf(fillHandle)!);
    expect(record.color, kDraftFillColor);
    expect(fillHandle.value, lessThan(boundary.value));
    expect(s.document.commands.undoDepth, 1);
    s.document.commands.undo();
    expect(ofKind(s.document, EntityKind.fill), isEmpty);
  });

  test('R4 with Fill off, a plain polyline and no fill', () {
    final s = drawScene();
    final fill = ValueNotifier<bool>(false);
    addTearDown(fill.dispose);
    final rig = drawRig(s.document, RectangleTool(fill: fill),
        objectSnap: false);
    clickAt(rig, screenOf(rig.camera, 7010, 3020));
    clickAt(rig, screenOf(rig.camera, 7090, 3070));
    expect(ofKind(s.document, EntityKind.fill), isEmpty);
    expect(ofKind(s.document, EntityKind.polyline), hasLength(1));
  });

  test('R5 a filled rectangle round-trips through the codec as a closed '
      'polyline with its fill (exit criterion 5)', () {
    final s = drawScene();
    final fill = ValueNotifier<bool>(true);
    addTearDown(fill.dispose);
    final rig = drawRig(s.document, RectangleTool(fill: fill),
        objectSnap: false);
    clickAt(rig, screenOf(rig.camera, 7010, 3020));
    clickAt(rig, screenOf(rig.camera, 7090, 3070));
    final text = snapshot(s.document);
    final back = DraftDocumentCodec.decodeString(text,
        measurer: MetricModelMeasurer(),
        registerComponents: PageComponent.register);
    final boundary = ofKind(back, EntityKind.polyline).single;
    expect(isClosedPolyline(payloadOf(back, boundary)), isTrue);
    expect(back.fills.fillsOf(boundary), hasLength(1));
    expect(snapshot(back), text);
  });
}
```

  (`registerComponents` takes `void Function(ComponentRegistry)`. If
  `PageComponent.register` has that shape, pass it directly. Otherwise pass
  `(r) => PageComponent.register(r)`.)

  Create `test/draw/draw_overlay_test.dart`:

```dart
import 'dart:ui' show Size;

import 'package:flutter/widgets.dart' show Listenable;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/src/draw/polyline_tool.dart';
import 'package:jet_cad_2d_flutter/src/selection_overlay.dart';
import 'package:jet_cad_2d_flutter/src/selection_style.dart';

import '../support/draw_fixture.dart';
import '../support/grip_fixture.dart' show screenOf;
import '../support/selection_fixture.dart' show addEntity;
import '../support/spy_canvas.dart';

List<RecordedCall> frame(int extraEntities) {
  final s = drawScene();
  for (var i = 0; i < extraEntities; i++) {
    addEntity(s.document, s.document.rootHandle, EntityKind.line,
        [7000.0 + i * 0.3, 3200, 7000.0 + i * 0.3, 3260], []);
  }
  final rig = drawRig(s.document, PolylineTool(), objectSnap: false);
  for (final (x, y) in const [
    (7010.0, 3020.0),
    (7040.0, 3080.0),
    (7090.0, 3030.0),
    (7130.0, 3090.0),
    (7170.0, 3040.0),
  ]) {
    clickAt(rig, screenOf(rig.camera, x, y));
  }
  hoverAt(rig, screenOf(rig.camera, 7200, 3100));
  final painter = SelectionOverlayPainter(
    selection: rig.selection,
    tools: rig.tools,
    camera: rig.camera,
    outlines: rig.outlines,
    repaint: Listenable.merge([rig.selection, rig.tools, rig.camera]),
  );
  final spy = SpyCanvas();
  painter.paint(spy, const Size(800, 600));
  return spy.calls;
}

void main() {
  test('OV1 a five-vertex pending polyline is one drawPath in the preview '
      'colour (D12, M-05s)', () {
    final calls = frame(0);
    final preview = [
      for (final c in calls)
        if (c.color?.toARGB32() == kPreviewColor.toARGB32()) c,
    ];
    expect(preview.where((c) => c.name == 'drawPath'), hasLength(1));
    expect(preview.where((c) => c.name == 'drawLine'), isEmpty);
  });

  test('OV2 the overlay draws the same calls at 10 and at 1,000 entities', () {
    List<String> names(List<RecordedCall> calls) =>
        [for (final c in calls) c.name];
    expect(names(frame(1000)), names(frame(10)));
  });
}
```

- [ ] **Step 2: Run them and see them fail.**
  Run: `cd packages/jet_cad_2d_flutter && CI=true flutter test test/draw/polyline_tool_test.dart test/draw/rectangle_tool_test.dart test/draw/draw_overlay_test.dart`
  Expected: compile errors for the two missing tools.

- [ ] **Step 3: Implement.** `lib/src/draw/polyline_tool.dart`:

```dart
import 'dart:ui' show Canvas;

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../tool.dart';
import 'placement_tool.dart';

/// Spec 05 D6. Each click appends a vertex:
/// - the last vertex again, or Enter, finishes it open;
/// - the first vertex (from three vertices on) closes it, appending the
///   **stored** first point, so closedness holds under `==`.
///
/// Closed with Fill on, it commits a region, or the plain boundary when the
/// loop cannot fill.
class PolylineTool extends PlacementTool {
  PolylineTool({super.fill});

  @override
  String get name => 'Polyline';

  @override
  Vector2? selfSnap(Vector2 raw, double apertureWorld) {
    if (points.length >= 3 && raw.distanceTo(points.first) <= apertureWorld) {
      return points.first;
    }
    if (points.length >= 2 && raw.distanceTo(points.last) <= apertureWorld) {
      return points.last;
    }
    return null;
  }

  @override
  void accept(Vector2 point, ToolContext ctx) {
    if (acceptingSelf) {
      if (points.length >= 3 && identical(point, points.first)) {
        // Ruling 05-4: the accepted point *is* the stored first vertex.
        _commit(ctx, polylinePayload([...points, point]), closed: true);
      } else {
        _commit(ctx, polylinePayload(points), closed: false);
      }
      return;
    }
    if (points.isNotEmpty && isDegenerateSegment(points.last, point)) return;
    points.add(point);
  }

  @override
  void finish(ToolContext ctx) {
    if (points.length >= 2) _commit(ctx, polylinePayload(points), closed: false);
  }

  void _commit(ToolContext ctx, GeometryPayload payload,
      {required bool closed}) {
    commitShape(ctx, EntityKind.polyline, payload, fillable: closed);
    clearShape();
  }

  @override
  void paintRubberBand(Canvas canvas, Vector2 origin, double scale) {
    if (points.isEmpty) return;
    band.reset();
    band.moveTo(points.first.x - origin.x, points.first.y - origin.y);
    for (var i = 1; i < points.length; i++) {
      band.lineTo(points[i].x - origin.x, points[i].y - origin.y);
    }
    if (hoverVisible) {
      band.lineTo(hoverPoint.x - origin.x, hoverPoint.y - origin.y);
    }
    canvas.drawPath(band, bandPaint);
  }
}
```

  `lib/src/draw/rectangle_tool.dart`:

```dart
import 'dart:ui' show Canvas;

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../tool.dart';
import 'placement_tool.dart';

/// Spec 05 D7: two opposite corners, world-axis aligned, committed as a
/// closed polyline whose every coordinate is a copy of a corner's.
class RectangleTool extends PlacementTool {
  RectangleTool({super.fill});

  @override
  String get name => 'Rectangle';

  @override
  Vector2? get orthoBase => points.isEmpty ? null : points.first;

  @override
  void accept(Vector2 point, ToolContext ctx) {
    if (points.isEmpty) {
      points.add(point);
      return;
    }
    final c1 = points.first;
    if (isDegenerateRectangle(c1, point)) return;
    commitShape(ctx, EntityKind.polyline, rectanglePayload(c1, point),
        fillable: true);
    clearShape();
  }

  @override
  void paintRubberBand(Canvas canvas, Vector2 origin, double scale) {
    if (points.isEmpty || !hoverVisible) return;
    final c1 = points.first, c2 = hoverPoint;
    final x1 = c1.x - origin.x, y1 = c1.y - origin.y;
    final x2 = c2.x - origin.x, y2 = c2.y - origin.y;
    band
      ..reset()
      ..moveTo(x1, y1)
      ..lineTo(x2, y1)
      ..lineTo(x2, y2)
      ..lineTo(x1, y2)
      ..close();
    canvas.drawPath(band, bandPaint);
  }
}
```

  Add the two exports.

- [ ] **Step 4: Run the tests and see them pass.**
  Run: `cd packages/jet_cad_2d_flutter && CI=true flutter test test/draw/`
  Expected: `All tests passed!`. Paste the count.

- [ ] **Step 5: Gate and commit.** Run the `jet_cad_2d_flutter` line.

```bash
git add packages/jet_cad_2d_flutter/lib/src/draw/polyline_tool.dart packages/jet_cad_2d_flutter/lib/src/draw/rectangle_tool.dart packages/jet_cad_2d_flutter/lib/jet_cad_2d_flutter.dart packages/jet_cad_2d_flutter/test/draw/polyline_tool_test.dart packages/jet_cad_2d_flutter/test/draw/rectangle_tool_test.dart packages/jet_cad_2d_flutter/test/draw/draw_overlay_test.dart
git commit -m "$(cat <<'EOF'
feat(draw): polyline and rectangle tools, and Fill

A polyline closes on its own stored first vertex (which beats a nearer
entity endpoint) and finishes open on its last vertex or Enter. A
rectangle is a closed, world-axis polyline copied from its two corners.
With Fill on, a closed shape commits as one AddRegionCommand, or as its
plain boundary when the loop cannot fill. The overlay's structural test
pins the rubber band to one path per frame. Spec 05 D6, D7, D12, D13.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 5: `CircleTool` and `ArcTool`

Package: `packages/jet_cad_2d_flutter`.

**Files:**
- Create: `lib/src/draw/circle_tool.dart`, `lib/src/draw/arc_tool.dart`
- Modify: `lib/jet_cad_2d_flutter.dart` (two exports)
- Test: `test/draw/circle_tool_test.dart` (C1–C3),
  `test/draw/arc_tool_test.dart` (AR1–AR6)

**Interfaces:**
- Consumes:
  - Task 3: `PlacementTool` (`hovered`, `commitShape`).
  - Task 1: `circlePayload`, `arcPayload`, `isDegenerateRadius`.
  - Task 2: `SweepTracker`.
- Produces:
  - `class CircleTool extends PlacementTool { CircleTool({ValueListenable<bool>? fill}); }`
  - `class ArcTool extends PlacementTool { ArcTool(); }`

- [ ] **Step 1: Write the failing tests.** Create
  `test/draw/circle_tool_test.dart`:

```dart
import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/src/draw/circle_tool.dart';

import '../support/draw_fixture.dart';
import '../support/grip_fixture.dart' show screenOf, snapshot;

GeometryPayload payloadOf(DraftDocument doc, Handle h) =>
    doc.geometry.read(doc.entities.geomIndexAt(doc.entities.slotOf(h)!));

List<Handle> ofKind(DraftDocument doc, EntityKind kind) => [
      for (final slot in doc.entities.liveSlots)
        if (doc.entities.kindAt(slot) == kind) doc.entities.handleAt(slot),
    ];

void main() {
  for (final flipY in const [true, false]) {
    test('C1 flipY $flipY: centre and a point on the circle', () {
      final s = drawScene();
      final rig =
          drawRig(s.document, CircleTool(), flipY: flipY, objectSnap: false);
      final c = screenOf(rig.camera, 7050.5, 3080.25);
      final r = screenOf(rig.camera, 7091.75, 3102.5);
      clickAt(rig, c);
      clickAt(rig, r);
      final p =
          payloadOf(s.document, ofKind(s.document, EntityKind.circle).single);
      final wc = worldAt(rig, c), wr = worldAt(rig, r);
      expect(p.coords.toList(), [wc.x, wc.y]);
      expect(p.scalars.toList(), [wc.distanceTo(wr)]);
    });
  }

  test('C2 with Fill on, a circle commits as one region', () {
    final s = drawScene();
    final fill = ValueNotifier<bool>(true);
    addTearDown(fill.dispose);
    final rig =
        drawRig(s.document, CircleTool(fill: fill), objectSnap: false);
    clickAt(rig, screenOf(rig.camera, 7050, 3080));
    clickAt(rig, screenOf(rig.camera, 7090, 3100));
    final circle = ofKind(s.document, EntityKind.circle).single;
    expect(s.document.fills.fillsOf(circle), hasLength(1));
    expect(s.document.commands.undoDepth, 1);
  });

  test('C3 a zero radius is refused', () {
    final s = drawScene();
    final rig = drawRig(s.document, CircleTool(), objectSnap: false);
    final c = screenOf(rig.camera, 7050, 3080);
    clickAt(rig, c);
    final before = snapshot(s.document);
    clickAt(rig, c);
    expect(snapshot(s.document), before);
    expect(rig.tool.isPending, isTrue);
  });
}
```

  Create `test/draw/arc_tool_test.dart`. The camera is non-identity, so the
  helper places pointer positions by **world** coordinates on a circle
  around the centre:

```dart
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/src/draw/arc_tool.dart';

import '../support/draw_fixture.dart';
import '../support/grip_fixture.dart' show screenOf, snapshot;

GeometryPayload payloadOf(DraftDocument doc, Handle h) =>
    doc.geometry.read(doc.entities.geomIndexAt(doc.entities.slotOf(h)!));

Handle arcOf(DraftDocument doc) => [
      for (final slot in doc.entities.liveSlots)
        if (doc.entities.kindAt(slot) == EntityKind.arc)
          doc.entities.handleAt(slot),
    ].single;

const double cx = 7150.5, cy = 3120.25;

/// The pointer at [angle] on a circle of [r] around the centre.
void at(DrawRig rig, double angle, double r,
        {bool click = false, bool down = false}) =>
    down
        ? downAt(rig,
            screenOf(rig.camera, cx + r * math.cos(angle), cy + r * math.sin(angle)))
        : click
            ? clickAt(rig,
                screenOf(rig.camera, cx + r * math.cos(angle), cy + r * math.sin(angle)))
            : hoverAt(rig,
                screenOf(rig.camera, cx + r * math.cos(angle), cy + r * math.sin(angle)));

void main() {
  for (final flipY in const [true, false]) {
    test('AR1 flipY $flipY: an asymmetric CCW arc stores start then sweep '
        '(M-05e)', () {
      final s = drawScene();
      final rig =
          drawRig(s.document, ArcTool(), flipY: flipY, objectSnap: false);
      clickAt(rig, screenOf(rig.camera, cx, cy));
      at(rig, 0.3, 40, click: true);
      for (final a in const [0.8, 1.4, 2.0]) {
        at(rig, a, 40);
      }
      at(rig, 2.2, 55, click: true); // the end need not be on the circle
      final p = payloadOf(s.document, arcOf(s.document));
      final start = p.scalars[1], sweep = p.scalars[2];
      expect(start, closeTo(0.3, 1e-6));
      expect(sweep, closeTo(1.9, 1e-6));
      expect(p.scalars[0], closeTo(40, 1e-6));
      expect(rig.tool.points, isEmpty, reason: 'cleared after the commit');
    });
  }

  test('AR2 a clockwise path gives a negative sweep (M-05g)', () {
    final s = drawScene();
    final rig = drawRig(s.document, ArcTool(), objectSnap: false);
    clickAt(rig, screenOf(rig.camera, cx, cy));
    at(rig, 0.3, 40, click: true);
    for (final a in const [0.0, -0.5, -1.0]) {
      at(rig, a, 40);
    }
    at(rig, -1.2, 40, click: true);
    final p = payloadOf(s.document, arcOf(s.document));
    expect(p.scalars[2], closeTo(-1.5, 1e-6));
  });

  test('AR3 a path across the ±π seam keeps its direction (M-05f)', () {
    final s = drawScene();
    final rig = drawRig(s.document, ArcTool(), objectSnap: false);
    clickAt(rig, screenOf(rig.camera, cx, cy));
    at(rig, 2.9, 40, click: true);
    for (final a in const [3.05, -3.05, -2.9]) {
      at(rig, a, 40);
    }
    at(rig, -2.8, 40, click: true);
    final p = payloadOf(s.document, arcOf(s.document));
    expect(p.scalars[2], greaterThan(0));
    expect(p.scalars[2], closeTo(-2.8 + 2 * math.pi - 2.9, 1e-6));
  });

  test('AR4 an end press with no hover after the start is CCW (M-05z)', () {
    final s = drawScene();
    final rig = drawRig(s.document, ArcTool(), objectSnap: false);
    downAt(rig, screenOf(rig.camera, cx, cy));
    at(rig, 0.3, 40, down: true);
    at(rig, -1.0, 40, down: true);
    final p = payloadOf(s.document, arcOf(s.document));
    expect(p.scalars[2], greaterThan(0), reason: 'τ == 0 is CCW');
    expect(p.scalars[2], closeTo(2 * math.pi - 1.3, 1e-6));
  });

  test('AR5 Fill does not apply to an arc', () {
    final s = drawScene();
    final fill = ValueNotifier<bool>(true);
    addTearDown(fill.dispose);
    final rig = drawRig(s.document, ArcTool(), objectSnap: false);
    clickAt(rig, screenOf(rig.camera, cx, cy));
    at(rig, 0.3, 40, click: true);
    at(rig, 1.0, 40);
    at(rig, 1.2, 40, click: true);
    expect(s.document.fills.fillsOf(arcOf(s.document)), isEmpty);
    expect(fill.value, isTrue);
  });

  test('AR6 an end on the start ray is refused and the tool waits', () {
    final s = drawScene();
    final rig = drawRig(s.document, ArcTool(), objectSnap: false);
    clickAt(rig, screenOf(rig.camera, cx, cy));
    at(rig, 0.3, 40, click: true);
    final before = snapshot(s.document);
    downAt(rig,
        screenOf(rig.camera, cx + 70 * math.cos(0.3), cy + 70 * math.sin(0.3)));
    expect(snapshot(s.document), before);
    expect(rig.tool.isPending, isTrue);
  });
}
```

  The raw pointer goes through a screen round trip, so the angles hold only
  to about 1e-9 rad. The 1e-6 tolerances absorb that; the stored start is
  compared with `atan2` of the stored start point in AR1's intent.

  **AR6 depends on the round trip landing exactly on the start ray.** It
  may not. If AR6 misbehaves, place the end with a snap:
  - put a line on the ray in the scene;
  - turn object snap on, so the end lands exactly on the start's direction.

  In the test, replace `downAt` with a press at that line's endpoint, and
  assert the refusal.

- [ ] **Step 2: Run them and see them fail** (compile errors).

- [ ] **Step 3: Implement.** `lib/src/draw/circle_tool.dart`:

```dart
import 'dart:ui' show Canvas, Offset, Rect;

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../tool.dart';
import 'placement_tool.dart';

/// Spec 05 D7: the centre, then a point on the circle.
class CircleTool extends PlacementTool {
  CircleTool({super.fill});

  @override
  String get name => 'Circle';

  @override
  Vector2? get orthoBase => points.isEmpty ? null : points.first;

  @override
  void accept(Vector2 point, ToolContext ctx) {
    if (points.isEmpty) {
      points.add(point);
      return;
    }
    final c = points.first;
    final r = c.distanceTo(point);
    if (isDegenerateRadius(r)) return;
    commitShape(ctx, EntityKind.circle, circlePayload(c, r), fillable: true);
    clearShape();
  }

  @override
  void paintRubberBand(Canvas canvas, Vector2 origin, double scale) {
    if (points.isEmpty || !hoverVisible) return;
    final c = points.first, h = hoverPoint;
    final r = c.distanceTo(h);
    band
      ..reset()
      ..addOval(
          Rect.fromCircle(center: Offset(c.x - origin.x, c.y - origin.y), radius: r))
      ..moveTo(c.x - origin.x, c.y - origin.y)
      ..lineTo(h.x - origin.x, h.y - origin.y);
    canvas.drawPath(band, bandPaint);
  }
}
```

  `lib/src/draw/arc_tool.dart`:

```dart
import 'dart:math' as math;
import 'dart:ui' show Canvas, Offset, Rect;

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../tool.dart';
import 'placement_tool.dart';

/// Spec 05 D8: centre, start, end. The start sets the radius and the start
/// angle; the end sets only the end angle. The sweep follows the angle the
/// pointer travelled around the centre ([SweepTracker]). Fill does not
/// apply.
class ArcTool extends PlacementTool {
  ArcTool();

  final SweepTracker _tracker = SweepTracker();
  double _r = 0;

  @override
  String get name => 'Arc';

  @override
  Vector2? get orthoBase => points.isEmpty ? null : points.first;

  double _angleOf(Vector2 p) =>
      math.atan2(p.y - points.first.y, p.x - points.first.x);

  @override
  void hovered(Vector2 raw) {
    if (points.length == 2) _tracker.track(_angleOf(raw));
  }

  @override
  void accept(Vector2 point, ToolContext ctx) {
    switch (points.length) {
      case 0:
        points.add(point);
      case 1:
        final r = points.first.distanceTo(point);
        if (isDegenerateRadius(r)) return;
        _r = r;
        _tracker.begin(_angleOf(point));
        points.add(point);
      default:
        final sweep = _tracker.sweepTo(_angleOf(point));
        if (sweep == 0) return;
        commitShape(ctx, EntityKind.arc,
            arcPayload(points.first, _r, _tracker.start, sweep));
        clearShape();
    }
  }

  @override
  void paintRubberBand(Canvas canvas, Vector2 origin, double scale) {
    if (points.isEmpty || !hoverVisible) return;
    final c = points.first;
    final co = Offset(c.x - origin.x, c.y - origin.y);
    final h = hoverPoint;
    band.reset();
    if (points.length == 1) {
      band
        ..moveTo(co.dx, co.dy)
        ..lineTo(h.x - origin.x, h.y - origin.y);
    } else {
      final sweep = _tracker.sweepTo(_angleOf(h));
      final start = _tracker.start;
      band
        ..addArc(Rect.fromCircle(center: co, radius: _r), start, sweep)
        ..moveTo(co.dx, co.dy)
        ..lineTo(co.dx + _r * math.cos(start), co.dy + _r * math.sin(start))
        ..moveTo(co.dx, co.dy)
        ..lineTo(co.dx + _r * math.cos(start + sweep),
            co.dy + _r * math.sin(start + sweep));
    }
    canvas.drawPath(band, bandPaint);
  }
}
```

  Add the two exports.

- [ ] **Step 4: Run the tests and see them pass.**
  Run: `cd packages/jet_cad_2d_flutter && CI=true flutter test test/draw/`

- [ ] **Step 5: Gate and commit.**

```bash
git add packages/jet_cad_2d_flutter/lib/src/draw/circle_tool.dart packages/jet_cad_2d_flutter/lib/src/draw/arc_tool.dart packages/jet_cad_2d_flutter/lib/jet_cad_2d_flutter.dart packages/jet_cad_2d_flutter/test/draw/circle_tool_test.dart packages/jet_cad_2d_flutter/test/draw/arc_tool_test.dart
git commit -m "$(cat <<'EOF'
feat(draw): circle and centre-start-end arc tools

The circle is a centre and a point on it, and fills with Fill on. The
arc's sweep follows the angle the pointer travelled around the centre:
seam-safe, counter-clockwise when nothing was travelled, and refused
when the end is on the start. The start and the sweep are stored in
that order. Spec 05 D7, D8.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 6: `TextTool`

Package: `packages/jet_cad_2d_flutter`.

**Files:**
- Create: `lib/src/draw/text_tool.dart`
- Modify: `lib/jet_cad_2d_flutter.dart` (one export)
- Test: `test/draw/text_tool_test.dart` (TX1–TX7)

**Interfaces:**
- Consumes: Task 3 (`PlacementTool`), Task 1 (`textPayload`,
  `textHeightMm`, `addDrafted`).
- Produces:

  ```dart
  final class TextPlacement { const TextPlacement(this.point, this.heightMm); final Vector2 point; final double heightMm; }
  class TextTool extends PlacementTool {
    TextTool();
    final TextEditingController controller;       // tool-owned (D9)
    ValueListenable<TextPlacement?> get pending;
    void commitText(String s, ToolContext ctx);
    void cancelText(ToolContext ctx);
  }
  ```

- [ ] **Step 1: Write the failing tests.** Create
  `test/draw/text_tool_test.dart`:

```dart
import 'dart:typed_data';

import 'package:flutter/services.dart'
    show LogicalKeyboardKey, PhysicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/src/draw/text_tool.dart';
import 'package:jet_cad_2d_flutter/src/select_tool.dart';

import '../support/draw_fixture.dart';
import '../support/grip_fixture.dart' show screenOf, snapshot;

Handle? textOf(DraftDocument doc) {
  for (final slot in doc.entities.liveSlots) {
    if (doc.entities.kindAt(slot) == EntityKind.text) {
      return doc.entities.handleAt(slot);
    }
  }
  return null;
}

void main() {
  for (final flipY in const [true, false]) {
    test('TX1 flipY $flipY: a click sets pending at the exact point, 2.5 '
        'paper mm at 1:20, and dispatches nothing (M-05j)', () {
      final s = drawScene();
      final tool = TextTool();
      addTearDown(tool.dispose);
      final rig = drawRig(s.document, tool, flipY: flipY, objectSnap: false);
      final before = snapshot(s.document);
      final at = screenOf(rig.camera, 7050.5, 3080.25);
      clickAt(rig, at);
      final placed = tool.pending.value!;
      expect(placed.point, worldAt(rig, at));
      expect(placed.heightMm, 50.0);
      expect(snapshot(s.document), before);
    });
  }

  test('TX2 commitText commits one text with the string and height', () {
    final s = drawScene();
    final tool = TextTool();
    addTearDown(tool.dispose);
    final rig = drawRig(s.document, tool, objectSnap: false);
    final at = screenOf(rig.camera, 7050.5, 3080.25);
    clickAt(rig, at);
    tool.commitText('Kitchen ', rig.context);
    final h = textOf(s.document)!;
    final slot = s.document.entities.slotOf(h)!;
    final r = s.document.entities.read(slot);
    final p =
        s.document.geometry.read(s.document.entities.geomIndexAt(slot));
    expect(r.text, 'Kitchen ', reason: 'stored exactly as typed');
    expect(r.textAttrs, 0);
    final w = worldAt(rig, at);
    expect(p.coords, Float64List.fromList([w.x, w.y]));
    expect(p.scalars, Float64List.fromList([50, 0, 1, 0]));
    expect(tool.pending.value, isNull);
    expect(s.document.commands.undoDepth, 1);
  });

  test('TX3 an empty string cancels, byte-identical', () {
    final s = drawScene();
    final tool = TextTool();
    addTearDown(tool.dispose);
    final rig = drawRig(s.document, tool, objectSnap: false);
    final before = snapshot(s.document);
    clickAt(rig, screenOf(rig.camera, 7050, 3080));
    tool.commitText('', rig.context);
    expect(snapshot(s.document), before);
    expect(tool.pending.value, isNull);
  });

  test('TX4 a canvas click while pending commits the controller text and '
      'starts nothing new (M-05y)', () {
    final s = drawScene();
    final tool = TextTool();
    addTearDown(tool.dispose);
    final rig = drawRig(s.document, tool, objectSnap: false);
    clickAt(rig, screenOf(rig.camera, 7050, 3080));
    tool.controller.text = 'Bath';
    clickAt(rig, screenOf(rig.camera, 7120, 3040));
    final h = textOf(s.document)!;
    expect(s.document.entities.read(s.document.entities.slotOf(h)!).text,
        'Bath');
    expect(tool.pending.value, isNull);
    expect(tool.controller.text, isEmpty);
  });

  test('TX5 Escape and a tool switch each cancel, byte-identical', () {
    final s = drawScene();
    final tool = TextTool();
    addTearDown(tool.dispose);
    final rig = drawRig(s.document, tool, objectSnap: false);
    final before = snapshot(s.document);
    clickAt(rig, screenOf(rig.camera, 7050, 3080));
    tool.controller.text = 'x';
    keyDown(rig, LogicalKeyboardKey.escape, PhysicalKeyboardKey.escape);
    expect(tool.pending.value, isNull);
    expect(snapshot(s.document), before);
    clickAt(rig, screenOf(rig.camera, 7050, 3080));
    tool.controller.text = 'y';
    rig.tools.activate(SelectTool());
    expect(tool.pending.value, isNull);
    expect(snapshot(s.document), before);
  });

  test('TX6 Enter with the canvas focused commits the controller text', () {
    final s = drawScene();
    final tool = TextTool();
    addTearDown(tool.dispose);
    final rig = drawRig(s.document, tool, objectSnap: false);
    clickAt(rig, screenOf(rig.camera, 7050, 3080));
    tool.controller.text = 'Hall';
    keyDown(rig, LogicalKeyboardKey.enter, PhysicalKeyboardKey.enter);
    expect(textOf(s.document), isNotNull);
  });

  test('TX7 a shift click takes no ortho', () {
    final s = drawScene();
    final tool = TextTool();
    addTearDown(tool.dispose);
    final rig = drawRig(s.document, tool, objectSnap: false);
    final at = screenOf(rig.camera, 7050.5, 3080.25);
    clickAt(rig, at, shift: true);
    expect(tool.pending.value!.point, worldAt(rig, at));
    expect(tool.orthoBase, isNull);
  });
}
```

  A `TextTool` owns a `TextEditingController`, so every test disposes it
  (`addTearDown(tool.dispose)`).

- [ ] **Step 2: Run it and see it fail** (compile error).

- [ ] **Step 3: Implement `lib/src/draw/text_tool.dart`.**

```dart
import 'dart:ui' show Canvas;

import 'package:flutter/foundation.dart' show ValueListenable, ValueNotifier;
import 'package:flutter/widgets.dart' show TextEditingController;
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../tool.dart';
import 'placement_tool.dart';

/// Where a pending text will go, and how tall (spec 05 D9).
final class TextPlacement {
  const TextPlacement(this.point, this.heightMm);
  final Vector2 point;
  final double heightMm;
}

/// Spec 05 D9. A click sets [pending]; the app's field edits [controller].
///
/// **The rule, stated once.** Enter, or a canvas click, commits a non-empty
/// string. Escape, a tool switch, or any other loss of focus cancels. The
/// tool owns the text, so a canvas click commits synchronously, before the
/// layer's focus request takes effect.
class TextTool extends PlacementTool {
  TextTool();

  final TextEditingController controller = TextEditingController();
  final ValueNotifier<TextPlacement?> _pending =
      ValueNotifier<TextPlacement?>(null);

  ValueListenable<TextPlacement?> get pending => _pending;

  @override
  String get name => 'Text';

  @override
  bool get isPending => _pending.value != null;

  @override
  Vector2? get orthoBase => null;

  @override
  void accept(Vector2 point, ToolContext ctx) {
    if (_pending.value != null) {
      commitText(controller.text, ctx);
      return;
    }
    controller.clear();
    _pending.value = TextPlacement(point, textHeightMm(ctx.page?.value));
  }

  @override
  void finish(ToolContext ctx) => commitText(controller.text, ctx);

  void commitText(String s, ToolContext ctx) {
    final placed = _pending.value;
    if (placed == null) return;
    if (s.isNotEmpty) {
      commit(
          ctx,
          () => addDrafted(ctx.document, EntityKind.text,
              textPayload(placed.point, placed.heightMm),
              text: s));
    }
    cancel(ctx);
  }

  void cancelText(ToolContext ctx) => cancel(ctx);

  @override
  void clearShape() {
    super.clearShape();
    _pending.value = null;
    controller.clear();
  }

  /// A small insertion cross at the pending point, 6 screen px per arm.
  @override
  void paintRubberBand(Canvas canvas, Vector2 origin, double scale) {
    final placed = _pending.value;
    if (placed == null) return;
    final x = placed.point.x - origin.x, y = placed.point.y - origin.y;
    final arm = 6 / scale;
    band
      ..reset()
      ..moveTo(x - arm, y)
      ..lineTo(x + arm, y)
      ..moveTo(x, y - arm)
      ..lineTo(x, y + arm);
    canvas.drawPath(band, bandPaint);
  }

  @override
  void dispose() {
    controller.dispose();
    _pending.dispose();
    super.dispose();
  }
}
```

  Add the export.

- [ ] **Step 4: Run the tests and see them pass.**
  Run: `cd packages/jet_cad_2d_flutter && CI=true flutter test test/draw/text_tool_test.dart`

- [ ] **Step 5: Gate and commit.**

```bash
git add packages/jet_cad_2d_flutter/lib/src/draw/text_tool.dart packages/jet_cad_2d_flutter/lib/jet_cad_2d_flutter.dart packages/jet_cad_2d_flutter/test/draw/text_tool_test.dart
git commit -m "$(cat <<'EOF'
feat(draw): the text tool owns its text and commits on a canvas click

A click sets a pending placement, 2.5 paper mm at the page scale, and
the tool's own TextEditingController holds the string. Enter or a
canvas click commits a non-empty string synchronously; Escape and a tool
switch cancel byte-identically. Spec 05 D9.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 7: The app: palette, shortcuts, the guard, the text field, `_activate`

Package: `apps/floor_planner`.

**Files:**
- Create: `lib/shortcut_guard.dart`, `lib/tool_palette.dart`,
  `lib/text_entry_overlay.dart`
- Modify: `lib/main.dart`, `lib/planner_view.dart`
- Test: `test/planner_draw_test.dart` (A1–A12)

**Interfaces:**
- Consumes: Tasks 3–6, all six tools and `TextTool.pending`,
  `controller`, `commitText` and `cancelText`. It also uses
  `ToolController`, `SelectTool` and `SelectionController.clear()`.
- Produces:
  - `const List<LogicalKeyboardKey> kShellLetterKeys` (V L P R C A T F);
  - `class ShellShortcutGuard extends StatelessWidget { const ShellShortcutGuard({super.key, required Widget child}); }`;
  - `class PaletteEntry` (`keyName`, `label`, `shortcut`, `logicalKey`,
    `tool`, `drawing`);
  - `class ToolPalette extends StatelessWidget` (`entries`, `tools`, `fill`,
    `geometryAllowed`, `onSelect`);
  - `const Size kTextEntrySize = Size(240, 32)`;
  - `class TextEntryOverlay extends StatefulWidget` (`tool`, `tools`,
    `camera`);
  - `PlannerView` gains `required TextTool textTool`.

- [ ] **Step 1: Write the failing tests.** Create
  `test/planner_draw_test.dart`:

```dart
import 'package:floor_planner/main.dart';
import 'package:floor_planner/planner_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

/// A 1:20 page anchored at (7000, 3000), grid snap off, and one line to
/// select. `DraftCanvas` needs a `FlutterTextMeasurer`.
({DraftDocument doc, Handle line}) drawDoc(FlutterTextMeasurer m) {
  final doc = DraftDocument.empty(measurer: m);
  PageComponent.register(doc.components);
  doc.commands.execute(SetComponentCommand<PageComponent>(
      doc.rootHandle,
      PageComponent(
          scaleDenominator: 20,
          originX: 7000,
          originY: 3000,
          snapToGrid: false)));
  final add = addDrafted(doc, EntityKind.line,
      linePayload(Vector2(7137.3, 3161.7), Vector2(7300.9, 3190.1)));
  doc.commands.execute(add);
  doc.commands.clearHistory();
  return (doc: doc, line: add.record.handle);
}

/// Pumps the shell, then sets a zoomed, rotated, **non-reflecting** camera:
/// the app camera in `planner_grips_test.dart` is a reflection, whose
/// `b == c` hides a transposition.
Future<PlannerView> pumpDraw(WidgetTester tester, DraftDocument doc) async {
  await tester.binding.setSurfaceSize(const Size(1440, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(MaterialApp(home: PlannerShell(document: doc)));
  await tester.pump();
  final view = tester.widget<PlannerView>(find.byType(PlannerView));
  final size = tester.getSize(find.byType(InteractionLayer));
  final linear =
      Transform2.rotation(0.35).multiply(Transform2.scale(2.0, 2.0));
  final mid = linear.transformPoint(Vector2(7150, 3110));
  view.camera.value = ViewportTransform(
      worldToScreenMatrix: Transform2.translation(
              size.width / 2 - mid.x, size.height / 2 - mid.y)
          .multiply(linear));
  await tester.pump();
  return view;
}

Offset globalOf(WidgetTester tester, PlannerView view, double x, double y) {
  final s = view.camera.value.worldToScreen(Vector2(x, y));
  return tester.getTopLeft(find.byType(InteractionLayer)) + Offset(s.x, s.y);
}

String status(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const Key('status-text'))).data!;

Future<bool> press(WidgetTester tester, LogicalKeyboardKey key) async {
  final handled = await tester.sendKeyEvent(key);
  await tester.pump();
  return handled;
}

String bytes(PlannerView view) =>
    DraftDocumentCodec.encodeToString(view.document);

List<Handle> ofKind(DraftDocument doc, EntityKind kind) => [
      for (final slot in doc.entities.liveSlots)
        if (doc.entities.kindAt(slot) == kind) doc.entities.handleAt(slot),
    ];

void main() {
  testWidgets('A1 each palette entry activates its tool', (tester) async {
    await pumpDraw(tester, drawDoc(FlutterTextMeasurer()).doc);
    for (final (key, name) in const [
      ('tool-line', 'Line'),
      ('tool-polyline', 'Polyline'),
      ('tool-rectangle', 'Rectangle'),
      ('tool-circle', 'Circle'),
      ('tool-arc', 'Arc'),
      ('tool-text', 'Text'),
      ('tool-select', 'Select'),
    ]) {
      await tester.tap(find.byKey(Key(key)));
      await tester.pump();
      expect(status(tester), name, reason: key);
    }
  });

  testWidgets('A2 each shortcut activates its tool, and F toggles Fill',
      (tester) async {
    await pumpDraw(tester, drawDoc(FlutterTextMeasurer()).doc);
    for (final (key, name) in const [
      (LogicalKeyboardKey.keyL, 'Line'),
      (LogicalKeyboardKey.keyP, 'Polyline'),
      (LogicalKeyboardKey.keyR, 'Rectangle'),
      (LogicalKeyboardKey.keyC, 'Circle'),
      (LogicalKeyboardKey.keyA, 'Arc'),
      (LogicalKeyboardKey.keyT, 'Text'),
      (LogicalKeyboardKey.keyV, 'Select'),
    ]) {
      await press(tester, key);
      expect(status(tester), name);
    }
    bool fill() => tester
        .widget<CheckboxListTile>(find.byKey(const Key('tool-fill')))
        .value!;
    expect(fill(), isFalse);
    await press(tester, LogicalKeyboardKey.keyF);
    expect(fill(), isTrue);
    await tester.tap(find.byKey(const Key('tool-fill')));
    await tester.pump();
    expect(fill(), isFalse);
  });

  testWidgets('A3 activating a drawing tool clears the selection',
      (tester) async {
    final d = drawDoc(FlutterTextMeasurer());
    final view = await pumpDraw(tester, d.doc);
    view.selection.replace([SelectionKey.root(d.line)]);
    await tester.pump();
    expect(view.selection.isEmpty, isFalse);
    await press(tester, LogicalKeyboardKey.keyL);
    expect(view.selection.isEmpty, isTrue);
  });

  testWidgets('A4 an idle Escape returns to Select (M-05m)', (tester) async {
    await pumpDraw(tester, drawDoc(FlutterTextMeasurer()).doc);
    await press(tester, LogicalKeyboardKey.keyL);
    await press(tester, LogicalKeyboardKey.escape);
    expect(status(tester), 'Select');
  });

  testWidgets('A5 text end to end: T, click, type, Enter; then focus is back '
      'on the canvas', (tester) async {
    final view = await pumpDraw(tester, drawDoc(FlutterTextMeasurer()).doc);
    await press(tester, LogicalKeyboardKey.keyT);
    await tester.tapAt(globalOf(tester, view, 7100.5, 3050.25));
    await tester.pump();
    expect(find.byKey(const Key('text-entry')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('text-entry')), 'Kitchen');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    final text = ofKind(view.document, EntityKind.text).single;
    final slot = view.document.entities.slotOf(text)!;
    expect(view.document.entities.read(slot).text, 'Kitchen');
    expect(
        view.document.geometry
            .read(view.document.entities.geomIndexAt(slot))
            .scalars[0],
        50.0);
    expect(find.byKey(const Key('text-entry')), findsNothing);
    await press(tester, LogicalKeyboardKey.keyL);
    expect(status(tester), 'Line', reason: 'Ruling 05-7: focus came back');
  });

  testWidgets('A6 text: Escape and a palette click cancel byte-identically; a '
      'canvas click commits', (tester) async {
    final view = await pumpDraw(tester, drawDoc(FlutterTextMeasurer()).doc);
    final before = bytes(view);
    await press(tester, LogicalKeyboardKey.keyT);
    await tester.tapAt(globalOf(tester, view, 7100, 3050));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('text-entry')), 'x');
    await press(tester, LogicalKeyboardKey.escape);
    expect(bytes(view), before);
    expect(find.byKey(const Key('text-entry')), findsNothing);

    await tester.tapAt(globalOf(tester, view, 7100, 3050));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('text-entry')), 'y');
    await tester.tap(find.byKey(const Key('tool-select')));
    await tester.pump();
    expect(bytes(view), before);

    await press(tester, LogicalKeyboardKey.keyT);
    await tester.tapAt(globalOf(tester, view, 7100, 3050));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('text-entry')), 'Hall');
    await tester.tapAt(globalOf(tester, view, 7180, 3020));
    await tester.pump();
    expect(ofKind(view.document, EntityKind.text), hasLength(1));
  });

  testWidgets('A7 the field sits at the camera\'s point and survives a pan '
      'with its state (M-05n, M-05u)', (tester) async {
    final view = await pumpDraw(tester, drawDoc(FlutterTextMeasurer()).doc);
    await press(tester, LogicalKeyboardKey.keyT);
    await tester.tapAt(globalOf(tester, view, 7100.5, 3050.25));
    await tester.pump();
    final field = find.byKey(const Key('text-entry'));
    final placed = view.tools.active as TextTool;
    final at = placed.pending.value!.point;
    Offset corner() =>
        tester.getBottomLeft(find.byKey(const Key('text-entry-box')));
    final want = globalOf(tester, view, at.x, at.y);
    expect((corner() - want).distance, lessThan(0.5));
    await tester.enterText(field, 'abc');
    final state = tester.state<EditableTextState>(find.byType(EditableText));
    view.camera.value = ViewportTransform(
        worldToScreenMatrix: Transform2.translation(40, -25)
            .multiply(view.camera.value.worldToScreenMatrix));
    await tester.pump();
    expect((corner() - globalOf(tester, view, at.x, at.y)).distance,
        lessThan(0.5));
    expect(identical(tester.state<EditableTextState>(find.byType(EditableText)),
        state), isTrue, reason: 'Ruling 05-10: never rebuilt by the camera');
    expect(state.widget.focusNode.hasFocus, isTrue);
    expect(placed.controller.text, 'abc');
  });

  testWidgets('A8 shell letters typed into the field are not consumed and do '
      'not switch tools (M-05v)', (tester) async {
    final view = await pumpDraw(tester, drawDoc(FlutterTextMeasurer()).doc);
    await press(tester, LogicalKeyboardKey.keyT);
    await tester.tapAt(globalOf(tester, view, 7100, 3050));
    await tester.pump();
    for (final key in const [
      LogicalKeyboardKey.keyL,
      LogicalKeyboardKey.keyA,
      LogicalKeyboardKey.keyT,
      LogicalKeyboardKey.keyF,
      LogicalKeyboardKey.keyV,
    ]) {
      expect(await press(tester, key), isFalse,
          reason: '$key reaches the platform as text (Ruling 05-9)');
      expect(status(tester), 'Text');
    }
  });

  testWidgets('A9 letters and cmd+Z in the page panel\'s scale field neither '
      'switch tools nor undo the document (Review Focus 1)', (tester) async {
    final view = await pumpDraw(tester, drawDoc(FlutterTextMeasurer()).doc);
    await press(tester, LogicalKeyboardKey.keyR);
    await tester.tapAt(globalOf(tester, view, 7010, 3020));
    await tester.tapAt(globalOf(tester, view, 7090, 3070));
    await tester.pump();
    expect(view.document.commands.undoDepth, 1);
    await tester.tap(find.byKey(const Key('page-scale')));
    await tester.pump();
    expect(await press(tester, LogicalKeyboardKey.keyL), isFalse);
    expect(status(tester), 'Rectangle');
    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pump();
    expect(view.document.commands.undoDepth, 1, reason: 'not undone');
  });

  testWidgets('A10 a tool shortcut mid-polyline cancels it byte-identically '
      '(Review Focus 2)', (tester) async {
    final view = await pumpDraw(tester, drawDoc(FlutterTextMeasurer()).doc);
    final before = bytes(view);
    await press(tester, LogicalKeyboardKey.keyP);
    await tester.tapAt(globalOf(tester, view, 7010, 3020));
    await tester.tapAt(globalOf(tester, view, 7060, 3090));
    await tester.pump();
    await press(tester, LogicalKeyboardKey.keyL);
    expect(status(tester), 'Line');
    expect(bytes(view), before);
  });

  testWidgets('A11 cmd+Z after a commit, with the tool armed and idle, removes '
      'exactly that shape (Review Focus 5)', (tester) async {
    final view = await pumpDraw(tester, drawDoc(FlutterTextMeasurer()).doc);
    final before = bytes(view);
    await press(tester, LogicalKeyboardKey.keyR);
    await tester.tapAt(globalOf(tester, view, 7010, 3020));
    await tester.tapAt(globalOf(tester, view, 7090, 3070));
    await tester.pump();
    expect(ofKind(view.document, EntityKind.polyline), hasLength(1));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pump();
    expect(bytes(view), before);
    expect(status(tester), 'Rectangle', reason: 'still armed');
  });

  testWidgets('A12 under runtime permissions the drawing tools are disabled',
      (tester) async {
    final d = drawDoc(FlutterTextMeasurer());
    d.doc.commands.permissions = DraftPermissions.runtime;
    await pumpDraw(tester, d.doc);
    expect(tester.widget<ListTile>(find.byKey(const Key('tool-line'))).enabled,
        isFalse);
    expect(tester.widget<ListTile>(find.byKey(const Key('tool-select'))).enabled,
        isTrue);
    await press(tester, LogicalKeyboardKey.keyL);
    expect(status(tester), 'Select');
  });
}
```

  A7 takes the field's corner from the keyed `SizedBox`
  (`text-entry-box`) that Task 7 Step 5 wraps it in.

- [ ] **Step 2: Run them and see them fail.**
  Run: `cd apps/floor_planner && CI=true flutter test test/planner_draw_test.dart`
  Expected: compile errors or missing keys (`tool-line` and so on).

- [ ] **Step 3: `lib/shortcut_guard.dart`.**

```dart
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter/widgets.dart';

/// The shell's single-letter tool shortcuts (spec 05 D5).
const List<LogicalKeyboardKey> kShellLetterKeys = [
  LogicalKeyboardKey.keyV,
  LogicalKeyboardKey.keyL,
  LogicalKeyboardKey.keyP,
  LogicalKeyboardKey.keyR,
  LogicalKeyboardKey.keyC,
  LogicalKeyboardKey.keyA,
  LogicalKeyboardKey.keyT,
  LogicalKeyboardKey.keyF,
];

/// Spec 05 D9 and Ruling 05-8.
///
/// **Why this exists.** A `Shortcuts` or `CallbackShortcuts` above a text
/// field takes the field's keystrokes ("Shortcuts prevent text input fields
/// from receiving their keystrokes as text input", Flutter's
/// `editable_text.dart`). The shell's tool letters and its cmd/ctrl+Z are
/// such shortcuts.
///
/// **What it does.** It maps each of them, **nearer** the field, to
/// `DoNothingAndStopPropagationTextIntent`. `EditableText` answers that
/// intent with `DoNothingAction(consumesKey: false)`, so the key stops here
/// and reaches the field as text.
///
/// **Elsewhere it is inert.** With focus anywhere other than a text field,
/// no action is found, and the key bubbles up to the shell as before.
class ShellShortcutGuard extends StatelessWidget {
  const ShellShortcutGuard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Shortcuts(
        shortcuts: <ShortcutActivator, Intent>{
          for (final key in kShellLetterKeys)
            SingleActivator(key): const DoNothingAndStopPropagationTextIntent(),
          const SingleActivator(LogicalKeyboardKey.keyZ, meta: true):
              const DoNothingAndStopPropagationTextIntent(),
          const SingleActivator(LogicalKeyboardKey.keyZ, control: true):
              const DoNothingAndStopPropagationTextIntent(),
        },
        child: child,
      );
}
```

- [ ] **Step 4: `lib/tool_palette.dart`.**

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

/// One palette row and its shortcut (spec 05 D5).
final class PaletteEntry {
  const PaletteEntry({
    required this.keyName,
    required this.label,
    required this.shortcut,
    required this.logicalKey,
    required this.tool,
    required this.drawing,
  });

  final String keyName;
  final String label;
  final String shortcut;
  final LogicalKeyboardKey logicalKey;
  final Tool tool;

  /// A drawing tool: disabled while geometry is denied.
  final bool drawing;
}

/// Spec 05 D5, D13: the tools and the Fill toggle, in the left panel.
///
/// **It never takes focus** (`ExcludeFocus`, Ruling 05-6), so the canvas
/// keeps it and the shell's shortcuts keep working after a click here.
class ToolPalette extends StatelessWidget {
  const ToolPalette({
    super.key,
    required this.entries,
    required this.tools,
    required this.fill,
    required this.geometryAllowed,
    required this.onSelect,
  });

  final List<PaletteEntry> entries;
  final ToolController tools;
  final ValueNotifier<bool> fill;
  final bool geometryAllowed;
  final void Function(Tool tool) onSelect;

  @override
  Widget build(BuildContext context) => ExcludeFocus(
        child: ListenableBuilder(
          listenable: Listenable.merge([tools, fill]),
          builder: (context, _) => ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              for (final e in entries)
                ListTile(
                  key: Key(e.keyName),
                  dense: true,
                  selected: identical(tools.active, e.tool),
                  enabled: !e.drawing || geometryAllowed,
                  title: Text(e.label),
                  trailing: Text(e.shortcut),
                  onTap: () => onSelect(e.tool),
                ),
              const Divider(),
              CheckboxListTile(
                key: const Key('tool-fill'),
                dense: true,
                title: const Text('Fill'),
                secondary: const Text('F'),
                value: fill.value,
                onChanged: geometryAllowed
                    ? (v) => fill.value = v ?? false
                    : null,
              ),
            ],
          ),
        ),
      );
}
```

- [ ] **Step 5: `lib/text_entry_overlay.dart`.**

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

import 'shortcut_guard.dart';

/// Ruling 05-11: the field's size. Its bottom-left sits at the insertion
/// point's screen position.
const Size kTextEntrySize = Size(240, 32);

/// Spec 05 D9: the inline field for [TextTool].
///
/// **Where it sits.** Outside the `InteractionLayer`, so a click on it is
/// not a canvas click.
///
/// **Keys.** The guard lets the shell's letters through as text, and
/// Escape cancels.
///
/// **Rebuilds.** The field is a stable child of the camera builder, so a pan
/// or zoom moves it and never rebuilds it (Ruling 05-10).
///
/// **Commit and cancel.** Enter commits. Any other loss of focus cancels
/// if the placement is still pending. A canvas click has already committed
/// synchronously in the tool, so its blur finds nothing to cancel.
class TextEntryOverlay extends StatefulWidget {
  const TextEntryOverlay({
    super.key,
    required this.tool,
    required this.tools,
    required this.camera,
  });

  final TextTool tool;
  final ToolController tools;
  final CameraController camera;

  @override
  State<TextEntryOverlay> createState() => _TextEntryOverlayState();
}

class _TextEntryOverlayState extends State<TextEntryOverlay> {
  final FocusNode _focus = FocusNode(debugLabel: 'text-entry');

  @override
  void initState() {
    super.initState();
    widget.tool.pending.addListener(_onPending);
    _focus.addListener(_onFocus);
  }

  /// Ruling 05-7: hand focus back to the canvas, the scope's previous child,
  /// as soon as the placement ends.
  void _onPending() {
    if (widget.tool.pending.value == null && _focus.hasFocus) {
      _focus.unfocus(disposition: UnfocusDisposition.previouslyFocusedChild);
    }
  }

  void _onFocus() {
    if (!_focus.hasFocus && widget.tool.pending.value != null) {
      widget.tool.cancelText(widget.tools.context);
    }
  }

  void _submit(String s) => widget.tool.commitText(s, widget.tools.context);

  void _cancel() => widget.tool.cancelText(widget.tools.context);

  @override
  void dispose() {
    widget.tool.pending.removeListener(_onPending);
    _focus.removeListener(_onFocus);
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<TextPlacement?>(
        valueListenable: widget.tool.pending,
        builder: (context, placed, _) {
          if (placed == null) return const SizedBox.shrink();
          final field = SizedBox.fromSize(
            key: const Key('text-entry-box'),
            size: kTextEntrySize,
            child: ShellShortcutGuard(
              child: CallbackShortcuts(
                bindings: <ShortcutActivator, VoidCallback>{
                  const SingleActivator(LogicalKeyboardKey.escape): _cancel,
                },
                child: TextField(
                  key: const Key('text-entry'),
                  controller: widget.tool.controller,
                  focusNode: _focus,
                  autofocus: true,
                  maxLines: 1,
                  onSubmitted: _submit,
                  decoration: const InputDecoration(
                      isDense: true, border: OutlineInputBorder()),
                ),
              ),
            ),
          );
          return Stack(
            children: [
              ListenableBuilder(
                listenable: widget.camera,
                builder: (context, child) {
                  final s = widget.camera.value.worldToScreen(placed.point);
                  return Positioned(
                    left: s.x,
                    top: s.y - kTextEntrySize.height,
                    child: child!,
                  );
                },
                child: field,
              ),
            ],
          );
        },
      );
}
```

- [ ] **Step 6: `lib/planner_view.dart`.** Add `required this.textTool`
  and `final TextTool textTool;`. In `build`, the `LayoutBuilder` builder
  now returns:

```dart
            return Stack(
              children: [
                Positioned.fill(
                  child: CameraGestureDetector(
                    // … exactly as before …
                  ),
                ),
                // Spec 05 D9: outside the InteractionLayer, so a click on
                // the field is not a canvas click.
                Positioned.fill(
                  child: TextEntryOverlay(
                    tool: widget.textTool,
                    tools: widget.tools,
                    camera: widget.camera,
                  ),
                ),
              ],
            );
```

  Import `text_entry_overlay.dart`. An empty `Stack` region does not
  absorb hits (`RenderStack` has no `hitTestSelf`), so pointer events still
  reach the canvas beneath.

- [ ] **Step 7: `lib/main.dart`.** In `_PlannerShellState`:

```dart
  // Spec 05 D5, D13: the shell owns the tools and the Fill toggle.
  final ValueNotifier<bool> _fill = ValueNotifier<bool>(false);
  final SelectTool _select = SelectTool();
  final LineTool _line = LineTool();
  late final PolylineTool _polyline = PolylineTool(fill: _fill);
  late final RectangleTool _rectangle = RectangleTool(fill: _fill);
  late final CircleTool _circle = CircleTool(fill: _fill);
  final ArcTool _arc = ArcTool();
  final TextTool _text = TextTool();

  late final List<PaletteEntry> _entries = [
    PaletteEntry(keyName: 'tool-select', label: 'Select', shortcut: 'V', logicalKey: LogicalKeyboardKey.keyV, tool: _select, drawing: false),
    PaletteEntry(keyName: 'tool-line', label: 'Line', shortcut: 'L', logicalKey: LogicalKeyboardKey.keyL, tool: _line, drawing: true),
    PaletteEntry(keyName: 'tool-polyline', label: 'Polyline', shortcut: 'P', logicalKey: LogicalKeyboardKey.keyP, tool: _polyline, drawing: true),
    PaletteEntry(keyName: 'tool-rectangle', label: 'Rectangle', shortcut: 'R', logicalKey: LogicalKeyboardKey.keyR, tool: _rectangle, drawing: true),
    PaletteEntry(keyName: 'tool-circle', label: 'Circle', shortcut: 'C', logicalKey: LogicalKeyboardKey.keyC, tool: _circle, drawing: true),
    PaletteEntry(keyName: 'tool-arc', label: 'Arc', shortcut: 'A', logicalKey: LogicalKeyboardKey.keyA, tool: _arc, drawing: true),
    PaletteEntry(keyName: 'tool-text', label: 'Text', shortcut: 'T', logicalKey: LogicalKeyboardKey.keyT, tool: _text, drawing: true),
  ];

  bool get _geometryAllowed =>
      _document.commands.permissions.allows(Capability.geometry);

  /// Spec 05 D5: the one way a tool becomes active. A drawing tool clears
  /// the selection first, because the overlay paints the selection's
  /// outlines and grips under any active tool. It is refused while geometry
  /// is denied. Focus never leaves the canvas (Ruling 05-6).
  void _activate(Tool tool) {
    final drawing = !identical(tool, _select);
    if (drawing && !_geometryAllowed) return;
    if (drawing) _selection.clear();
    _tools.activate(tool);
  }

  /// An idle drawing tool leaves Escape unhandled; it arrives here.
  void _escape() {
    if (!identical(_tools.active, _select)) _activate(_select);
  }
```

  Then:
  - Change `_tools` to `ToolController(initial: _select, context: _context)`.
  - In `bindings`, add the tool shortcuts, then Fill, then Escape:

    ```dart
    for (final e in _entries) SingleActivator(e.logicalKey, includeRepeats: false): () => _activate(e.tool),
    const SingleActivator(LogicalKeyboardKey.keyF, includeRepeats: false): () { if (_geometryAllowed) _fill.value = !_fill.value; },
    const SingleActivator(LogicalKeyboardKey.escape): _escape,
    ```
  - Fill the `chrome-left` container:

    ```dart
    child: ToolPalette(entries: _entries, tools: _tools, fill: _fill, geometryAllowed: _geometryAllowed, onSelect: _activate)
    ```
  - Wrap the right panel in the guard:

    ```dart
    child: ShellShortcutGuard(child: PagePanel(document: _document, page: _page))
    ```
  - Pass `textTool: _text` to `PlannerView`.
  - In `dispose`, after `_tools.dispose()`, dispose all seven tools and
    `_fill`.

  Import `shortcut_guard.dart` and `tool_palette.dart`. Update the class's
  doc comment: "since 05, the tools and the Fill toggle."

- [ ] **Step 8: Run the tests and see them pass.**
  Run: `cd apps/floor_planner && CI=true flutter test`
  Expected: all 26 existing tests and A1–A12 pass, for **38**.

  **If A8's `sendKeyEvent` returns `true` with the guard in place**, then
  `flutter_test`'s dispatch treats `skipRemainingHandlers` differently than
  Ruling 05-9 assumed:
  - Stop. Paste the output. Record it in the ledger.
  - Assert instead that `status` stays `Text` and that the field's
    controller text is unchanged.
  - Keep M-05v's kill on the status assertion.

- [ ] **Step 9: Gate and commit.** Run the `floor_planner` line, including
  both builds.

```bash
git add apps/floor_planner/lib/shortcut_guard.dart apps/floor_planner/lib/tool_palette.dart apps/floor_planner/lib/text_entry_overlay.dart apps/floor_planner/lib/main.dart apps/floor_planner/lib/planner_view.dart apps/floor_planner/test/planner_draw_test.dart
git commit -m "$(cat <<'EOF'
feat(app): the tool palette, shortcuts and the inline text field

A palette in the left panel and the V, L, P, R, C, A, T and F shortcuts
reach the seven tools and Fill through one _activate, which clears the
selection. An idle Escape returns to Select. The text field sits outside
the InteractionLayer, follows the camera without rebuilding, and is
guarded, like the page panel, so the shell's letters and cmd+Z reach a
text field as text. Spec 05 D5, D9, D13; Rulings 05-6 to 05-11.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 8: The sample plan's furniture becomes filled regions

Package: `apps/floor_planner`.

**Files:**
- Modify: `lib/startup_plan.dart`
- Test: `test/startup_plan_test.dart` (SP1, SP2 added)

**Interfaces:**
- Consumes: Task 1 (`addDraftedRegion`, `rectanglePayload`,
  `polylinePayload`, `circlePayload`).
- Produces: `_Pen.rectRegion`, `_Pen.polygonRegion`, `_Pen.circleRegion`
  (private).

- [ ] **Step 1: Write the failing tests.** Append to
  `test/startup_plan_test.dart`'s `main()`. Add the `jet_cad_2d` import if
  the file lacks it.

```dart
  test('SP1 the furniture is eight filled regions with the furniture '
      'outline', () {
    final doc = startupPlan(FlutterTextMeasurer());
    final boundaries = <Handle>[];
    for (final slot in doc.entities.liveSlots) {
      final h = doc.entities.handleAt(slot);
      if (doc.fills.fillsOf(h).isNotEmpty) boundaries.add(h);
    }
    expect(boundaries, hasLength(8));
    for (final b in boundaries) {
      final r = doc.entities.read(doc.entities.slotOf(b)!);
      expect(r.color, const TrueColor(0x8A6D3B));
      expect(r.lineweight, 25);
      final fill = doc.fills.fillsOf(b).single;
      expect(doc.entities.read(doc.entities.slotOf(fill)!).color,
          kDraftFillColor);
    }
    expect(doc.entities.liveCount, 509, reason: 'Ruling 05-12: 523 − 14');
  });

  test('SP2 every fill draws over every floor-finish line (M-05r)', () {
    final doc = startupPlan(FlutterTextMeasurer());
    var maxFinish = 0, minFill = 1 << 62;
    for (final slot in doc.entities.liveSlots) {
      final r = doc.entities.read(slot);
      if (r.kind == EntityKind.fill && r.handle.value < minFill) {
        minFill = r.handle.value;
      }
      if (r.kind == EntityKind.line &&
          r.color == const TrueColor(0xBBBBBB) &&
          r.handle.value > maxFinish) {
        maxFinish = r.handle.value;
      }
    }
    expect(maxFinish, greaterThan(0));
    expect(minFill, greaterThan(maxFinish));
  });
```

  (`_finishColor` is `TrueColor(0xBBBBBB)`, at `startup_plan.dart:37`.
  Verify that before relying on it.)

- [ ] **Step 2: Run them and see them fail.**
  Run: `cd apps/floor_planner && CI=true flutter test test/startup_plan_test.dart`
  Expected: SP1 finds 0 regions, and SP2's `minFill` is `1 << 62`.

- [ ] **Step 3: Implement.** In `_Pen`, add:

```dart
  /// Spec 05 D14: a furniture piece as one region, the fill under its
  /// boundary, the boundary keeping today's colour and weight.
  void _region(EntityKind kind, GeometryPayload payload) =>
      doc.commands.execute(addDraftedRegion(doc, kind, payload,
          boundaryColor: _furnitureColor, boundaryLineweight: 25)!);

  void rectRegion(double ax, double ay, double bx, double by) => _region(
      EntityKind.polyline, rectanglePayload(Vector2(ax, ay), Vector2(bx, by)));

  void polygonRegion(List<double> xy) => _region(
      EntityKind.polyline,
      polylinePayload([
        for (var i = 0; i < xy.length; i += 2) Vector2(xy[i], xy[i + 1]),
      ], closed: true));

  void circleRegion(double cx, double cy, double r) =>
      _region(EntityKind.circle, circlePayload(Vector2(cx, cy), r));
```

  Import `package:vector_math/vector_math_64.dart show Vector2`, which is
  already an app dependency (`pubspec.yaml:21`).

  Then **delete** the furniture block (`// --- Furniture: rectangles, one
  L. ---` through the basin). Re-add it **after the parquet call**, before
  `PageComponent.register`:

```dart
  // --- Furniture: filled regions (spec 05 D14), after the finishes so
  // their fills draw over the tile and parquet lines. ---
  p.rectRegion(x0 + 400, y0 + 6600, x0 + 2200, y0 + 8600); // bed
  p.rectRegion(x0 + 2900, y0 + 6800, x0 + 4500, y0 + 8600); // bed
  p.rectRegion(x0 + 6000, y0 + 4200, x0 + 9000, y0 + 5100); // sofa
  p.rectRegion(x0 + 6400, y0 + 5600, x0 + 8600, y0 + 6800); // table
  // The kitchen counter: one L, so its fill has no seam.
  p.polygonRegion([
    x0 + 5400, y0 + 400, //
    x0 + 9100, y0 + 400,
    x0 + 9100, y0 + 1000,
    x0 + 6000, y0 + 1000,
    x0 + 6000, y0 + 3100,
    x0 + 5400, y0 + 3100,
  ]);
  p.rectRegion(x0 + 12200, y0 + 400, x0 + 13500, y0 + 2000); // bath
  p.circleRegion(x0 + 7600, y0 + 6200, 350); // lamp, after the table
  p.circleRegion(x0 + 10300, y0 + 1200, 220); // basin
```

  If `_Pen.rect` is now unused, keep it (the walls use it) or delete it;
  `analyze` decides.

- [ ] **Step 4: Run the tests and see them pass.** Run the whole app suite.
  `planner_shell_test`'s `>= 500` and `startup_plan_test`'s `[500, 1000]`
  still hold at 509.

- [ ] **Step 5: Gate and commit.** Run the `floor_planner` line.

```bash
git add apps/floor_planner/lib/startup_plan.dart apps/floor_planner/test/startup_plan_test.dart
git commit -m "$(cat <<'EOF'
feat(app): the sample plan's furniture as filled regions

The beds, the sofa, the table, the bath, the L-shaped counter, the lamp
and the basin are regions in the drafting fill colour with their old
outline, emitted after the floor finishes so the fills cover the tile
and parquet lines. 523 entities become 509. Spec 05 D14.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 9: Mutation testing — all twenty-six

**Files:**
- Create: `docs/superpowers/notes/plan-05-mutation-log.md`

**Interfaces:**
- Consumes: every test from Tasks 1–8. No code change survives this task.

For each mutant in the table, in order:
1. `cp` the file to
   `.superpowers/sdd/2026-09-23-drawing-tools/mutation-backups/<basename>.<id>`.
2. Apply the one edit by hand.
3. Run **only the named test file**, with `CI=true`.
4. Paste the failing test names and the summary line.
5. Restore with `cp` back from the backup.
6. Run `diff <backup> <file>` and paste its empty output.

**Never `git checkout --` a `.dart` file.**

**Log format** per mutant: the heading `### M-05x — <title>`, then `file:`,
`edit:`, `test:` and `result: KILLED -- <test names> [E]; <summary>`. A
survivor is `SURVIVED`, with the reason and what was done (a fixture change
plus a re-fire, or an equivalence argument). The spec permits no designed
survivor.

The paths below are relative to the repo root.

| ID | file | edit | test file |
|---|---|---|---|
| M-05a | `packages/jet_cad_2d_flutter/lib/src/draw/placement_tool.dart`, `onPointerDown` | `_resolve(ctx, e.world, e.shift)` → `_resolve(ctx, Vector2(e.screen.dx, e.screen.dy), e.shift)` | `test/draw/placement_tool_test.dart` (B1) |
| M-05b | `packages/jet_cad_2d/lib/src/document/drafting.dart`, `rectanglePayload` | drop the last pair `c1.x, c1.y` | `test/document/drafting_test.dart` (E5) |
| M-05c | `drafting.dart`, `textPayload` | `[heightMm, 0, 1, 0]` → `[heightMm * kCapHeightRatio, 0, 1, 0]` (import `text_metrics.dart`) | `drafting_test.dart` (E7) |
| M-05d | `drafting.dart`, `addDrafted` | `doc.handleSeed.next()` → `Handle(doc.entities.liveCount + ReservedHandles.firstFree)` | `drafting_test.dart` (E3) |
| M-05e | `packages/jet_cad_2d_flutter/lib/src/draw/arc_tool.dart`, `accept` | `arcPayload(points.first, _r, _tracker.start, sweep)` → `arcPayload(points.first, _r, _tracker.start + sweep, -sweep)` | `test/draw/arc_tool_test.dart` (AR1) |
| M-05f | `drafting.dart`, `SweepTracker.track` | `_travel += wrapAngle(angle - _previous);` → `_travel += angle - _previous;` | `test/document/sweep_tracker_test.dart` (S4) |
| M-05g | `drafting.dart`, `sweepTo` | `return _travel >= 0 ? delta : delta - _tau;` → `return delta;` | `sweep_tracker_test.dart` (S3) |
| M-05h | `packages/jet_cad_2d_flutter/lib/src/draw/placement_tool.dart`, `orthoBase` | `points.last` → `points.first` | `test/draw/polyline_tool_test.dart` (PL6) |
| M-05i | `placement_tool.dart`, `onPointerDown` | `accept(self ?? Vector2.copy(_hover.point), ctx);` → `accept(self != null ? Vector2.copy(e.world) : Vector2.copy(_hover.point), ctx);` | `polyline_tool_test.dart` (PL3) |
| M-05j | `drafting.dart`, `textHeightMm` | `page.scaleDenominator` → `50` | `drafting_test.dart` (E8) |
| M-05k | `line_tool.dart`, `accept` | `..add(point)` (after a commit) → `..add(ctx.camera.value.screenToWorld(ctx.camera.value.worldToScreen(point)))` | `test/draw/line_tool_test.dart` (L1) |
| M-05l | `placement_tool.dart`, `onKey` | Escape's `cancel(ctx);` → `finish(ctx); cancel(ctx);` | `polyline_tool_test.dart` (PL9) |
| M-05m | `placement_tool.dart`, `onKey` | `if (event is KeyUpEvent \|\| !isPending) return KeyEventResult.ignored;` → put `if (key == LogicalKeyboardKey.escape) return KeyEventResult.handled;` before it | `apps/floor_planner/test/planner_draw_test.dart` (A4), and `placement_tool_test.dart` (B4) |
| M-05n | `apps/floor_planner/lib/text_entry_overlay.dart`, the camera builder | `left: s.x, top: s.y - …` → `left: placed.point.x, top: placed.point.y - …` | `planner_draw_test.dart` (A7) |
| M-05o | `rectangle_tool.dart`, `accept` | `fillable: true` → `fillable: false` | `test/draw/rectangle_tool_test.dart` (R3) |
| M-05p | `placement_tool.dart`, `commitShape` | Ruling 05-15's two executes in place of `return region;` (return the second command; execute the first inline) | `rectangle_tool_test.dart` (R3), `polyline_tool_test.dart` (PL4) |
| M-05q | `drafting.dart`, `addDraftedRegion` | delete `if (boundaryKind == EntityKind.polyline && triangles.isEmpty) return null;` | `drafting_test.dart` (E9), `polyline_tool_test.dart` (PL5) |
| M-05r | `apps/floor_planner/lib/startup_plan.dart` | move the furniture block back before the finishes | `apps/floor_planner/test/startup_plan_test.dart` (SP2) |
| M-05s | `polyline_tool.dart`, `paintRubberBand` | one `canvas.drawLine` per segment (and to the hover) instead of `band` plus one `drawPath` | `test/draw/draw_overlay_test.dart` (OV1) |
| M-05t | `drafting.dart`, `draftRecord` | `textAttrs: 0` → `textAttrs: packTextAttrs(overrideWidthFactor: true, overrideOblique: true)` | `drafting_test.dart` (E1, E7) |
| M-05u | `text_entry_overlay.dart` | move `field` into the camera builder, with `key: ValueKey(widget.camera.value.worldToScreenMatrix.e)` on the `SizedBox` | `planner_draw_test.dart` (A7) |
| M-05v | `text_entry_overlay.dart` | remove the `ShellShortcutGuard` around the field | `planner_draw_test.dart` (A8) |
| M-05w | `placement_tool.dart`, `_resolve` | run `resolveDragPoint` first and consult `selfSnap` only when `_hover.objectKind == null && !_hover.grid` | `polyline_tool_test.dart` (PL8) |
| M-05x | `line_tool.dart`, `selfSnap` | drop the `_segments > 0 &&` clause | `line_tool_test.dart` (L3) |
| M-05y | `text_tool.dart`, `accept` | `commitText(controller.text, ctx);` → `cancelText(ctx);` | `test/draw/text_tool_test.dart` (TX4) |
| M-05z | `drafting.dart`, `sweepTo` | `_travel >= 0` → `_travel > 0` | `sweep_tracker_test.dart` (S5), `arc_tool_test.dart` (AR4) |

- [ ] **Step 1: Fire each mutant as above.** Append each result to the log
  as it lands. For M-05k, **paste the round trip's actual bits** (the
  first line's end next to the second line's start), so the log shows the
  kill is not luck (Ruling 05-5).
- [ ] **Step 2: Tally.** "26 fired: N killed, M survived". Any survivor
  gets a fixture change in the owning test and a re-fire, logged as
  `M-05x′`.
- [ ] **Step 3: Verify the tree.** `git status --short` lists only the log.
  `git diff --stat` shows no `.dart` change.
- [ ] **Step 4: Commit.**

```bash
git add docs/superpowers/notes/plan-05-mutation-log.md
git commit -m "$(cat <<'EOF'
docs: Plan 05 mutation log -- M-05a..z

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 10: The invariants, and the greps

**Files:**
- Modify: `docs/superpowers/notes/plan-05-mutation-log.md` (append the
  greps' output)

**Interfaces:**
- Consumes: the whole branch.

- [ ] **Step 1: Run each check and paste its output into the log.**

```sh
# Invariant 4: 02's API is unchanged.
git diff main -- packages/jet_cad_2d_flutter/lib/src/tool.dart packages/jet_cad_2d_flutter/lib/src/interaction_layer.dart | wc -l   # 0
# The allocation invariants are unedited.
git diff main -- packages/jet_cad_2d/test/invariants packages/jet_cad_2d_flutter/test/invariants | wc -l   # 0
# The engine stays pure Dart.
grep -rn "package:flutter\|dart:ui" packages/jet_cad_2d/lib | wc -l   # 0
# D12: each tool reuses one Path; no Path() is constructed on the paint path.
grep -rn "Path()" packages/jet_cad_2d_flutter/lib/src/draw   # exactly one hit, in placement_tool.dart's field
# Ruling 05-3: every handle a tool allocates goes through the builders.
grep -rn "handleSeed" packages/jet_cad_2d_flutter/lib/src/draw apps/floor_planner/lib   # no hits
# Transform2 is never compared with == in the new tests.
grep -rn "Transform2.*==" packages/jet_cad_2d_flutter/test/draw apps/floor_planner/test/planner_draw_test.dart   # no hits
```

- [ ] **Step 2: Run all four gate lines.** Paste each summary line. Name
  the five golden failures.
- [ ] **Step 3: Commit.**

```bash
git add docs/superpowers/notes/plan-05-mutation-log.md
git commit -m "$(cat <<'EOF'
docs: Plan 05 invariants and greps

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 11: Gates, the results note, the spec amendments, STATUS, the owed look

**Files:**
- Create: `docs/superpowers/notes/2026-09-23-plan-05-results.md`
- Modify: the spec, `roadmap/05-drawing-tools.md`, `roadmap/00-README.md`,
  `STATUS.md`

**Interfaces:**
- Consumes: every earlier task, the mutation log, and the differential's
  printed line.

- [ ] **Step 1: The four gate lines, pasted with exit codes.**
  - **Expected counts** (the branch point plus what this plan lands):
    - engine: 894 + 10 (E) + 7 (S) = **911**;
    - render layer: 854 plus every `test/draw/` case (count them from the
      run; the per-flipY loops double some), with 1 skip and the five
      goldens;
    - harness: **82**;
    - app: 26 + 12 (A) + 2 (SP) = **40**;
    - both builds `✓ Built`.
  - **Report what ran, not these sums.** Explain any difference.
- [ ] **Step 2: The results note.** Include:
  - one row per exit criterion 1–14, each with its witness;
  - the differential's printed line;
  - the mutation tally;
  - every Ruling 05-1…05-15, one line each;
  - the Review Focus items and their tests;
  - the debt:
    - the text field's font jump;
    - no fill preview;
    - the app camera in `planner_grips_test.dart` still a reflection;
    - the sample-plan count margin (Ruling 05-12);
  - **criterion 14 marked OWED: not looked at; the human looks after this
    branch is presented.** It is itemised per platform: macOS, Chrome, and
    Firefox from `build/web`. Each platform's list:
    1. Every tool once. The palette highlights the active tool, and the
       top bar names it.
    2. A line chain snapped onto a wall end, and ended by clicking its
       start.
    3. A polyline closed by clicking its first vertex, with Fill on and
       then off.
    4. A rectangle and a circle with Fill on: grey fills under their
       outlines.
    5. An arc drawn clockwise, then counter-clockwise, then across the
       left-hand horizontal.
    6. Text: T, click, type "Living room" (it contains `l`, `v`, `r`),
       Enter. Then Escape on a second one, and a canvas click on a third.
    7. Escape mid-shape and then undo: one step per shape.
    8. The filled furniture over the tiles and the parquet.
    9. In Chrome and Firefox, whether the browser also takes any single
       letter, or F.
    10. Whether the text field's position and font jump on commit are
        acceptable.
- [ ] **Step 3: The spec amendments.** Add "Amended at execution (Plan 05)"
  paragraphs, each citing its ruling:
  - D4: Ruling 05-2;
  - D5: Rulings 05-6 and 05-8;
  - D8 and the differential: Ruling 05-1;
  - D9: Rulings 05-8 and 05-11;
  - Testing: Ruling 05-9, M-05v's observable.
- [ ] **Step 4: STATUS and the roadmap.** Follow Plan 03's shape:
  - a "Plan 05 — drawing tools (executed on `plan-05/drawing-tools`, not
    merged)" section;
  - the header;
  - the Resume paragraph;
  - the branch map;
  - `roadmap/05-drawing-tools.md`'s status line;
  - the row in `roadmap/00-README.md`.
- [ ] **Step 5: Commit, then archive the ledger.**

```bash
git add docs/superpowers/notes/2026-09-23-plan-05-results.md docs/superpowers/specs/2026-09-23-drawing-tools-design.md roadmap/05-drawing-tools.md roadmap/00-README.md STATUS.md
git commit -m "$(cat <<'EOF'
docs: Plan 05 results, spec amendments, STATUS and roadmap

Exit gate 13 of 14; criterion 14 (the human's look on macOS, Chrome and
Firefox) is OWED. Spec amended at execution for Rulings 05-1, 05-2,
05-6, 05-8, 05-9 and 05-11.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
mkdir -p docs/superpowers/ledgers/2026-09-23-drawing-tools
cp -R .superpowers/sdd/2026-09-23-drawing-tools/. docs/superpowers/ledgers/2026-09-23-drawing-tools/
git add docs/superpowers/ledgers/2026-09-23-drawing-tools
git commit -m "$(cat <<'EOF'
docs: archive the Plan 05 ledger

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

The ledger archive is the branch's **last commit before the merge**. Hand
over to `superpowers:finishing-a-development-branch`. **The merge is the
human's decision.**

---

## Exit gate

The spec's fourteen criteria and where each is witnessed:

| # | criterion | witness |
|---|---|---|
| 1 | each tool, documented geometry, both cameras | B1, L1, PL1, PL3, R1, C1, AR1, TX1–TX2 |
| 2 | one shape, one undo step; redo, same handles | E4, L1, L4, PL1, PL4, R3, C2, TX2, A11 |
| 3 | a snapped start is exact | B2, L1 |
| 4 | Escape, tool switch, dispose: byte-identical | B4, B9, PL9, TX5, A6, A10 |
| 5 | a rectangle round-trips closed, plain and filled | E5, R5 |
| 6 | text at the requested cap height | E7 |
| 7 | the palette and shortcuts reach all seven tools and Fill; an idle Escape returns | A1, A2, A4 |
| 8 | the arc's direction follows the pointer; the differential | S2–S6, AR1–AR4, the differential |
| 9 | Fill: regions, the fallback, the kinds that ignore it | E9, PL4, PL5, R3, R4, C2, AR5 |
| 10 | the sample plan's furniture is filled over the finishes | SP1, SP2 |
| 11 | every mutant killed | `plan-05-mutation-log.md` |
| 12 | the allocation invariants unedited; the overlay's structural test | Task 10 greps, OV1, OV2 |
| 13 | the four gate lines, the five goldens only, both builds | Task 11 Step 1 |
| 14 | the human's look | OWED (Task 11) |

## Self-review

**Spec coverage.** Each part of the spec, and where the plan covers it:

| spec item | covered by |
|---|---|
| D1 | Tasks 3–6: 02's API is untouched, checked by the Task 10 grep |
| D2 | Task 1: `draftRecord` and `addDrafted` |
| D3 | Task 3 |
| D4 | Task 3 `_resolve`; PL8 |
| D5 | Task 7 |
| D6 | Tasks 3 and 4 |
| D7 | Tasks 4 and 5 |
| D8 | Tasks 2 and 5 |
| D9 | Tasks 1, 6 and 7 |
| D10 | B4, B6, B8, B9, TX5 |
| D11 | Tasks 1 and 2 |
| D12 | Task 3's `band`; OV1 and OV2 |
| D13 | Tasks 1, 3 and 4, and the Task 7 palette |
| D14 | Task 8 |
| Invariants 1–6 | B1, L1, PL3 (1); E4, R3 (2); B4, PL9, A6 (3); Task 10 grep (4); OV1, OV2 and the allocation tests (5); E9, PL4, R3 (6) |

**Fixture rules.** No test uses scale 1.0, a 0° or 90° camera, the origin,
or the default 1:50. The render and app cameras run unflipped, which
guards against a `b`/`c` transposition, as `fix/grip-camera-bc-swap`
taught.

**Placeholder scan.** There is no TBD and no "similar to Task N".

Three steps name a fallback to take if a measured behaviour differs from
this plan's reading of Flutter:
- A8's `sendKeyEvent` result;
- AR6's round trip;
- M-05k's bits.

Each says what to paste and what to do instead.

**Type and name consistency.** These names are used identically across
Tasks 1–8:
- `PlacementTool`, `commit`, `commitShape`, `acceptingSelf`, `band`,
  `bandPaint`, `hoverPoint`, `hoverVisible`, `isPending`, `clearShape`,
  `hovered`;
- `TextPlacement`, `pending`, `controller`, `commitText`, `cancelText`;
- `addDrafted`, `addDraftedRegion`, `kDraftFillColor`, `textHeightMm`,
  `SweepTracker`, `wrapAngle`;
- `ShellShortcutGuard`, `ToolPalette`, `PaletteEntry`, `TextEntryOverlay`,
  `kTextEntrySize`.

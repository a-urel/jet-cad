# Alignment Guides Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Alignment guides (edges, centres, equal spacing) that show and snap while movable objects are dragged or placed, in design mode and in service mode.

**Architecture:**
- A pure-Dart solver and a per-document reference cache live in `jet_cad_2d_plan/lib/src/guides/`.
- Design moves reach them through a new generic `MoveAdjuster` seam on `jet_cad_2d_flutter`'s `SelectTool`.
- Placement (`PlanSymbolTool`) and service (`ServiceTool`) call them directly.
- One `PlanGuideSettings` on the controller gates all three. Each bar gets one plain toggle; the look comes from `PaperPalette.guide` and three `PlanTheme` fields.

**Tech Stack:** Dart 3.6+, Flutter ≥ 3.44, `vector_math`, `flutter_test`, the VM allocation meter (`vm_service`) for the invariant.

**Spec:** [docs/superpowers/specs/2026-10-23-alignment-guides-design.md](../specs/2026-10-23-alignment-guides-design.md) (revision 3, approved). Read it with this plan; the spec is the authority on behaviour.

**Plan review:** reviewed by the Copilot CLI at the human's request; findings P-1 to P-14 are folded in below and recorded in `docs/superpowers/notes/2026-10-23-alignment-guides-spec-review.md`.

**Ledger:** `.superpowers/sdd/2026-10-23-alignment-guides/` (git-ignored) while in flight; archived to `docs/superpowers/ledgers/` before the merge.

## Global Constraints

- The frame path allocates nothing per entity in steady state, and O(1) per flush. `query_allocation_test`, `paint_allocation_test` and `canvas_paint_allocation_test` stay green.
- Guides add **zero** allocations per event over today's baseline (spec, Constraints).
- Geometric decisions use `Tolerance` (`ε = Tolerance.standard.linear`); the aperture is in screen pixels divided by `camera.scale`.
- Constants: `kGuideAperturePixels = 6.0` (mouse), `kGuideTouchAperturePixels = 10.0` (touch), `kGuideOverhangPixels = 8.0`, `kGuideTickPixels = 4.0`, `kGuideCapacity = 16` (lines, and marks, each).
- Default colours: light `Color(0xFFE0218A)`, dark `Color(0xFFFF5CB0)`. They live only in `PaperPalette`; no colour literal is added to plan `lib`, which `theme_colours_test` enforces.
- `guideWidth` defaults to `1.0`.
- File format, schema, draw order, undo shape (one command per drag) and host events are unchanged, apart from the snapped positions.
- No version bump in any pubspec. Each touched package's CHANGELOG gets an `## Unreleased` entry (plan: append to the existing one; `jet_cad_2d_flutter`: new section).
  - Release note for the human: `jet_cad_2d_flutter` must be published before the plan library's floor (`jet_cad_2d_flutter: ^0.7.3`) is raised.
- Never commit `analysis_options.yaml`: run `git status --short` before every commit.
- Commit trailer: `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>` (implementers: their own model name).
- Code, comments and commits in English. Comments match the surrounding density: spec references such as `(spec G-…, C-8)`.
- **Testing bar.** A test lands only if a named mutation turns it red; each task's report names its mutations and shows them red, then green. Fixtures are rotated (30°, 90°), mirrored, off the origin, and at a camera scale other than 1.
- **Gates per task:**

```sh
cd packages/jet_cad_2d_flutter && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
cd packages/jet_cad_2d_plan && flutter test --enable-vmservice && flutter analyze && dart format --output=none --set-exit-if-changed .
```

  The `jet_cad_2d_flutter` gate applies only when a task touches that package. The final task also runs `packages/jet_cad_2d` (`dart test`, `dart analyze`, `dart format`), `packages/jet_cad_2d_gpu`, `packages/jet_cad_2d_integration`, `apps/restaurant_demo`, `apps/architecture_demo` (`flutter test && flutter analyze`) and `cd tool/ci && dart test`. Known failures: `tool/ci/standing_failures.txt`.

## Review Focus

1. **Two references at the same position** (duplicate tables stacked, or a copy-paste in place). The tie order must give one stable winner, and the guide must be drawn once per reference, never thrown. Task 3 pins it.
2. **Zoomed far out** (scale 0.05): the world aperture is large and many references capture. The buffers must cap at 16 without overflow or allocation. Task 3 pins it.
3. **A service group whose members include a hidden one**: the moving box is the union of the visible members only; an all-hidden group draws no guide and moves as today. Task 8 pins it.
4. **Undo right after a guided move** must restore the exact pre-drag transforms (`==`, not within tolerance). Redo must give the guided ones. Tasks 6 and 8 pin it.
5. **A plan whose only other objects are seats, walls or rooms** must draw no guide, and the move must equal today's. Task 6 pins it.


---

### Task 2: The `MoveAdjuster` seam on `SelectTool`

**Files:**
- Modify: `packages/jet_cad_2d_flutter/lib/src/select_tool.dart`
- Modify: `packages/jet_cad_2d_flutter/lib/jet_cad_2d_flutter.dart` (export `MoveAdjuster`)
- Modify: `packages/jet_cad_2d_flutter/CHANGELOG.md`
- Test: `packages/jet_cad_2d_flutter/test/select_tool_move_adjuster_test.dart`

**Interfaces:**
- Produces, beside `MoveResolver`:

```dart
/// What a body move's target may be replaced with, after the snap chain and
/// before the move (alignment guides). An application seam: generic.
abstract interface class MoveAdjuster {
  /// A move drag of [moving] (the drag's own set) begins.
  void begin(ToolContext ctx, Set<Handle> moving);

  /// [target] holds the chain's point; write the point to move to. [raw] is
  /// the pointer, [base] the drag's base, [orthoBase] non-null while Shift
  /// pins an axis (the minor one, `resolveDragPoint`'s rule),
  /// [objectSnapped] whether the chain's point came from object snap.
  void adjust(ToolContext ctx,
      {required Vector2 raw,
      required Vector2 base,
      required Vector2? orthoBase,
      required bool objectSnapped,
      required bool touch,
      required bool alt,
      required Vector2 target});

  /// The attachment replaced this event's move: draw nothing for it.
  void suppress();

  /// Screen space, under the tool's overlay, above the selection preview.
  void paint(Canvas canvas, ViewportTransform camera, Size viewport,
      PaperPalette paper);

  /// The drag ended: committed, cancelled or abandoned.
  void end();

  /// Notifies when the adjustment would change for the same input (its
  /// setting toggled): the tool re-targets from the last screen point.
  Listenable get changes;
}
```

- `SelectTool({this.moveResolver, this.gates, this.moveAdjuster})`, with `final MoveAdjuster? moveAdjuster`.

**Wiring in `SelectTool`:**
- `_enter`: for `DragKind.move`, call `moveAdjuster?.begin(ctx, drag.handles)` **before** `_follow`, and add `_onCamera` as a listener of `moveAdjuster.changes` (P-6).
- `_follow`: also store `_lastTouch = e.isTouch` and `_lastAlt = e.alt`. `_retarget` keeps its signature and reads these two fields (P-12).
- `drag.handles` may hold leaf handles; the adjuster decides eligibility.
- `_retarget`, for a non-rotate drag:
  1. `_resolve`;
  2. if an adjuster is set and the drag is a move, copy `_dragPoint.point` into a reused `_adjusted` field, call `adjust(...)` with `orthoBase: shift ? drag.base : null`, then `drag.moveTo(_adjusted)`; else `drag.moveTo(_dragPoint.point)` as today;
  3. the attachment runs as today; when `_attached` becomes true, call `moveAdjuster?.suppress()`.
- `onKey`: Alt-left or Alt-right down or up (not a repeat) during a drag sets `_lastAlt` and calls `_onCamera()`, exactly as Shift does today.
- `_endDrag`: for a move drag only, remove the `changes` listener and call `moveAdjuster?.end()` before clearing `_drag` (P-12: `_endDrag` also ends rotate and reshape drags).
- `paintOverlay`, while dragging: call `moveAdjuster?.paint(...)` after `_paintGuide`. Exception: when `_attached`, do not call it.
- `_onCamera` passes the stored kind and Alt through `_retarget`; it gains no new parameters on the public surface.
- With `moveAdjuster == null`, behaviour and allocations equal today's. The existing `select_tool` suites must stay green untouched.

- [ ] **Step 1: Write failing tests**, with a recording fake adjuster that offsets `target` by `(+3, −2)`, a document with two rectangles off the origin, and a camera at scale 2 rotated 30°:
  - `begin` is called once with the drag's handles at the move's start, `end` once on release and once on Escape-cancel, and never for a rotate or reshape drag;
  - after release, the committed transform's translation equals the chain delta plus `(3, −2)`;
  - `adjust` receives `orthoBase != null` only while Shift is held; `objectSnapped` is true when the pointer sits on an endpoint;
  - `touch` is true for a touch pointer, `alt` true with Alt held;
  - pressing Alt with no pointer move calls `adjust` again with `alt: true` (one more call, the same `raw`);
  - a camera pan mid-drag calls `adjust` with the stored `touch` and `alt`;
  - with a `MoveResolver` that attaches, `suppress` is called and `paint` is not;
  - the fake's `changes` notifying mid-drag calls `adjust` once more; after release it does nothing;
  - with `moveAdjuster` null, the committed transform equals today's for the same pointer path (a differential test against a second `SelectTool()` run).
- [ ] **Step 2:** The tests fail to compile (no `moveAdjuster`).
- [ ] **Step 3:** Implement the wiring above.
- [ ] **Step 4:** Pass. Named mutations: `moveTo(_dragPoint.point)` kept instead of `_adjusted`; `orthoBase` always passed; `suppress` not called; Alt key not re-targeting; `end` skipped on cancel.
- [ ] **Step 5:** Package gate. CHANGELOG line: "`SelectTool.moveAdjuster` (`MoveAdjuster`): a generic seam to replace a body move's target after the snap chain." Commit `feat(flutter): SelectTool.moveAdjuster seam`.


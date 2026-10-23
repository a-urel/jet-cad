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

### Task 6: Design move: `PlanMoveGuides` and the painter

**Files:**
- Create: `packages/jet_cad_2d_plan/lib/src/guides/guide_painter.dart`
- Create: `packages/jet_cad_2d_plan/lib/src/guides/plan_move_guides.dart`
- Modify: `packages/jet_cad_2d_plan/lib/src/tools/generic_tools.dart` (`buildGenericTools({..., MoveAdjuster? moveAdjuster})`)
- Modify: `packages/jet_cad_2d_plan/lib/src/controller/session.dart` (owns a `GuideReferenceCache` and a `PlanMoveGuides`, passes it to the generic tools)
- Modify: `packages/jet_cad_2d_plan/lib/src/controller/plan_controller.dart` (hands the settings and stroke to the session)
- Test: `packages/jet_cad_2d_plan/test/guides/design_move_guides_test.dart`

**Interfaces:**
- Consumes: `MoveAdjuster` (Task 2), `solveGuides`/`GuideSolution` (Task 3), `GuideReferenceCache` (Task 4), `PlanGuideSettings` and `guideStrokePixels` (Task 5), `PaperPalette.guideColor` (Task 1).
- Produces:

```dart
/// Paints [s]'s lines and marks in screen space: lines extended
/// kGuideOverhangPixels past each end, marks with kGuideTickPixels ticks.
/// Reuses one Paint and one Float32List (drawRawPoints, PointMode.lines);
/// allocates nothing per call (P-13).
final class GuidePainter {
  void paint(Canvas canvas, Transform2 worldToScreen, GuideSolution s,
      {required Color color, required double strokePixels});
}
const double kGuideOverhangPixels = 8.0;
const double kGuideTickPixels = 4.0;

final class PlanMoveGuides implements MoveAdjuster {
  PlanMoveGuides({required GuideReferenceCache references,
      required PlanGuideSettings settings,
      required double Function() strokePixels,
      required bool Function(Handle root) movable});
}
```

**`movable`**: true when the root node is an `InstanceNode`. `begin` sets the drag eligible only when every moved handle is movable. It also computes the moving box once through `unionOf`, into a reused `Float64List(4)`.

**`adjust`** (spec *The delta* and *Priority*). It returns, leaving `target` as the chain's, when any of these holds:
- the drag is not eligible;
- `!settings.on`;
- `alt`;
- the union failed.

Otherwise:
1. `dRaw = raw − base`, and `fallback = target − raw`, per axis.
2. The free axes are both axes, unless `orthoBase` is set; then the minor axis is pinned, by `resolveDragPoint`'s rule, `|raw.x − base.x| ≥ |raw.y − base.y|` pins y.
3. Solve with the moving box shifted by `dRaw` and the aperture `(touch ? 10 : 6) / camera.scale`.
4. Write only the captured axes: `target.x = raw.x + dx` when `capturedX`, likewise y; an uncaptured axis keeps the chain's value bit for bit (P-7).

`objectSnapped` does not stop the solve (C-8).

**`suppress`** clears the solution. **`paint`** draws the solution through `GuidePainter`, with `paper.guideColor` and `strokePixels()`. **`end`** clears it.

`changes` is the `PlanGuideSettings` itself. When guides turn off mid-drag, `SelectTool` re-targets through it (Task 2), `adjust` returns at once, and the solution is cleared, so the repaint shows none.

- [ ] **Step 1: Write failing tests** through a real `PlanController` with the restaurant kit, driving pointer events through the canvas (follow the existing design-move tests' rig). Camera at scale 1.5, rotated 0°; tables rotated 30° and 90°, one mirrored, all around `(6000, 4000)`.
  - Dragging table B to within 4 px of table A's left edge snaps B's box min-x to A's exactly. The committed translation equals the preview's. One undo step restores B's original transform exactly (`==`), and redo restores the guided one.
  - The same drag 7 px away: no capture; the result equals the drag with `controller.alignmentGuides.toggle()` applied (differential).
  - **Grid mixing.** With `page.snapToGrid` on (step 100) and a capture on x only, the x result is A's edge and the y result is on the grid. The jump when the capture switches on is at most half a step plus the aperture.
  - **Off-grid press.** Press at a point whose snapped base differs from the raw press; the guided edge still lands exactly.
  - **Wall endpoint.** A wall endpoint 3 px from the pointer and a guide inside the aperture on x: x takes the guide. Three successive pointer moves 1 px apart all give the same guided x (no blinking).
  - **Shift.** A mostly horizontal Shift drag: y equals the base's y exactly, and no y-line exists.
  - **Attachment.** A wall-attaching symbol over a wall: the attachment's transform is committed and `paint` draws no guide line. Inspect the painter's last solution: `lineCount == 0`.
  - **Mixed selection.** A selection of a table plus a wall line: the move equals today's (differential against guides off).
  - **Alt.** With Alt held, the move equals guides-off.
  - **Seats only.** A plan where the only other objects are seats and walls: the move equals guides-off (Review Focus 5).
  - **Setting off.** `alignmentGuidesAllowed = false`: no capture.
  - **Toggled mid-drag.** `toggle()` while a capture is shown, with no pointer move: the preview falls back to the chain's point at once (P-6).
  - **Non-node handles.** A drag whose handles include a leaf entity is not eligible.
- [ ] **Step 2:** Fail.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Pass. Named mutations:
  - `objectSnapped` short-circuiting the solve;
  - the pin rule inverted;
  - `fallback` taken from `raw` instead of `target`;
  - `begin` ignoring `movable`;
  - `paint` ignoring `suppress`.
- [ ] **Step 5:** Plan gate. Commit `feat(plan): alignment guides in design moves`.


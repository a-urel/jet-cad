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

### Task 8: Service: `ServiceTool`

**Files:**
- Modify: `packages/jet_cad_2d_plan/lib/src/service/service_tool.dart`
- Modify: `packages/jet_cad_2d_plan/lib/src/service/service_session.dart` (owns a `GuideReferenceCache` over the service copy; passes it, the settings and the stroke to `ServiceTool`)
- Test: `packages/jet_cad_2d_plan/test/guides/service_guides_test.dart`

**Interfaces:**
- Consumes: Tasks 3–6.
- `ServiceTool` gains optional `GuideReferenceCache? guides`, `PlanGuideSettings? guideSettings` and `double Function()? guideStroke`.

**Behaviour:**
- `_startDrag`, after `_moving` is set: `unionOf(_moving)` into a reused box; false means the drag is not eligible. The cache already excludes seats and hidden units, so a group of hidden members gives false (P-11). Build the `moving` `Set<Handle>` once here, and store `_dragCtx = ctx`.
- `_drag`, **only for `_Gesture.dragging`** (panning is untouched):
  - `dRaw = e.world − _pressWorld`;
  - when eligible, `guideSettings.on` and not Alt: solve with fallback `(0, 0)`, both axes free, and the aperture by `e.isTouch`;
  - `_dx/_dy` = `dRaw` plus the offset on captured axes only.
- Store `_lastTouch` and `_lastAlt`. The screen point is the existing `_lastScreen`; no `_lastWorld` (P-11).
- **Camera** (P-11): only while an eligible drag lives and guides are on, a camera listener recomputes the world point from `_lastScreen` (`camera.value.screenToWorld`), re-solves and notifies. With guides off or the drag not eligible, nothing listens, so `_dx/_dy` stay today's. Add the listener on entering an eligible drag; remove it through `_dragCtx` in `_reset` (release, cancel, a failed `_startDrag`) and in `dispose`, which does not call `_reset`.
- **Settings** (P-6): the same lifetime listens to `guideSettings`. A toggle re-solves from `_lastScreen` (off gives `dRaw`) and notifies.
- **Alt key**: `onKey`, Alt down or up while dragging re-solves from `_lastScreen`.
- `paintOverlay` paints the solution while `_gesture == _Gesture.dragging`, beside the band branch.

- [ ] **Step 1: Write failing tests**, using `test/support/service_rig.dart` (`hallController`): tables rotated 30° off the origin, camera scale 1.5.
  - Dragging table 2 to within 5 px of table 1's centre line snaps its centre exactly. `onUnitsMoved`'s `PlanUnitDetail.center` for table 2 equals the snapped centre. One undo restores it exactly (`==`).
  - A camera zoom mid-drag with no pointer move re-solves at the new scale: a capture at 5 px under scale 1.5 is lost when the scale halves (5 px becomes 10 px at the old pointer). Release then commits the unsnapped delta.
  - A second finger cancels the drag. The camera listener is removed: a later camera change does not throw and does not notify the tool.
  - **Group.** A group of two tables, one on a hidden layer: the moving box is the visible member's. A group of only hidden members draws no guide and moves as today (Review Focus 3).
  - **Equal spacing.** Three tables in a row, the middle dragged: `between` captures, and the solution has two marks.
  - Alt with no pointer move gives guides-off.
  - Seats of the dragged table stay put, and are not references.
- [ ] **Step 2:** Fail.
- [ ] **Step 3:** Implement.
  - with guides off, a camera zoom mid-drag leaves `_dx/_dy` exactly as today (no listener) (P-11);
  - a pan (floor drag) never solves.
- [ ] **Step 4:** Pass. Named mutations: the camera listener not removed in `_reset`; the listener added with guides off; `_dx` computed without the offset on release; the `moving` set not excluded (a table snapping to itself, `dx == 0` always).
- [ ] **Step 5:** Plan gate. Commit `feat(plan): alignment guides in service drags`.


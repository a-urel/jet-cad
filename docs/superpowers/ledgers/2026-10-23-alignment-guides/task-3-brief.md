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

### Task 3: The solver

**Files:**
- Create: `packages/jet_cad_2d_plan/lib/src/guides/guide_solver.dart` (pure Dart: `dart:typed_data`, `package:jet_cad_2d` only)
- Test: `packages/jet_cad_2d_plan/test/guides/guide_solver_test.dart`

**Interfaces:**
- Produces:

```dart
const double kGuideAperturePixels = 6.0;
const double kGuideTouchAperturePixels = 10.0;
const int kGuideCapacity = 16;

/// The references: box i is boxes[4i..4i+3] = minX, minY, maxX, maxY.
final class GuideReferences {
  GuideReferences(this.boxes, this.handles);
  final Float64List boxes;
  final List<Handle> handles;
  int get length => handles.length;
}

enum GuideKind { edge, centre, between, continuing }

/// Caller-owned; reset by every solve.
final class GuideSolution {
  /// The shift to apply to the moving box: per axis the captured offset, or
  /// the caller's fallback.
  double dx = 0, dy = 0;
  bool capturedX = false, capturedY = false;
  GuideKind? kindX, kindY;
  /// The winning candidate's reference (the lower of a pair); null when
  /// the axis did not capture (P-8).
  Handle? refX, refY;
  /// Lines: [axis (0: x, a vertical line; 1: y), coord, from, to] each.
  final Float64List lines = Float64List(4 * kGuideCapacity);
  int lineCount = 0;
  /// Gap marks: [axis, gapStart, gapEnd, at] each.
  final Float64List marks = Float64List(4 * kGuideCapacity);
  int markCount = 0;
  void reset();
}

void solveGuides(GuideReferences refs,
    {required double minX,
    required double minY,
    required double maxX,
    required double maxY,
    required double aperture,
    required bool freeX,
    required bool freeY,
    required double fallbackDx,
    required double fallbackDy,
    required Set<Handle> moving,
    required GuideSolution out});
```

- The box `(minX..maxY)` is the moving box at the raw delta.
- A reference in `moving` is skipped.
- An axis with `free… == false` (Shift's pin, or the caller's choice) never captures, and takes its fallback.

**Algorithm:** exactly the spec's *Candidates on one axis* steps 1–6, including:
- the total tie order;
- the simultaneous recheck of spacing captures against the provisional box. The provisional box takes, per axis, the captured offset or the fallback;
- gaps `≤ ε` never counting.

Lines and marks are written for the **final** box:
- a line spans, on its perpendicular axis, from the moving box to the farthest aligned reference (world units). Overhang is the painter's job;
- a mark's `at` is the middle of the perpendicular overlap of the two boxes beside the gap.

Lines on the same axis at the same coordinate (within `ε`) merge into one, with the union of their extents, so stacked duplicates use one slot (P-8). Past `kGuideCapacity`, further lines and marks are dropped silently. The solve allocates nothing; scratch state is fields of `GuideSolution` or locals of primitive type.

- [ ] **Step 1: Write failing tests**
  - Every coordinate below is written relative to an offset `(5000, −3200)` that the test adds to each box (x to x, y to y), so the fixtures sit off the origin; the aperture is 3.0 (scale 2, 6 px).
  - **Edges, x.** One reference `[100..200]`, moving `[202.5..302.5]`: captured, `dx == −2.5`, `kindX == edge`; one vertical line at `x = 200`. Moving at `[203.5..303.5]`: not captured, `dx == fallbackDx`.
  - **Centre, y.** A reference centred at `y = 50` and a moving box centred at `51`: `dy == −1`, `kindY == centre`.
  - **Between.** `L = [0..100]`, `R = [300..400]` and a moving box 100 wide at `[149..249]`: `dx == 1`, `kindX == between`; two marks of length 50 each (P-8: no edge lies within 3).
  - **Between refused.** The same, but the box is 250 wide: no `between` candidate.
  - **Continuing.** `A = [0..100]`, `L = [150..250]` (gap 50), moving at `[302..402]`: `dx == −2`, `kindX == continuing`; two marks of length 50.
  - **Touching.** `A = [0..100]` and `L = [100..200]`, moving at `[200.5..]`: the capture is an edge, never `continuing`; no mark.
  - **Ties.** An edge offset and a centre offset of equal size: the edge wins. Two references at the same position: `refX` is the lower handle, and they share one merged line (`lineCount == 1`).
  - **Shift.** `freeX: false` gives `dx == fallbackDx` and no x-line, even inside the aperture.
  - **Recheck.** A spacing capture on x whose row is lost after y snaps (y's fallback moves the box off the row) falls back to x's best edge candidate in the same pass. The case is constructed so x has an edge candidate at a larger offset.
  - **Capacity.** 40 references on one line at scale 0.05: `lineCount == 16`, no throw.
  - **Allocation-free.** Covered by Task 10, not here.
- [ ] **Step 2:** Fail (missing file).
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Pass. Named mutations: `<=` to `<` on the aperture; the edge-before-centre tie flipped; recheck done sequentially (x sees the rechecked y); `g ≤ ε` filter removed; `freeX` ignored.
- [ ] **Step 5:** Plan gate. Commit `feat(plan): alignment guide solver`.


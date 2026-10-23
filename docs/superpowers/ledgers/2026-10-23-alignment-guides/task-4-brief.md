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

### Task 4: The reference cache

**Files:**
- Create: `packages/jet_cad_2d_plan/lib/src/guides/guide_references.dart`
- Test: `packages/jet_cad_2d_plan/test/guides/guide_references_test.dart`

**Interfaces:**
- Consumes: `GuideReferences` (Task 3); `boxOfLeaves` and `UnitKinds` (`jet_cad_2d_kit`); `UnitComponent`.
- Produces:

```dart
final class GuideReferenceCache {
  /// [units] is read lazily: the session creates its `UnitIndexCache` after
  /// the tools (P-2).
  GuideReferenceCache(DraftDocument document,
      {required UnitIndexCache Function() units});
  /// Rebuilt lazily when `units().current` is a new object, or the
  /// document's `commands.stateId` or table revision changed, since the last
  /// read. `UnitIndexCache` already folds in the locks and the catalog.
  GuideReferences get current;
  /// Writes the union of [handles]' boxes into [out] (minX, minY, maxX, maxY);
  /// false when none of them has a box. May allocate (drag start only).
  bool unionOf(Iterable<Handle> handles, Float64List out);
}

/// A placement ghost's box: [box] (definition space) through [t], as an AABB.
void worldBoxOf(SymbolBox box, Transform2 t, Float64List out);
```

**Build rules** (spec *The boxes*):
- **Units** come from `units().current.units` (`UnitInfo`): its `box`, its `toWorld` (generated units already carry the group's transform) and its `kind`. Seats (`kind == UnitKinds.seat`) are skipped.
- **Other root instances** (a bar counter, furniture with no `UnitComponent`) come from one pass over `tree.nodes`. Their boxes come from one bucketing pass over `entities.liveSlots` (leaves by owner, ATTRIBs skipped), then `boxOfLeaves` per definition, memoised per build.
- Skip:
  - an instance whose layer is off (`UnitInfo.visible` false, or the layer lookup `UnitIndex` uses), whose own node `visible` is false, or whose root group's `visible` is false (P-2);
  - a singular or non-finite transform;
  - an empty or non-finite box.
- World AABB = the four transformed corners' min and max.
- Handles ascending (`tree.nodes` order).
- **Deviation recorded for the human** (spec said "nested instances are included"): this plan uses `UnitIndex`'s and `boxOfEntry`'s rule, direct leaves only, so a moved object and its ghost get the same box as the unit index. Nested-instance geometry is not in a box.

- [ ] **Step 1: Write failing tests**, each over a built `DraftDocument` (use `test/support/unit_fixtures.dart`):
  - a table rotated 30° at `(4000, −2500)`: its box equals the AABB of its four rotated corners, within `1e-9`;
  - a mirrored instance (scale `(−1, 1)`) at a 90° turn: min is less than max on both axes;
  - a table whose `UNIT` label text sits outside its outline: the box equals the outline's, not the label's;
  - a seat is not in `current`, a table on a hidden layer is not, and a bar counter (a symbol with no `UnitComponent`) is;
  - a generated unit inside a root group gets the group's transform applied; one whose group is hidden is skipped;
  - locking an object (the `locked` listenable) gives a new `current` when `UnitIndexCache` rebuilds;
  - `current` is identical (`identical`) across two reads without a change. After placing a new instance through a command it is a new object with `length + 1`; after undo, `length` again;
  - `unionOf` of two rotated tables equals the union of their boxes; of a hidden-only set it returns false.
- [ ] **Step 2:** Fail.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Pass. Named mutations: ATTRIB not skipped; the seat filter removed; the parent transform not applied; the cache never invalidated.
- [ ] **Step 5:** Plan gate. Commit `feat(plan): alignment guide reference cache`.


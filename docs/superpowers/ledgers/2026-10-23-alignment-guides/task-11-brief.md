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

### Task 11: Docs, demo, CHANGELOG, exit gate

**Files:**
- Modify: `docs/host-guide.md`: a new `### 10.1 Alignment guides` subsection under "## 10. Themes and your own widgets", or a new `## 15. Alignment guides`. Pick one; the TOC is updated if the guide has one.
- Modify: `tool/ci/host_probe/lib/main.dart`: every new ```dart block appears verbatim, whitespace aside (`tool/ci/check_guide.dart`).
- Modify: `packages/jet_cad_2d_plan/CHANGELOG.md` (Unreleased), `packages/jet_cad_2d_flutter/CHANGELOG.md` (Unreleased; already started in Tasks 1–2).
- Modify: `apps/restaurant_demo/lib/main.dart`: pass `alignmentGuides: true` explicitly to `PlanEditor` and set a `PlanTheme` with `guideWidth: 1.5`, so the demo reads as a showcase. Its seeded hall has at least three tables in a row, so equal spacing can be seen. Add tables only if the seed has fewer.
- Test: `apps/restaurant_demo/test/`: one widget test that the bar shows `toolbar-guides` in design and `service-guides` in service.

**Guide content:**
- what counts (edges, centres, equal spacing, movable objects only, the AABB of rotated ones);
- both modes;
- Alt;
- `PlanEditor.alignmentGuides` / `PlanServiceView.alignmentGuides` / `PlanCanvas.alignmentGuides`;
- `controller.alignmentGuides` (`on`, `userOn`, `toggle()`);
- the bar actions (and that a host switching exhaustively over `PlanEditorAction` or `PlanServiceAction` adds `guides`);
- `PlanTheme.guideOnLight` / `guideOnDark` / `guideWidth`;
- that a host whose `actions` equal `values` now gets the toggle.

Snippets: one `PlanEditor(alignmentGuides: false, …)`, one `controller.alignmentGuides.toggle()` with a listener, one `PlanTheme(guideOnLight: …, guideWidth: 2)`.

**CHANGELOG (plan)** bullets: the feature in both modes; the options; `PlanGuideSettings`; the enum values with the migration note; the theme fields; `C-8`'s rule (a guide beats a pointer object-snap hit in a guide-eligible drag).

- [ ] **Step 1:** Write the guide section and the probe additions. Every fenced ```dart or ```yaml block in the guide must also appear, whitespace collapsed, in `tool/ci/host_probe/lib/main.dart` or `tool/ci/host_probe/pubspec.yaml.in`, or `check_guide` fails (P-14). The probe must also compile: build it as CI does (`.github/workflows/ci.yml`). Gate: `cd tool/ci && dart test`. Expected: pass.
- [ ] **Step 2:** Demo change and its test. Run `cd apps/restaurant_demo && flutter test && flutter analyze`. Expected: pass.
- [ ] **Step 3:** Run the full exit gate (Global Constraints, the final-task list), every command, and paste each one's real last lines into the task report.
- [ ] **Step 4:** Results note at `docs/superpowers/notes/2026-10-23-alignment-guides-results.md`. It holds:
  - the commits;
  - every gate's real last lines;
  - the named mutations per task;
  - Task 4's deviation (direct leaves only);
  - the release note on `jet_cad_2d_flutter`'s floor;
  - open questions.
- [ ] **Step 5:** Update `STATUS.md`'s In flight entry. Commit `docs: alignment guides in the host guide, the demo and the CHANGELOGs`.

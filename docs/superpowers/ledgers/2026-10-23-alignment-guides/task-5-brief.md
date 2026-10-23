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

### Task 5: Settings, controller API, theme

**Files:**
- Create: `packages/jet_cad_2d_plan/lib/src/guides/guide_settings.dart`
- Modify: `packages/jet_cad_2d_plan/lib/src/controller/plan_controller.dart`
- Modify: `packages/jet_cad_2d_plan/lib/src/theme/plan_theme.dart`
- Modify: `packages/jet_cad_2d_plan/lib/jet_cad_2d_plan.dart` (export `PlanGuideSettings`)
- Test: `packages/jet_cad_2d_plan/test/guides/guide_settings_test.dart`, `packages/jet_cad_2d_plan/test/theme/plan_theme_guide_test.dart`

**Interfaces:**
- Produces:

```dart
final class PlanGuideSettings extends ChangeNotifier {
  bool get on;        // allowed && userOn
  bool get userOn;    // starts true
  bool get allowed;   // starts true
  void toggle();      // flips userOn, notifies
}
// PlanController:
PlanGuideSettings get alignmentGuides;
@internal set alignmentGuidesAllowed(bool value); // frame-safe, as snappingAllowed
@internal double guideStrokePixels = 1.0;          // written by the views
// PlanTheme: Color? guideOnLight, Color? guideOnDark, double? guideWidth
```

- The allowance setter changes `allowed` at once (the tools read it). Its notification goes out after the frame through `SchedulerBinding.addPostFrameCallback` and `ensureVisualUpdate`, like `snappingAllowed`'s. A user `toggle` notifies at once.
- Disposed with the controller.
- `PlanTheme`:
  - the three fields join the constructor, `copyWith`, `merge`, `lerp` (colours with `Color.lerp`, width with `_lerpBetween`), `==`, `hashCode`, `debugFillProperties` and the "set fields" `toString`;
  - validation uses `positive(theme.guideWidth, 'guideWidth')`;
  - `planPaperPaletteFor` applies `withGuide(colour)` after `withSelection` when the theme gives the paper's set a guide colour. With no theme it still returns the `const` set itself.

- [ ] **Step 1: Write failing tests**
  - `on` is true at start. `toggle()` gives `on == false` with one notification. `alignmentGuidesAllowed = false` gives `on == false` at once, and the listener fires only after `tester.pump()`. Setting the same value twice notifies once.
  - The user's choice survives `controller.mode = PlanMode.service` and back.
  - `PlanTheme(guideWidth: 0)` is refused by the scope with an `ArgumentError` naming `guideWidth`.
  - `lerp` at 0.5 of the two guide colours gives `Color.lerp`'s.
  - `merge` keeps `other`'s non-null guide fields.
  - `copyWith(guideOnDark: c)` keeps `guideOnLight`.
  - `==` distinguishes `guideWidth` 1 from 2.
  - `planPaperPaletteFor(darkPaper, PlanTheme(guideOnDark: c)).guide == c` and `selection` is unchanged; `planPaperPaletteFor(lightPaper, null)` is `identical` to `PaperPalette.light`.
- [ ] **Step 2:** Fail.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Pass. Named mutations: `on` ignoring `allowed`; the allowance notified synchronously; `lerp` dropping `guideWidth`; `planPaperPaletteFor` applying the light colour on dark paper.
- [ ] **Step 5:** Plan gate. CHANGELOG (plan, Unreleased) gets its first bullet; Task 11 completes it. Commit `feat(plan): PlanGuideSettings and the guide theme fields`.


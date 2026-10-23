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

### Task 1: `PaperPalette.guide`

**Files:**
- Modify: `packages/jet_cad_2d_flutter/lib/src/canvas_palette.dart`
- Modify: `packages/jet_cad_2d_flutter/CHANGELOG.md` (new `## Unreleased` at the top)
- Test: `packages/jet_cad_2d_flutter/test/canvas_palette_test.dart` (extend if present, else create)

**Interfaces:**
- Produces:
  - `PaperPalette({..., Color? guide})`, a new optional named argument;
  - `final Color? guide`;
  - `Color get guideColor`: `guide` when set; else `PaperPalette.darkGuide` when `minorGrid.computeLuminance() > 0.5` (a dark paper's overlay ink is light), else `PaperPalette.lightGuide`;
  - `static const Color lightGuide = Color(0xFFE0218A)` and `static const Color darkGuide = Color(0xFFFF5CB0)`;
  - `PaperPalette withGuide(Color guide)`.
- `light` and `dark` set `guide` explicitly. `withSelection`, `==`, `hashCode` and `toString` (if present) carry `guide`.
- Doc on `preview`: "the move's base-to-target line, rubber bands and ghosts". Doc on `guide`: "alignment guides and their gap marks".

- [ ] **Step 1: Write failing tests**
  - `light.guideColor == Color(0xFFE0218A)` and `dark.guideColor == Color(0xFFFF5CB0)`.
  - A custom palette built from `dark`'s colours with `guide` omitted gives `darkGuide`; one from `light`'s colours gives `lightGuide`.
  - `light.withSelection(const Color(0xFF00FF00)).guide == light.guide`.
  - `light.withGuide(c).guide == c`, and every other field equals `light`'s.
  - `light.withGuide(c) != light` and the hash codes differ; `light.withGuide(light.guide!) == light`.
- [ ] **Step 2:** `flutter test test/canvas_palette_test.dart` fails (no `guide`).
- [ ] **Step 3:** Implement as above.
- [ ] **Step 4:** Tests pass. Named mutations to show red: `withSelection` drops `guide`; `==` ignores `guide`; `guideColor`'s luminance test inverted.
- [ ] **Step 5:** Package gate. CHANGELOG line: "`PaperPalette.guide` (and `withGuide`, `guideColor`): the alignment guides' colour; the built-in sets carry a magenta." Commit `feat(flutter): PaperPalette.guide for alignment guides`.

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
}
```

- `SelectTool({this.moveResolver, this.gates, this.moveAdjuster})`, with `final MoveAdjuster? moveAdjuster`.

**Wiring in `SelectTool`:**
- `_enter`: for `DragKind.move`, call `moveAdjuster?.begin(ctx, drag.handles)`.
- `_follow`: also store `_lastTouch = e.isTouch` and `_lastAlt = e.alt`.
- `_retarget`, for a non-rotate drag:
  1. `_resolve`;
  2. if an adjuster is set and the drag is a move, copy `_dragPoint.point` into a reused `_adjusted` field, call `adjust(...)` with `orthoBase: shift ? drag.base : null`, then `drag.moveTo(_adjusted)`; else `drag.moveTo(_dragPoint.point)` as today;
  3. the attachment runs as today; when `_attached` becomes true, call `moveAdjuster?.suppress()`.
- `onKey`: Alt-left or Alt-right down or up (not a repeat) during a drag sets `_lastAlt` and calls `_onCamera()`, exactly as Shift does today.
- `_endDrag`: call `moveAdjuster?.end()` before clearing `_drag`.
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
  - with `moveAdjuster` null, the committed transform equals today's for the same pointer path (a differential test against a second `SelectTool()` run).
- [ ] **Step 2:** The tests fail to compile (no `moveAdjuster`).
- [ ] **Step 3:** Implement the wiring above.
- [ ] **Step 4:** Pass. Named mutations: `moveTo(_dragPoint.point)` kept instead of `_adjusted`; `orthoBase` always passed; `suppress` not called; Alt key not re-targeting; `end` skipped on cancel.
- [ ] **Step 5:** Package gate. CHANGELOG line: "`SelectTool.moveAdjuster` (`MoveAdjuster`): a generic seam to replace a body move's target after the snap chain." Commit `feat(flutter): SelectTool.moveAdjuster seam`.

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

Past `kGuideCapacity`, further lines and marks are dropped silently. The solve allocates nothing; scratch state is fields of `GuideSolution` or locals of primitive type.

- [ ] **Step 1: Write failing tests**
  - All fixtures are off the origin (around `(5000, −3200)`), with aperture 3.0 for scale 2 at 6 px.
  - **Edges, x.** One reference `[100..200]`, moving `[202.5..302.5]`: captured, `dx == −2.5`, `kindX == edge`; one vertical line at `x = 200`. Moving at `[203.5..303.5]`: not captured, `dx == fallbackDx`.
  - **Centre, y.** A reference centred at `y = 50` and a moving box centred at `51`: `dy == −1`, `kindY == centre`.
  - **Between.** `L = [0..100]`, `R = [300..400]` and a moving box 100 wide at `[101..201]`: `dx == 49`, `kindX == between`; two marks with gaps 100 and 100.
  - **Between refused.** The same, but the box is 250 wide: no `between` candidate.
  - **Continuing.** `A = [0..100]`, `L = [150..250]` (gap 50), moving at `[302..402]`: `dx == −2`, `kindX == continuing`; two marks of length 50.
  - **Touching.** `A = [0..100]` and `L = [100..200]`, moving at `[200.5..]`: the capture is an edge, never `continuing`; no mark.
  - **Ties.** An edge offset and a centre offset of equal size: the edge wins. Two references at the same position: the lower handle's is `kindX`, and both get lines.
  - **Shift.** `freeX: false` gives `dx == fallbackDx` and no x-line, even inside the aperture.
  - **Recheck.** A spacing capture on x whose row is lost after y snaps (y's fallback moves the box off the row) falls back to x's best edge candidate in the same pass. The case is constructed so x has an edge candidate at a larger offset.
  - **Capacity.** 40 references on one line at scale 0.05: `lineCount == 16`, no throw.
  - **Allocation-free.** Covered by Task 10, not here.
- [ ] **Step 2:** Fail (missing file).
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Pass. Named mutations: `<=` to `<` on the aperture; the edge-before-centre tie flipped; recheck done sequentially (x sees the rechecked y); `g ≤ ε` filter removed; `freeX` ignored.
- [ ] **Step 5:** Plan gate. Commit `feat(plan): alignment guide solver`.

### Task 4: The reference cache

**Files:**
- Create: `packages/jet_cad_2d_plan/lib/src/guides/guide_references.dart`
- Test: `packages/jet_cad_2d_plan/test/guides/guide_references_test.dart`

**Interfaces:**
- Consumes: `GuideReferences` (Task 3); `boxOfLeaves` and `UnitKinds` (`jet_cad_2d_kit`); `UnitComponent`.
- Produces:

```dart
final class GuideReferenceCache {
  GuideReferenceCache(DraftDocument document);
  /// Rebuilt lazily when the document's state or revision changed since the
  /// last read (as UnitIndexCache keys itself).
  GuideReferences get current;
  /// Writes the union of [handles]' boxes into [out] (minX, minY, maxX, maxY);
  /// false when none of them has a box. May allocate (drag start only).
  bool unionOf(Iterable<Handle> handles, Float64List out);
}

/// A placement ghost's box: [box] (definition space) through [t], as an AABB.
void worldBoxOf(SymbolBox box, Transform2 t, Float64List out);
```

**Build rules** (spec *The boxes*):
- One bucketing pass over `entities.liveSlots`: leaves by owner, ATTRIBs skipped. Then `boxOfLeaves` per definition, memoised per build.
- References:
  - root-level `InstanceNode`s;
  - an `InstanceNode` one level inside a root `GroupNode` that `UnitIndex` would count as a generated unit. Reuse `UnitIndex`'s test: a catalog type, or a locked object. Its `toWorld` is `parent.transform · node.transform`.
- Skip:
  - seats (`UnitComponent.kind == UnitKinds.seat`);
  - a hidden layer, or `visible == false`;
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
  - a generated unit inside a root group gets the group's transform applied;
  - `current` is identical (`identical`) across two reads without a change. After placing a new instance through a command it is a new object with `length + 1`; after undo, `length` again;
  - `unionOf` of two rotated tables equals the union of their boxes; of a hidden-only set it returns false.
- [ ] **Step 2:** Fail.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Pass. Named mutations: ATTRIB not skipped; the seat filter removed; the parent transform not applied; the cache never invalidated.
- [ ] **Step 5:** Plan gate. Commit `feat(plan): alignment guide reference cache`.

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
/// Reuses one Paint; allocates nothing per call.
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
4. Write `target = raw + (dx, dy)`.

`objectSnapped` does not stop the solve (C-8).

**`suppress`** clears the solution. **`paint`** draws the solution through `GuidePainter`, with `paper.guideColor` and `strokePixels()`. **`end`** clears it.

The settings' listener requests a repaint when guides turn off mid-drag. The tool notifies, so the overlay repaints.

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
- [ ] **Step 2:** Fail.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Pass. Named mutations:
  - `objectSnapped` short-circuiting the solve;
  - the pin rule inverted;
  - `fallback` taken from `raw` instead of `target`;
  - `begin` ignoring `movable`;
  - `paint` ignoring `suppress`.
- [ ] **Step 5:** Plan gate. Commit `feat(plan): alignment guides in design moves`.

### Task 7: Placement: `PlanSymbolTool`

**Files:**
- Modify: `packages/jet_cad_2d_plan/lib/src/tools/plan_symbol_tool.dart`
- Modify: the place that constructs `PlanSymbolTool`, so it receives the session's `GuideReferenceCache`, the settings and the stroke
- Test: `packages/jet_cad_2d_plan/test/guides/placement_guides_test.dart`

**Interfaces:**
- Consumes: Tasks 3–6 (`GuidePainter`, `worldBoxOf`, `solveGuides`).
- `PlanSymbolTool` gains optional constructor parameters `GuideReferenceCache? guides`, `PlanGuideSettings? guideSettings` and `double Function()? guideStroke`. With null, behaviour equals today's.

**Behaviour** (spec *The delta: Place*, *Modes*):
- `_free({bool guided = true})`. The attachment query's `current:` uses `_free(guided: false)`; `_syncPlacement` uses the guided one.
- A new `_solveGuides(ctx)` runs after `_resolve` in `_update`, and in the R and M key branch before `_syncPlacement`.
  - It computes the ghost box at the raw pointer: `worldBoxOf(boxOfEntry(entry), placementTransform(at: raw, ...))`, recomputed only when the turns, the mirror, the armed symbol or the raw point changed. The transform allocation is baseline, `_free()`'s own.
  - It solves with both axes free and `fallback = at − raw`, and stores the guided anchor in a reused `Vector2`.
- `_track` stores `e.isTouch` and `e.alt`.
- An Alt key down or up re-runs `_update` from the last screen point, as `_onCamera` does.
- `paintOverlay` paints the solution when no attachment is captured.
- `moving` is the empty set (const).

- [ ] **Step 1: Write failing tests** (90°-turned armed table, scale 2, references off the origin):
  - hovering 4 px off a placed table's top edge snaps the ghost's box max-y to that edge; the placed instance (pointer up) has exactly that transform;
  - pressing R with no pointer move re-solves: the ghost's new box captures a different edge and the solution changes;
  - pressing M behaves the same;
  - with Alt held, placement equals guides-off;
  - a wall-attaching symbol over a wall takes the attachment, and no guide is painted;
  - placing two tables in a row: the second sees the first as a reference, because the cache rebuilt after the placement command.
- [ ] **Step 2:** Fail.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Pass. Named mutations: the attachment's `current` guided; the R branch not re-solving; the box not recomputed on a turn.
- [ ] **Step 5:** Plan gate. Commit `feat(plan): alignment guides while placing a symbol`.

### Task 8: Service: `ServiceTool`

**Files:**
- Modify: `packages/jet_cad_2d_plan/lib/src/service/service_tool.dart`
- Modify: `packages/jet_cad_2d_plan/lib/src/service/service_session.dart` (owns a `GuideReferenceCache` over the service copy; passes it, the settings and the stroke to `ServiceTool`)
- Test: `packages/jet_cad_2d_plan/test/guides/service_guides_test.dart`

**Interfaces:**
- Consumes: Tasks 3–6.
- `ServiceTool` gains optional `GuideReferenceCache? guides`, `PlanGuideSettings? guideSettings` and `double Function()? guideStroke`.

**Behaviour:**
- `_startDrag`, after `_moving` is set: `unionOf(_moving)` into a reused box. False means the drag is not eligible.
- `_drag`, for a dragging gesture:
  - `dRaw = e.world − _pressWorld`;
  - solve with fallback `(0, 0)`, both axes free, the aperture by `e.isTouch`, and `moving` = a `Set<Handle>` built once in `_startDrag` from `_moving`;
  - `_dx/_dy = dRaw + (dx, dy)`.
- Store `_lastWorld` (the last raw world point), `_lastTouch` and `_lastAlt`.
- **Camera.** On entering `_Gesture.dragging`, add a camera listener that recomputes the world point from `_lastScreen` (`camera.value.screenToWorld`), re-solves and notifies. Remove it in `_reset`, which every release, cancel and dispose path reaches. Also call `_reset` from `dispose` if it is not already called there.
- **Alt key.** `onKey`: Alt down or up while dragging re-solves from the last world point.
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
- [ ] **Step 4:** Pass. Named mutations: the camera listener not removed in `_reset`; `_dx` computed without the offset on release; the `moving` set not excluded (a table snapping to itself, `dx == 0` always).
- [ ] **Step 5:** Plan gate. Commit `feat(plan): alignment guides in service drags`.

### Task 9: Views and bars

**Files:**
- Modify: `packages/jet_cad_2d_plan/lib/src/canvas/plan_canvas.dart`
- Modify: `packages/jet_cad_2d_plan/lib/src/service/view/plan_service_view.dart`
- Modify: `packages/jet_cad_2d_plan/lib/src/service/view/plan_service_bar.dart`
- Modify: `packages/jet_cad_2d_plan/lib/src/editor/plan_editor.dart`
- Modify: `packages/jet_cad_2d_plan/lib/src/editor/plan_editor_bar.dart`
- Modify: `packages/jet_cad_2d_plan/lib/src/l10n/strings.dart`, `strings_en.dart`, `strings_de.dart`, `strings_tr.dart`
- Test: `packages/jet_cad_2d_plan/test/guides/guide_views_test.dart`

**Interfaces:**
- Consumes: `PlanController.alignmentGuides`, `alignmentGuidesAllowed` and `guideStrokePixels` (Task 5).
- Produces:
  - `PlanCanvas({..., this.alignmentGuides = true})`, `PlanServiceView({..., this.alignmentGuides = true})` and `PlanEditor({..., this.alignmentGuides = true})`, each with `final bool alignmentGuides`;
  - `enum PlanEditorAction { export, print, undo, redo, guides, snap, zoom }` and `enum PlanServiceAction { undo, redo, guides, merge, split, export, print }`, so the declaration order is the default order;
  - `PlanStrings.alignmentGuides` (tooltip and semantics): en "Alignment guides", de "Ausrichtungshilfen", tr "Hizalama kılavuzları".

**Behaviour:**
- **Allowance.** `PlanCanvas` and `PlanServiceView` write `controller.alignmentGuidesAllowed = widget.alignmentGuides` in `initState` and in `didUpdateWidget`. On dispose, and on a controller swap for the old controller, they set it back to true, exactly as `PlanCanvas` does for `snappingAllowed` (`plan_canvas.dart:165,198,210`).
- `PlanEditor` passes its value to the canvas and to the `PlanServiceView` it builds.
- **Stroke.** Both views write `controller.guideStrokePixels = theme?.guideWidth ?? 1.0` where they resolve the theme today, beside the `selectionWidth` use.
- **Editor bar.** `_editCommands` gains a `_BarCommand(id: 'guides', icon: Icons.straighten, ...)` after redo. It is a toggle: `_BarCommand` gains `final bool? selected`, and the toolbar renders a selected command as an `IconButton` with `isSelected` and a `selectedIcon`. It is listenable through `controller.alignmentGuides`, and is left out when `!widget.alignmentGuides`. `_toolbarFor` maps `PlanEditorAction.guides` to `(_byId(edit, 'guides'), false)`. The readouts switch lists `PlanEditorAction.guides => null` explicitly; no `_ =>` path is relied on.
- **Service bar.** The `_actions` button switch has `PlanServiceAction.guides =>` a toggle button keyed `service-guides`, null when `!widget.alignmentGuides`. The group switch puts `guides` in group 0.
- Keys: `toolbar-guides` and `service-guides`.

- [ ] **Step 1: Write failing tests**
  - `PlanEditor` with default `bar` shows `toolbar-guides`; tapping it flips `controller.alignmentGuides.userOn` and the button's selected state.
  - `PlanEditorBar(actions: [PlanEditorAction.undo, PlanEditorAction.guides])` shows it after Undo. `PlanEditor(alignmentGuides: false)` shows none, and `controller.alignmentGuides.on` is false after a pump.
  - `PlanServiceView` with default bar shows `service-guides` after `service-redo`; with `alignmentGuides: false`, none.
  - Disposing a `PlanCanvas(alignmentGuides: false)` restores `allowed == true`.
  - Switching `PlanEditor` from design to service keeps the user's `userOn == false`.
  - `PlanTheme(guideWidth: 3)` under `PlanEditor` sets `controller.guideStrokePixels == 3`.
  - The tooltip reads "Hizalama kılavuzları" under `Locale('tr')`.
- [ ] **Step 2:** Fail.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Pass. Named mutations: the editor's default path not including the command; dispose not resetting the allowance; `PlanEditor` not passing its value to the service view.
- [ ] **Step 5:** Plan gate. Commit `feat(plan): alignment guide options and bar toggles`.

### Task 10: The allocation invariant

**Files:**
- Create: `packages/jet_cad_2d_plan/test/invariants/guide_allocation_test.dart`

**Interfaces:**
- Consumes: `vm_allocation_meter.dart` (`AllocationMeter`), the rigs of Tasks 6–8.

**Method** (follow `pick_allocation_test.dart`, including its `--enable-vmservice` skip reason):
- For each tool (design move, placement, service), warm 50 events, then meter 200 pointer-driven re-targets and 50 camera-driven ones.
- Do this with guides on and with guides off (`toggle()`), at 10 and at 200 references, and for service with one and with three moved tables.
- **Assert:** for each class in `{_Double, Aabb2, Transform2, Vector2, _GrowableList, _List, _Map, _Set, _Closure, _Record}`, the count with guides on minus the count with guides off is `≤ 0` per event. The on-minus-off difference does not grow from 10 to 200 references.
- `GuidePainter.paint` over a full solution (16 lines, 16 marks), 100 calls: zero instances of any class.
- The capacity of `GuideSolution.lines` and `GuideSolution.marks` is unchanged (`identical` buffers).

- [ ] **Step 1:** Write the test.
- [ ] **Step 2:** Run `flutter test --enable-vmservice test/invariants/guide_allocation_test.dart`. Expected: pass. If it fails, fix the allocating code in Tasks 3–8's files. Never raise a budget.
- [ ] **Step 3:** Named mutations, each shown red:
  - `GuidePainter` creating a `Paint` per call;
  - `solveGuides` building a `List` of candidates;
  - `PlanMoveGuides.adjust` cloning `raw`;
  - the service re-solve allocating a `Set` per event.
- [ ] **Step 4:** Plan gate, including `canvas_paint_allocation_test`. Commit `test(plan): alignment guides add no allocation per event`.

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

- [ ] **Step 1:** Write the guide section and the probe additions. Run `cd tool/ci && dart test` and `dart run check_guide.dart` (or the probe check CI runs; see `.github/workflows/ci.yml`). Expected: pass.
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

# Rubber-band selection in the selection mode — implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** In the selection mode a drag on the floor can draw a band that
selects tables — by direction a window or a crossing, groups whole, locked
tables never — chosen by the host with `FloorPlanView(floorDrag:)`, and,
under the default `pan`, opened by a modifier mouse drag.

**Architecture:** The render package's band look moves into a shared
public `SelectionBandPainter` and `bandModeFor`, which the design mode's
`SelectTool` keeps using unchanged. The floor planner's `TableSelectTool`
gains a `banding` gesture: it starts per RB-2, paints with the shared
painter, and at the up asks the spatial index's `forEachInstanceInBand`
(under `QueryFilter.snapping()`), keeps the picker's candidates, expands
groups by the window or crossing rule, and replaces or adds in one call.
`FloorPlanView` carries the host's option to the tool through the internal
`ServiceOptions` record.

**Tech stack:** Dart 3 / Flutter (`flutter`, `dart` on `PATH`),
`flutter_test`, the VM service for the allocation meter
(`--enable-vmservice`).

**Spec:** [2026-10-13-rubber-band-selection-design.md](../specs/2026-10-13-rubber-band-selection-design.md),
revision 2, approved 2026-10-13. RB-1 to RB-7, rulings R-1 to R-4, facts
F-1 to F-10, tests RB1 to RB20 with their mutants M-RB1 to M-RB21.

**Started** on the human's *"evet, devam et"* (2026-10-13) after the
spec's approval. **Branch:** `feat/rubber-band` (worktree
`.claude/worktrees/rubber-band`), from `main` at `1e53de1`. **Ledger:**
`.superpowers/sdd/2026-10-13-rubber-band-selection/`, archived to
`docs/superpowers/ledgers/2026-10-13-rubber-band-selection/` as the
branch's last commit. **Release 0.7.0** follows the merge, as its own step.

## Global Constraints

- `CLAUDE.md`'s non-negotiables. **The frame path allocates nothing per
  entity**: `query_allocation_test`, `paint_allocation_test` and
  `pick_allocation_test` stay untouched and green. A live band builds no
  `Paint` and no `Path` per frame (RB16).
- **`jet_cad_2d` is not edited.** `jet_cad_2d_flutter` is edited **only in
  Task 1**.
- **No existing public signature, `==`, `hashCode` or `toString`
  changes.** New public API, exactly: `bandModeFor`, `SelectionBandPainter`
  (Task 1, render barrel); `FloorPlanFloorDrag`,
  `FloorPlanView.floorDrag` (Tasks 2–3, host barrel). Every new parameter
  is named and optional with `pan` as its default. The internal
  `ServiceOptions` record gains `floorDrag` (Task 2).
- **Existing tests pass unedited**, with these named exceptions only: the
  `ServiceOptions` record literals in
  `test/service/service_options_test.dart`,
  `test/host/table_groups_context_test.dart` and
  `test/host/table_overlay_test.dart` gain `floorDrag:
  FloorPlanFloorDrag.pan` (Task 2). Any other test that has to change is a
  finding for the task's report.
- **The standing sets stay exactly as they are**
  (`tool/ci/standing_failures.txt`, `standing_skips.txt`), compared from
  the repo root with `dart run tool/ci/expect_failures.dart --package
  packages/<pkg> --root packages/<pkg> <run.json>` (runs made with
  `--file-reporter json:<run.json>`). On macOS the render package's
  `text_lod_ladder` rungs 1–2 pass: the recorded standing difference, not
  a finding. The engine's `dart test` exits 1 for its two fingerprints
  while `expect_failures` exits 0.
- **Every task ends green** in every package it touches and every package
  that reads what it changed. The planner runs with `flutter test
  --enable-vmservice`. `flutter analyze` / `dart analyze`, and `dart format
  --output=none --set-exit-if-changed .`, clean.
- **Fixtures** (the spec's testing section): the camera is y-flipped,
  scaled ≠ 1 and off the origin (it never rotates); tables are rotated
  and one is mirrored; one L-shaped table is rotated 37°; the plans hold
  a group of three, a table on a locked layer, a group with a locked
  member, an unnumbered table, a table on a hidden layer and a non-table
  symbol (the planter).
- **Each named mutant is applied, seen red and reverted**, its killer
  named in the report.
- **Never `git checkout` a file to revert it**; copy it aside or `git show
  HEAD:path > path`. **Never commit an `analysis_options.yaml`.** **Never
  synthesize test output.** Code, comments and commits in English; commit
  trailers name the model that wrote the commit.
- **No handle and no component type crosses the host barrel.**
- **The worktree guard:** this session's shell refuses `$VAR` in argument
  position, `bash <script>` and git-mixing pipelines inside the worktree;
  use plain commands and literal paths and SHAs.

## Review Focus

The situations a person meets that the spec's table does not name, each
pinned by a test in the task named:

1. **A tablet under `band` on a crowded floor**: a finger in the aisle
   10 px off a table's box draws a band, a tap there still selects that
   table, and a finger on the table itself still moves it. Task 2, RB5b;
   Task 3, RBV7.
2. **A band, then at once a tap on a table**: the tap acts normally (no
   stuck state, no double tap made from the band's press). Task 2, RB13b.
3. **A band while a host status, group colour and zone veil are drawn**:
   the band takes veiled tables and paints over the fills (it is an
   overlay). Task 3, RBV6.
4. **The design mode, after the refactor**: its band still selects, still
   toggles with Shift at the up, and still paints the same colours. Task
   1, BP3 and the existing `tool_palette_test` / `select_tool` tests.
5. **A host flipping `floorDrag` while the view is shown**: the next press
   reads the new value; a band in progress finishes as it started. Task 3,
   RBV5.

---

## File structure

| File | Responsibility | Task |
|---|---|---|
| `packages/jet_cad_2d_flutter/lib/src/selection_band.dart` | `bandModeFor`, `SelectionBandPainter` | 1 |
| `packages/jet_cad_2d_flutter/lib/jet_cad_2d_flutter.dart` | exports `src/selection_band.dart` | 1 |
| `packages/jet_cad_2d_flutter/lib/src/select_tool.dart` | uses both; `_drawDashedRect` goes | 1 |
| `packages/jet_cad_2d_flutter/test/selection_band_test.dart` | BP1–BP3 | 1 |
| `packages/jet_cad_floor_plan/lib/src/host/floor_plan_types.dart` | `FloorPlanFloorDrag` | 2 |
| `packages/jet_cad_floor_plan/lib/src/service/table_select_tool.dart` | `floorDrag` in `ServiceOptions`; the `banding` gesture | 2 |
| `packages/jet_cad_floor_plan/test/service/table_band_test.dart` | RB1, RB2, RB5–RB16 at the tool | 2 |
| `packages/jet_cad_floor_plan/test/invariants/band_allocation_test.dart` | RB16 | 2 |
| `packages/jet_cad_floor_plan/lib/src/host/floor_plan_view.dart` | `floorDrag` | 3 |
| `packages/jet_cad_floor_plan/lib/jet_cad_floor_plan.dart` | shows `FloorPlanFloorDrag` | 3 |
| `packages/jet_cad_floor_plan/test/host/band_view_test.dart` | RBV1–RBV8 (RB3, RB4, RB13, RB14, RB18, RB19 through the view) | 3 |
| `apps/restaurant_demo/lib/main.dart`, `demo_strings.dart`, `apps/restaurant_demo/test/demo_test.dart` | the Floor drag switch | 4 |
| `docs/host-guide.md`, `tool/ci/host_probe/lib/main.dart`, `CHANGELOG.md`, `STATUS.md`, four specs | RB-7 | 4 |

---

### Task 1: The shared band painter (RB-6, render package)

**Files:**
- Create: `packages/jet_cad_2d_flutter/lib/src/selection_band.dart`
- Modify: `packages/jet_cad_2d_flutter/lib/jet_cad_2d_flutter.dart` (add `export 'src/selection_band.dart';` beside `export 'src/selection_style.dart';`, `:65`)
- Modify: `packages/jet_cad_2d_flutter/lib/src/select_tool.dart` (`:239`, `:307` the mode; `:876-934` `paintOverlay` and `_drawDashedRect`)
- Test: `packages/jet_cad_2d_flutter/test/selection_band_test.dart`

**Interfaces:**
- Consumes: `BandMode` (`jet_cad_2d`), `PaperPalette.windowBand` /
  `crossingBand`, `kBandFillAlpha` (`selection_style.dart`).
- Produces: `BandMode bandModeFor(Offset start, Offset end)`;
  `final class SelectionBandPainter { SelectionBandPainter(); void
  paint(Canvas canvas, Rect rect, BandMode mode, PaperPalette paper); }`.

- [ ] **Step 1: Write the failing tests** — `test/selection_band_test.dart`,
  with a recording canvas (use the package's `SpyCanvas` the way
  `tool_palette_test.dart` does; read its helpers first):
  - **BP1** `bandModeFor`: `(Offset(310, 40), Offset(520, 90))` is window;
    `(Offset(520, 90), Offset(310, 40))` crossing; equal x is window;
    `(Offset(310, 90), Offset(309.5, 40))` crossing. Kills **M-BP1** (`>`
    for `>=`) and **M-BP2** (y compared).
  - **BP2** a window over `Rect.fromLTRB(312.5, 41.25, 518.75, 97.5)` on
    `PaperPalette.light`: two `drawRect`s at that rect, the fill
    `0xFF1E6FE8` at `kBandFillAlpha`, then a 1 px stroke `0xFF1E6FE8`; a
    crossing over the same rect: one fill `drawRect` (`0xFF2E9E5B` at the
    alpha), then one `drawPath` stroked `0xFF2E9E5B` — the path's bounds
    equal the rect within 1e-9, and its first dash runs from the top-left
    corner 6 px right. Kills **M-RB18** (the mode's stroke swapped).
  - **BP3** one painter painting a window, then a crossing, then a window
    again into three spies: the third call's recorded paints are the
    first call's (colours, style, width) — no state leaks between calls.
    Kills **M-BP3** (`_stroke.color = color` moved inside the crossing
    branch: a window after a crossing strokes in the crossing's colour).
  Run: `cd packages/jet_cad_2d_flutter && flutter test test/selection_band_test.dart` — fails: `selection_band.dart` does not exist.

- [ ] **Step 2: Write the implementation** — `lib/src/selection_band.dart`:

```dart
// The selection band's direction rule and look (interaction-core D1, spec
// D8), shared by the design mode's SelectTool and the floor planner's
// selection mode (rubber-band spec RB-6).
import 'dart:math' as math;
import 'dart:ui';

import 'package:jet_cad_2d/jet_cad_2d.dart' show BandMode;

import 'canvas_palette.dart';
import 'selection_style.dart';

/// The band's mode by its drag direction (interaction-core D1): left to
/// right is a window, right to left a crossing.
BandMode bandModeFor(Offset start, Offset end) =>
    end.dx >= start.dx ? BandMode.window : BandMode.crossing;

/// Paints a selection band over a rect in screen pixels: the band colour
/// at [kBandFillAlpha], a 1 px outline, solid for a window, dashed 6 on and
/// 4 off for a crossing, walking the edges clockwise from the top-left.
///
/// Keeps its two paints and its path and resets them per call, so a live
/// band builds no `Paint` and no `Path` per frame.
final class SelectionBandPainter {
  SelectionBandPainter();

  final Paint _fill = Paint();
  final Paint _stroke = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.0;
  final Path _dashes = Path();

  void paint(Canvas canvas, Rect rect, BandMode mode, PaperPalette paper) {
    final crossing = mode == BandMode.crossing;
    final color = crossing ? paper.crossingBand : paper.windowBand;
    _fill.color = color.withAlpha(kBandFillAlpha);
    canvas.drawRect(rect, _fill);
    _stroke.color = color;
    if (!crossing) {
      canvas.drawRect(rect, _stroke);
      return;
    }
    _dashes.reset();
    _edge(rect.left, rect.top, rect.right, rect.top);
    _edge(rect.right, rect.top, rect.right, rect.bottom);
    _edge(rect.right, rect.bottom, rect.left, rect.bottom);
    _edge(rect.left, rect.bottom, rect.left, rect.top);
    canvas.drawPath(_dashes, _stroke);
  }

  /// One edge's dashes, from (x0, y0) to (x1, y1): what `SelectTool`'s
  /// `_drawDashedRect` drew, on doubles.
  void _edge(double x0, double y0, double x1, double y1) {
    const on = 6.0, off = 4.0;
    final dx = x1 - x0, dy = y1 - y0;
    final length = math.sqrt(dx * dx + dy * dy);
    if (length == 0) return;
    final ux = dx / length, uy = dy / length;
    var travelled = 0.0;
    var drawing = true;
    while (travelled < length) {
      final step = math.min(drawing ? on : off, length - travelled);
      if (drawing) {
        _dashes
          ..moveTo(x0 + ux * travelled, y0 + uy * travelled)
          ..lineTo(x0 + ux * (travelled + step), y0 + uy * (travelled + step));
      }
      travelled += step;
      drawing = !drawing;
    }
  }
}
```

  Check the relative imports against the package's layout (where
  `PaperPalette` and `kBandFillAlpha` live) and adjust the two `import`
  lines only.

- [ ] **Step 3: `SelectTool` uses them.** In `select_tool.dart`: replace
  both `_end.dx >= _start.dx ? BandMode.window : BandMode.crossing` (`:239`,
  `:307`) with `bandModeFor(_start, _end)`; add a field `final
  SelectionBandPainter _bandPainter = SelectionBandPainter();`; the band
  branch of `paintOverlay` becomes
  `_bandPainter.paint(canvas, rect, _bandMode!, paper);` after the
  `rect == null` return; delete `_drawDashedRect`. Nothing else in the
  file changes (Shift is still read at the up, `:524`).

- [ ] **Step 4: Run** — `cd packages/jet_cad_2d_flutter && flutter test
  test/selection_band_test.dart test/tool_palette_test.dart` (the latter's
  `M-DT-8: SelectTool` group pins the design band's colours, dashes and
  pixels: RB17) — all pass; then the package's whole gate (the standing
  comparison), `flutter analyze`, `dart format`.

- [ ] **Step 5: Mutants** M-BP1, M-BP2, M-BP3, M-RB18: each applied, seen
  red, reverted; killers in the report.

- [ ] **Step 6: Commit** — `feat(render): a shared selection band painter
  and direction rule`.

---

### Task 2: The band in the selection tool (RB-2 to RB-5, RB-6's tool side)

**Files:**
- Modify: `packages/jet_cad_floor_plan/lib/src/host/floor_plan_types.dart` (after `FloorPlanLongPress`, `:173-180`; and that enum's `contextMenu` doc)
- Modify: `packages/jet_cad_floor_plan/lib/src/service/table_select_tool.dart`
- Modify: `packages/jet_cad_floor_plan/lib/src/host/floor_plan_view.dart:698-702` (the `options` record literal gains `floorDrag: FloorPlanFloorDrag.pan` — Task 3 wires the widget field)
- Modify (named exceptions): the `ServiceOptions` literals in `test/service/service_options_test.dart`, `test/host/table_groups_context_test.dart`, `test/host/table_overlay_test.dart`
- Test: `packages/jet_cad_floor_plan/test/service/table_band_test.dart`
- Test: `packages/jet_cad_floor_plan/test/invariants/band_allocation_test.dart`

**Interfaces:**
- Consumes: Task 1's `bandModeFor`, `SelectionBandPainter`;
  `ctx.index.forEachInstanceInBand(Aabb2, BandMode, QueryFilter,
  void Function(Handle))`; `QueryFilter.snapping()`;
  `TablePicker.pick(Vector2, {double reach = 0})`, `picker.candidates`
  (`List<PickCandidate>`, each `.table.instance`, `.locked`);
  `TableGroupLookup.visibleMembers(id)` / `selectableMembers(id)`
  (`GroupTable.handle`, `.locked`).
- Produces: `enum FloorPlanFloorDrag { pan, band }`; `ServiceOptions` =
  `({bool serviceMoves, FloorPlanLongPress longPress,
  void Function(String, Offset)? onTableContextMenu,
  FloorPlanFloorDrag floorDrag})`, `kDefaultServiceOptions.floorDrag ==
  FloorPlanFloorDrag.pan`.

- [ ] **Step 1: The enum** — in `floor_plan_types.dart`, after
  `FloorPlanLongPress`:

```dart
/// What a one-pointer drag on the empty floor does in the selection mode
/// (rubber-band spec RB-1). The design mode is unaffected.
enum FloorPlanFloorDrag {
  /// Pans the camera (the default). With Shift, Ctrl or Cmd held at the
  /// press, a mouse or stylus drag draws a band that adds to the
  /// selection.
  pan,

  /// Draws a band that selects tables: left to right takes the tables
  /// wholly inside, right to left every table it touches. The camera
  /// pans with two fingers, the wheel or trackpad, and the middle button.
  band,
}
```

  and `FloorPlanLongPress.contextMenu`'s doc becomes: "Reports the table
  to `FloorPlanView.onTableContextMenu`, as a secondary click does; a
  touch screen's multiple selection is then a band
  (`FloorPlanFloorDrag.band`)."

- [ ] **Step 2: The record** — in `table_select_tool.dart`,
  `ServiceOptions` gains `FloorPlanFloorDrag floorDrag` (last field) and
  `kDefaultServiceOptions` gains `floorDrag: FloorPlanFloorDrag.pan`. Add
  `floorDrag: FloorPlanFloorDrag.pan` to the literal in
  `floor_plan_view.dart:698-702` and to the three named test files'
  literals. Run the planner's suite: green, unchanged behaviour.

- [ ] **Step 3: Write the failing tests** — `test/service/table_band_test.dart`.
  Build its own rig on `table_select_tool_test.dart`'s pattern (read
  that file's `Rig` first; copy, do not import it): a service copy
  decoded with `DraftPermissions.runtime`, camera
  `Transform2(0.1, 0, 0, -0.1, 700, 450)` (y-flipped, scaled, off the
  origin), its own `SpatialIndex`, `SelectionController`, a
  `ValueNotifier<Map<String, TableGroup>>` for groups, an `options`
  closure over a mutable `ServiceOptions` (so a test sets
  `floorDrag`), and an `ev()` that takes `shift`, `control`, `meta`,
  `touch` on downs **and** moves and ups. The plan holds:
  - **1** `tableSymbol()` at (-2000, 1000), quarter turn, mirrored;
  - **2** `trapezoidTable` at (2500, 1000), mirrored;
  - **3** `tableSymbol()` at (0, -2500) on a **locked** layer;
  - **4, 5, 6** `tableSymbol()` at (6000, 1000), (7600, 1000),
    (9200, 1000): the group `{'4', '5', '6'}` (id `'g'`);
  - **7, 8** `tableSymbol()` at (6000, -3000), (7600, -3000): group
    `{'7', '8'}` (id `'h'`), **8 on the locked layer**;
  - **9** an L-shaped table, a new fixture constant in this test file:

```dart
/// An L-shaped top, its empty quadrant at the upper right of its
/// 1200 x 1200 box (review V-5): turned 37 degrees, a corner of its
/// bounding box lies off every leaf.
const FurnitureSymbol ellTable = FurnitureSymbol(
  key: 'test.ell',
  name: 'Test L table',
  category: 'Tests',
  tags: ['table', 'test'],
  seats: 3,
  baseX: 600,
  baseY: 600,
  shapes: [
    PolylineShape([(0, 0), (1200, 0), (1200, 500), (500, 500),
        (500, 1200), (0, 1200)], closed: true),
  ],
);
```

    placed with `InsertInstanceCommand`/`placeSymbol` at (-6000, -3000)
    and turned 37° (`placementAt(-6000, -3000, kDeg37, baseX: 600,
    baseY: 600)` via `TransformNodeCommand` after placing);
  - **10** `tableSymbol()` at (-6000, 2500), its label emptied
    (`SetEntityTextCommand(label, '', kTableLabelTag)`): **unnumbered**;
  - **11** `tableSymbol()` at (-9000, 2500) on a **hidden** layer;
  - a **planter** (`planterSymbol`) at (-3500, -1000).

  World rects for bands are computed from the instances' leaves in the
  test (`doc` world bounds of each table via its transform and the
  symbol's shapes), never hard-coded screen numbers without a reason in a
  comment; convert to screen with `camera.value.worldToScreen`.

  Tests (each names the mutant it kills; one `testWidgets` each, fake
  time):
  - **RB1** `pan`: a plain mouse drag on the floor pans (the camera's
    matrix moved by the drag), the selection unchanged, no band painted.
    M-RB1.
  - **RB2** `pan`: Shift (and, in a second leg, Ctrl and Cmd) mouse drag
    from the floor over tables 1 and 2 left to right selects them, adding
    to a selected 9; the same drag with `touch: true` and Shift pans.
    M-RB2.
  - **RB5** `band`: a drag from table 2's top moves it (one undo step);
    from table 3 (locked) is spent; with `serviceMoves: false` a drag
    from 2's top pans. M-RB5.
  - **RB5b** `band`, touch: a finger down 10 px (screen) outside table
    2's box and dragged away draws a band (the tool's `phase` is
    `dragging`, `selectionPreviewTransform` null, table 2 not moved);
    the same press tapped selects table 2. M-RB5b (the reach-only flag
    ignored).
  - **RB6** window: a band whose world rect encloses every leaf of table
    9 while its bounding box's empty-quadrant corner lies outside (assert
    that premise in the test with the instance's world box) selects 9.
    M-RB6 (take by `ctx.index` box: apply as a mutant that keeps an
    instance when its world box is enclosed instead of querying the
    band).
  - **RB7** crossing (drawn right to left) touching only table 1's chair
    selects 1; a crossing over only table 9's empty quadrant takes
    nothing; a drag that goes right of the press then back left paints
    window then crossing and takes by crossing. M-RB7, M-RB7b.
  - **RB8** during a band, the camera zooms ×1.5 about screen (200, 700)
    (`camera.value = …` with a new matrix, as `camera_test` does); at the
    up the band's world rect is the one under the new camera: a table
    inside only under the new camera is taken. M-RB8.
  - **RB9** a window over the whole floor (plain, `band`): 11 (hidden)
    and the planter not selected; 10 selected (its key in
    `selection.keys`). M-RB9.
  - **RB10** a window round 3 alone selects nothing; a window round
    7 and 8 selects 7 only; a crossing touching only 5 selects 4, 5, 6; a
    window round 4 and 5 (6 outside) selects none of the group. M-RB10,
    M-RB10b, M-RB11, M-RB12.
  - **RB11** plain replaces (1 selected, a band over 2 → {2}); Ctrl band
    over 1 and 2 with 1 already selected → {1, 2} (1 stays). M-RB13.
  - **RB12** a plain band over empty floor clears {1}; a Shift band over
    empty floor leaves {1}. M-RB14.
  - **RB13** a `SelectionController` listener counts one notification
    for a band that changes the selection and none for one that does
    not; `taps` stays empty for a band that starts on the floor and ends
    over table 2 after a tap on 2 (no tap, and no double tap event:
    wire `events` with an `onTableDoubleTap` recorder and an
    `onFloorTap` recorder, both empty). M-RB15, M-RB16.
  - **RB13b** a band, then at once a tap on table 1: selects 1 and
    reports `'1'`. (Review Focus 2.)
  - **RB14** at the tool: Escape mid-band (with `idleKeys: () => false`)
    returns `handled`, ends the band (phase idle), selection unchanged;
    another key mid-band (`KeyDownEvent` for `z`) returns `handled`;
    `cancel(ctx)` mid-band: idle, selection unchanged, the next tap acts.
    M-RB17, M-RB17b.
  - **RB15** `paintOverlay` into a recording canvas during a band from
    screen (900, 120) to (1100, 300): a fill `drawRect` at
    `Rect.fromPoints` of the two, then a stroke `drawRect` (window);
    after moving to (800, 300) a `drawPath` (crossing); idle: nothing
    drawn. (M-RB18 is Task 1's; here **M-RB18b**: the overlay painted
    while idle.)
  Run: `cd packages/jet_cad_floor_plan && flutter test --enable-vmservice test/service/table_band_test.dart` — fails (no band).

- [ ] **Step 4: Implement** — in `table_select_tool.dart`:

  Imports: `dart:math` as `math`; `dart:ui` gains `Rect`.

```dart
enum _Gesture { none, pressed, dragging, panning, banding, spent }
```

  `phase`: `_Gesture.dragging || _Gesture.panning || _Gesture.banding =>
  ToolPhase.dragging`.

  Fields:

```dart
  /// A finger's press that reached a table by the reach only (14t R-11):
  /// under FloorPlanFloorDrag.band its drag is a band (rubber-band R-4).
  bool _reachOnly = false;

  /// The live band's mode (RB-3), from the press to the pointer's latest.
  BandMode _bandMode = BandMode.window;

  final SelectionBandPainter _bandPainter = SelectionBandPainter();
```

  In `onPointerDown`, after `_hit = picker.pick(…)`:

```dart
    // A finger's hit found by the reach alone (RB-2): one more pick, a
    // finger's down only.
    _reachOnly = e.isTouch && _hit != null && picker.pick(e.world) == null;
```

  In `onPointerMove`'s `_Gesture.pressed` case, after `_lastTap = null;`
  and before `final hit = _hit;`:

```dart
        if (_startsBand(e)) {
          _gesture = _Gesture.banding;
          _lastScreen = e.screen;
          _bandMode = bandModeFor(_pressScreen, e.screen);
          notifyListeners();
          return;
        }
```

  and a new case beside `dragging || panning`:

```dart
      case _Gesture.banding:
        _lastScreen = e.screen;
        _bandMode = bandModeFor(_pressScreen, e.screen);
        notifyListeners();
```

  The rule:

```dart
  /// Whether this drag is a band (rubber-band RB-2): from the floor — or,
  /// under `band`, a finger's reach-only press — when the host chose
  /// `band`, or under `pan` with a modifier at the press and no finger.
  bool _startsBand(ToolPointerEvent e) {
    final band = _options.floorDrag == FloorPlanFloorDrag.band;
    if (_hit != null && !(band && _reachOnly)) return false;
    return band || (_toggle && !e.isTouch);
  }
```

  In `onPointerUp`: `case _Gesture.banding: _band(e, ctx);` (before the
  `none || panning || spent` case).

```dart
  /// The band's end (RB-3, RB-4): both screen corners under the camera at
  /// the up, the instances the band passes kept to the picker's
  /// candidates, groups taken by the mode's rule; one `replace`.
  void _band(ToolPointerEvent e, ToolContext ctx) {
    final a = ctx.camera.value
        .screenToWorld(Vector2(_pressScreen.dx, _pressScreen.dy));
    final b = e.world;
    final world = Aabb2.raw(math.min(a.x, b.x), math.min(a.y, b.y),
        math.max(a.x, b.x), math.max(a.y, b.y));
    final keys = _bandKeys(world, bandModeFor(_pressScreen, e.screen), ctx);
    if (_toggle) {
      if (keys.isEmpty) return;
      ctx.selection.replace({...ctx.selection.keys, ...keys});
    } else {
      ctx.selection.replace(keys);
    }
  }

  /// The band's keys (RB-3), ascending by handle. `snapping`, not
  /// `picking`: a locked layer's table reaches the window's group rule
  /// (review V-1); a locked table is never a key.
  List<SelectionKey> _bandKeys(Aabb2 world, BandMode mode, ToolContext ctx) {
    final locked = <Handle, bool>{
      for (final c in picker.candidates) c.table.instance: c.locked
    };
    final passing = <Handle>{};
    ctx.index.forEachInstanceInBand(world, mode, const QueryFilter.snapping(),
        (h) {
      if (locked.containsKey(h)) passing.add(h);
    });
    final lookup = _groupLookup();
    final keys = <Handle>{};
    final groups = <String>{};
    for (final h in passing) {
      final id = lookup == null ? null : _groupByHandle[h];
      if (id != null) {
        groups.add(id);
      } else if (!locked[h]!) {
        keys.add(h);
      }
    }
    for (final id in groups) {
      final members = lookup!.visibleMembers(id);
      final take = switch (mode) {
        BandMode.crossing =>
          members.any((t) => !t.locked && passing.contains(t.handle)),
        BandMode.window => members.every((t) => passing.contains(t.handle)),
      };
      if (take) {
        for (final t in lookup.selectableMembers(id)) {
          keys.add(t.handle);
        }
      }
    }
    return [for (final h in _sorted(keys)) SelectionKey.root(h)];
  }
```

  `onKey` gains, first:

```dart
    // A band takes every key (RB-5): Escape ends it, whatever idleKeys
    // says; no other shortcut lands in its middle.
    if (_gesture == _Gesture.banding) {
      if (event is KeyDownEvent &&
          event.logicalKey == LogicalKeyboardKey.escape) {
        _reset();
        notifyListeners();
      }
      return KeyEventResult.handled;
    }
```

  `_reset()` gains `_reachOnly = false;`. `paintOverlay`:

```dart
  @override
  void paintOverlay(Canvas canvas, ViewportTransform camera, Size viewport,
      PaperPalette paper) {
    if (_gesture != _Gesture.banding) return;
    _bandPainter.paint(
        canvas, Rect.fromPoints(_pressScreen, _lastScreen), _bandMode, paper);
  }
```

  Update the file's header comment: the tool also draws a band (rubber-band
  spec RB-2 to RB-5).

- [ ] **Step 5: Run** — the new file passes; the planner's whole suite
  with `--enable-vmservice` green, unchanged elsewhere.

- [ ] **Step 6: RB16** — `test/invariants/band_allocation_test.dart`, on
  `pick_allocation_test.dart`'s pattern (read it and
  `vm_allocation_meter.dart` first; same skip rule without the VM
  service): a tool mid-band (a rig as in Step 3, or a minimal one with
  one table), `paintOverlay` called 1,000 times into a
  `PictureRecorder`'s canvas with the pointer moving 1 px per frame
  (alternating window and crossing); the meter's counts of `Paint` and
  `_Path`/`Path` (read the meter's class-name convention) are ≤ 2 in
  total over the 1,000 frames. **M-RB19**: build `Paint()` inside
  `SelectionBandPainter.paint` (Task 1's file, applied and reverted only
  for the mutant) — red.

- [ ] **Step 7: Mutants** — M-RB1, M-RB2, M-RB5, M-RB5b, M-RB6, M-RB7,
  M-RB7b, M-RB8, M-RB9, M-RB10, M-RB10b, M-RB11, M-RB12, M-RB13, M-RB14,
  M-RB15, M-RB16, M-RB17, M-RB17b, M-RB18b, M-RB19: each applied, seen
  red, reverted; killers in the report. Definitions where the spec is
  terse: M-RB10 drops `!locked[h]!`; M-RB10b uses
  `QueryFilter.picking()`; M-RB11 adds groups' members as lone tables
  without expansion; M-RB12 uses `any` for window; M-RB13 replaces the
  union with `ctx.selection.toggle(keys)`; M-RB14 swaps the empty rule
  (plain empty returns, modifier empty clears); M-RB15 calls
  `ctx.selection.toggle([k])` per key; M-RB16 routes `banding` to `_tap`
  at the up; M-RB17 gates the Escape on `idleKeys()`; M-RB17b returns
  `ignored` for non-Escape keys mid-band.

- [ ] **Step 8: Commit** — `feat(floor-plan): a band selects tables in
  the selection mode`.

---

### Task 3: The view's option, through real pointers (RB-1)

**Files:**
- Modify: `packages/jet_cad_floor_plan/lib/src/host/floor_plan_view.dart` (`:41-47` the constructor, the field beside `longPress` `:95`, `:698-702` the options record)
- Modify: `packages/jet_cad_floor_plan/lib/jet_cad_floor_plan.dart:30-40` (`FloorPlanFloorDrag` in the `show` list of `floor_plan_types.dart`)
- Test: `packages/jet_cad_floor_plan/test/host/band_view_test.dart`
- Test: `packages/jet_cad_floor_plan/test/host/barrel_test.dart` only if it enumerates the barrel's names (then a named exception: add `FloorPlanFloorDrag`; say so in the report)

**Interfaces:**
- Consumes: Task 2's `FloorPlanFloorDrag`, `ServiceOptions.floorDrag`.
- Produces: `FloorPlanView({…, FloorPlanFloorDrag floorDrag =
  FloorPlanFloorDrag.pan, …})`, `final FloorPlanFloorDrag floorDrag;`
  read at each press.

- [ ] **Step 1: Write the failing tests** — `test/host/band_view_test.dart`,
  on `service_options_test.dart`'s harness pattern (read it; build the
  plan the same way with a group `{'5', '6'}` via
  `controller.setTableGroups`, table 3 locked, table 4 unnumbered), a
  `FloorPlanView` with `floorDrag`, `userCamera`, `shortcuts`,
  `longPress`, `onTableTap`, `onFloorTap`, `onTableContextMenu`
  parameters; `selectedTables` listened to with a counter:
  - **RBV1** (RB3) `band`: a one-finger drag (`TestGesture`, kind touch)
    from the floor over tables 1 and 2 selects `{'1', '2'}`, the camera
    unmoved; a mouse drag does the same; two fingers down on the floor
    and moved together pan (the camera moved) and select nothing; a
    second finger landing mid-band cancels it (selection unchanged), and
    after both lift a tap on table 1 selects it. M-RB3, M-RB3b.
  - **RBV2** (RB4) `band` with `userCamera: false`: the band selects.
    M-RB4.
  - **RBV3** (RB13) `selectedTables` notifies exactly once for a band
    that selects `{'1', '2'}`; no `onTableTap`, no `onFloorTap`.
  - **RBV4** (RB14) under `shortcuts: false`, Escape mid-band (a mouse
    drag held, `sendKeyEvent(LogicalKeyboardKey.escape)`) ends it: the
    up then changes nothing; a secondary click mid-band opens no menu;
    `controller.setMode(FloorPlanMode.design)` mid-band, then back:
    nothing selected. M-RB17 at the view.
  - **RBV5** `floorDrag` flipped from `pan` to `band` by rebuilding the
    view: the next plain drag bands; flipped back mid-band: that band
    finishes as a band. (Review Focus 5.)
  - **RBV6** (RB18) with `controller.setTableFocus({'2'})` (table 1
    veiled) and a status on table 2, a band over 1 and 2 selects both. A
    pin, not a mutant's killer: the tool never sees the focus, so M-RB20
    has no place to be applied; the report says so.
  - **RBV7** (RB19) `longPress: FloorPlanLongPress.contextMenu`, touch,
    `band`: a 600 ms press on table 1 opens the menu for `'1'`; a floor
    drag bands. M-RB21. Also Review Focus 1: a finger 10 px outside
    table 2's box dragged bands; on table 2's top dragged moves it.
  - **RBV8** `pan` (the default): a Shift mouse drag over 1 and 2 adds
    them to a selected 4 (unnumbered: `selectedTables` is `{'1', '2'}`);
    a plain mouse drag pans.
  Run: fails (`floorDrag` is not a parameter).

- [ ] **Step 2: Implement** — the constructor parameter `this.floorDrag
  = FloorPlanFloorDrag.pan` after `longPress`; the field, documented:

```dart
  /// What a one-pointer drag on the empty floor does in the selection
  /// mode (rubber-band spec RB-1): `pan` (the default) pans, and a Shift,
  /// Ctrl or Cmd mouse or stylus drag draws a band that adds to the
  /// selection; `band` draws a band that selects — left to right the
  /// tables wholly inside, right to left every table touched, a group
  /// whole, a locked table never — and the camera pans with two fingers,
  /// the wheel or trackpad, and the middle button. Read at each press.
  final FloorPlanFloorDrag floorDrag;
```

  and `floorDrag: widget.floorDrag` in the options record (replacing
  Task 2's `FloorPlanFloorDrag.pan`). Barrel: add `FloorPlanFloorDrag` to
  the `show` list.

- [ ] **Step 3: Run** — the file passes; the planner's suite green.

- [ ] **Step 4: Mutants** — M-RB3 (the view passes `pan` always), M-RB3b
  (`banding` mapped to `ToolPhase.idle` in Task 2's `phase`), M-RB4,
  M-RB21 (`_startsBand` returns false when
  `_options.longPress == contextMenu`): each red, reverted.

- [ ] **Step 5: Commit** — `feat(floor-plan): FloorPlanView.floorDrag`.

---

### Task 4: The demo, the guide, the CHANGELOG, the specs, STATUS and the exit (RB-7)

**Files:**
- Modify: `apps/restaurant_demo/lib/main.dart` (a `floorBand` bool beside `longPressMenu`, `:403`; `floorDrag:` at `:1210`'s view; a `SwitchListTile` keyed `'floor-band'` after `'long-press-menu'`, `:1461-1466`)
- Modify: `apps/restaurant_demo/lib/demo_strings.dart` (`floorBand` in the base, English, German, Turkish: "Floor drag: select" / "Ziehen auf dem Boden: Auswählen" / "Zeminde sürükle: Seç")
- Modify: `apps/restaurant_demo/test/demo_test.dart` (the switch flips the view's `floorDrag`)
- Modify: `docs/host-guide.md` (§8's option list; a "Selecting with a band" subsection in §7 before "### Table groups"; §10 Touch)
- Modify: `tool/ci/host_probe/lib/main.dart` (every new code block)
- Modify: `CHANGELOG.md` (`## Unreleased`), `STATUS.md`
- Modify: `docs/superpowers/specs/2026-10-09-host-embedding-api-design.md` (O-4), `2026-10-03-selection-mode-design.md` (S3), `2026-10-03-restaurant-embedding-design.md` (D11, D17), `2026-10-03-touch-design.md` (T6)

- [ ] **Step 1: The demo** — the switch, its strings in three languages,
  its test (the `FloorPlanView` found by type has `floorDrag ==
  FloorPlanFloorDrag.band` after the tap, `pan` before). Run the demo's
  `flutter test`, analyze, format.

- [ ] **Step 2: The guide** — the subsection, in the guide's voice:
  `floorDrag: FloorPlanFloorDrag.band` in a `FloorPlanView(...)` block;
  the two triggers; the direction rule; groups whole, locked never,
  unnumbered selected but absent from `selectedTables`; the camera under
  `band` (two fingers, wheel, middle button); a finger near a table:
  tap selects it, drag bands; the modifier read at the press (the
  editor's band reads Shift at the release); **the change under the
  default** (a modifier mouse drag on the floor now bands, it panned
  before 0.7.0). §8 gains a `floorDrag` bullet; §10 Touch gains one
  sentence for `band`. Every block in the host probe; from the repo root
  `dart run tool/ci/check_guide.dart` passes.

- [ ] **Step 3: The CHANGELOG** — `## Unreleased` ("Nothing yet."
  replaced): "**A band selects tables in the selection mode.**
  `FloorPlanView(floorDrag: FloorPlanFloorDrag.band)` makes a one-finger
  or mouse drag on the floor draw a band — left to right the tables
  wholly inside, right to left every table touched; a group whole; a
  locked table never; a plain band replaces the selection, one with
  Shift, Ctrl or Cmd adds — and the camera then pans with two fingers,
  the wheel or trackpad and the middle button. **Changed under the
  default `pan`:** a mouse or stylus drag on the floor with Shift, Ctrl
  or Cmd held now draws a band that adds to the selection; it panned
  before." and, for `jet_cad_2d_flutter`: "`bandModeFor` and
  `SelectionBandPainter`: the selection band's direction rule and look,
  shared by the editor and the selection mode."

- [ ] **Step 4: The specs' notes** — host embedding O-4: "**Taken up**
  (2026-10-13) by the rubber-band spec
  [2026-10-13-rubber-band-selection-design.md](2026-10-13-rubber-band-selection-design.md)."
  Selection-mode S3, restaurant-embedding D11 and D17, touch T6: a dated
  line each, "(2026-10-13) Except under `floorDrag: band` (rubber-band
  spec RB-2)."

- [ ] **Step 5: STATUS** — "In flight": the rubber-band slice implemented
  on `feat/rubber-band`, reviewed, awaiting the human's merge word, then
  release 0.7.0. "Resume here" likewise. "Owed to the human": a look at
  the band (mouse and tablet, light and dark, `pan` with Shift and
  `band`); a native German and Turkish read of the demo's new switch.

- [ ] **Step 6: The exit gate, whole.** Every package and app through its
  gate (the comparison for the engine, render and GPU; `flutter test`,
  analyze and format for the rest, the planner with `--enable-vmservice`),
  `tool/ci` (`dart test`, analyze, format, `check_guide`), the host probe
  (`tool/ci/host_probe.sh file:///<absolute worktree path> <full HEAD
  sha>`) and the four old-host probes (`tool/ci/old_host_probe.sh
  v0.3.0`, `v0.4.0`, `v0.5.1`, `v0.6.0`). Paste each command's last lines
  into the report.

- [ ] **Step 7: Commit** — `docs: rubber-band selection in the guide, the
  CHANGELOG, the specs and STATUS; the demo's switch`.

---

## Mutants per task

| Task | Mutants | Count |
|---|---|---|
| 1 | M-BP1, M-BP2, M-BP3, M-RB18 | 4 |
| 2 | M-RB1, M-RB2, M-RB5, M-RB5b, M-RB6, M-RB7, M-RB7b, M-RB8, M-RB9, M-RB10, M-RB10b, M-RB11, M-RB12, M-RB13, M-RB14, M-RB15, M-RB16, M-RB17, M-RB17b, M-RB18b, M-RB19 | 21 |
| 3 | M-RB3, M-RB3b, M-RB4, M-RB21 (RBV6 pins M-RB20's case) | 4 |
| 4 | — (`check_guide` covers the probe) | 0 |

## Exit gate

- Task 4's step 6 green: every gate, the standing sets exact, the host
  probe and the four old-host probes.
- Every named mutant above seen red and recorded.
- A whole-branch independent review, its fixes applied.
- The ledger archived to
  `docs/superpowers/ledgers/2026-10-13-rubber-band-selection/`.
- **Owed to the human:** a look at the band (mouse and tablet, light and
  dark); the demo switch's German and Turkish read.
- **The merge into `main` happens on the human's word**; release 0.7.0 is
  its own step after it.

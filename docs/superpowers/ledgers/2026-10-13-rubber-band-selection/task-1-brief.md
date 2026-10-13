# Brief: Task 1 of docs/superpowers/plans/2026-10-13-rubber-band-selection.md

Spec: docs/superpowers/specs/2026-10-13-rubber-band-selection-design.md (revision 2, approved)

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


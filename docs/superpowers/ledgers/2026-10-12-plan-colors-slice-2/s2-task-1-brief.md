# Brief: plan colours Slice 2, Task 1

Plan: docs/superpowers/plans/2026-10-12-plan-colors-slice-2.md
Spec: docs/superpowers/specs/2026-10-12-plan-colors-design.md

## Global Constraints

- `CLAUDE.md`'s non-negotiables. **The frame path allocates nothing per
  entity in steady state**: `query_allocation_test` and
  `paint_allocation_test` stay untouched and green; the fill painter's own
  allocation bar (`test/service/table_status_painter_test.dart`) is
  extended to the design mode's mount (Task 3), never loosened.
- **Draw order is ascending handle value**; the fills keep it (they are
  sorted by instance handle, as today).
- **Stored values compare with exact `==`**; geometric decisions use
  `Tolerance`.
- **`jet_cad_2d` is not edited in this slice.** `jet_cad_2d_flutter` is
  edited **only in Task 1** (the page export's underlay).
- **No existing signature, `==`, `hashCode` or `toString` changes**, except
  `FloorPlanTableDetail`'s (Task 2: `color` joins all four),
  `FloorPlanTheme`'s (Task 3: `tableColorOpacity` joins every field list)
  and `TableStatusPainter`'s constructor (Task 3: a new optional
  parameter). Every new parameter is named and optional with today's
  behaviour as its default. **Existing tests pass unedited**, with these
  named exceptions only:
  - **Task 3:** `test/host/floor_plan_theme_test.dart` — the tests that
    enumerate every field (`copyWith`, `merge`, `lerp`, `==`, the debug
    map, the range check) gain `tableColorOpacity`; any test in
    `test/service/table_status_painter_test.dart` that pins "no survey
    when no status is set" (the `:185` skip, removed by PC-5) is re-pinned
    to the new rule.
  - **Task 5:** `test/colors/color_picker_test.dart` CP1's Wall-tool leg
    (the vacuous one, Slice 1's ledger) is rewritten to the pinned form.
  Any other test that has to change is a finding for the task's report.
- **The standing sets stay exactly as they are**
  (`tool/ci/standing_failures.txt`, `standing_skips.txt`), compared from
  the repo root with `dart run tool/ci/expect_failures.dart --package
  packages/<pkg> --root packages/<pkg> <run.json>` (runs made with
  `--file-reporter json:<run.json>`). On macOS the render package's
  `text_lod_ladder` rungs 1–2 pass: the recorded standing difference, not a
  finding. The engine's `dart test` exits 1 for its two fingerprints while
  `expect_failures` exits 0.
- **Every task ends green** in every package it touches and every package
  that reads what it changed. The planner runs with `flutter test
  --enable-vmservice`. `flutter analyze` / `dart analyze`, and `dart format
  --output=none --set-exit-if-changed .`, clean.
- **Fixtures** (CLAUDE.md's testing bar; the spec's testing section): every
  drawing test places a table **turned and mirrored**, away from the
  origin, whose top is **off-centre in its definition and asymmetric**
  (a circle or a centred rectangle is invariant under a turn and a mirror
  about its centre), beside a **circular** top that is also off-centre;
  status, group status and colour on **different tables of one plan**; one
  coloured table inside a coloured room; one coloured table **unnumbered**;
  one on a **locked** layer; one on a **hidden** layer. Hues `teal` and
  `purple`, and the unknown name `"magenta"`. A non-default
  `tableColorOpacity` (0.6) beside a different `statusFillOpacity` (0.8)
  wherever an opacity is asserted.
- **Each named mutant is applied, seen red and reverted**, its killer named
  in the report.
- **Never `git checkout` a file to revert it**; copy it aside or `git show
  HEAD:path > path`. **Never commit an `analysis_options.yaml`.** **Never
  synthesize test output.** Code, comments and commits in English; commit
  trailers name the model that wrote the commit.
- No component type and no handle crosses the host barrel
  (`FloorPlanTableColor` stays internal, as `FloorPlanTableData` does).
- **The worktree guard:** this session's shell refuses `$VAR` in argument
  position, `bash <script>` and git-mixing pipelines inside the worktree;
  use plain commands and literal paths/SHAs.


## Review Focus

The situations a person meets that the tasks' own assertions would
otherwise not reach, each pinned by a test in the task named:

1. **A status arriving and leaving on a coloured table** in the selection
   mode: the table shows its colour, then the status (no colour visible),
   then its colour again when the host clears the status — with no
   document change in between. Task 3, TF6.
2. **Delete then Undo of a coloured table** in the editor: the colour is
   back on screen at the next frame and in `tableDetails`, and
   `designChanges` reports the table re-added with its colour. Task 2,
   TC8; Task 3, TF8.
3. **`controller.exportPlan` with no view mounted**: coloured tables are in
   the PNG at 0.35 (the default), and at a given `tableColorOpacity`.
   Task 4, EX3.
4. **A coloured table on a locked layer**: it is filled on screen and in
   the export, the API recolours it, and the editor cannot select it (the
   picker never reaches it). Task 2, TC5; Task 3, TF4; Task 4, EX2.
5. **A theme switch light ↔ dark while the editor is up**: the table fills
   re-tone with no document change, matching a room tint of the same hue.
   Task 3, TF7.

---


---

### Task 1: The page export's underlay (PC-7, render package)

**Files:**
- Create: `packages/jet_cad_2d_flutter/lib/src/export/page_underlay.dart`
- Modify: `packages/jet_cad_2d_flutter/lib/src/export/page_export.dart` (`exportPagePdf` `:34-77`, `exportPagePng` `:104-150`)
- Modify: `packages/jet_cad_2d_flutter/lib/jet_cad_2d_flutter.dart` (export the new file)
- Create: `packages/jet_cad_2d_flutter/test/export/page_underlay_test.dart`

**Interfaces:**
- Produces (public, exported from `package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart`):

```dart
/// A fill under a page export's drawing (plan colours spec PC-7): a closed
/// shape in its own space, placed in world by [placement], in [argb]
/// (0xAARRGGBB, drawn as given).
@immutable
sealed class PageUnderlayFill {
  const PageUnderlayFill({required this.placement, required this.argb});
  final Transform2 placement;
  final int argb;
}

/// A closed polygon: [xy] interleaved x, y with the first point repeated as
/// the last; [count] the point count including that duplicate;
/// [triangles] its triangulation (`triangulateSimplePolygon`), never empty.
final class PageUnderlayPolygon extends PageUnderlayFill {
  PageUnderlayPolygon(
      {required super.placement, required super.argb,
       required this.xy, required this.count, required this.triangles});
  final Float64List xy;
  final int count;
  final Int32List triangles;
}

/// A circle of radius [r] about ([cx], [cy]).
final class PageUnderlayCircle extends PageUnderlayFill {
  const PageUnderlayCircle(
      {required super.placement, required super.argb,
       required this.cx, required this.cy, required this.r});
  final double cx, cy, r;
}

/// Draws [fills] in order through [sink] under [camera]: each under the
/// residual `camera.worldToScreenMatrix · placement`, as `DraftPainter`
/// draws a leaf.
void drawPageUnderlay(DrawSink sink, ViewportTransform camera,
    List<PageUnderlayFill> fills);
```

  `exportPagePdf({..., List<PageUnderlayFill> underlay = const []})` and
  `exportPagePng({..., List<PageUnderlayFill> underlay = const []})`.

- [ ] **Step 1: Write the failing tests** in
  `test/export/page_underlay_test.dart`. Read `test/export/export_png_test.dart`
  (`:40-70`) for how a PNG is decoded to RGBA and a pixel read, and
  `test/export/pdf_content_test.dart` / `lib/src/export/testing/pdf_content.dart`
  for `PdfContent.parse(bytes, inflate: zlib.decode)` and its `paths`
  (`fills`, `subpaths[].vertices`, `state.fillRgb`, `state.ctm`). Fixture:
  an empty `DraftDocument` with a `PageComponent` (A4 landscape, 1:50,
  white) and one LINE drawn across the polygon (so draw order is visible);
  the placement `T = translation(4000.5, 2500.25) · rotation(0.7) ·
  scale(1, -1)` (turned and mirrored); a polygon off-centre and
  asymmetric in its own space — the L-shape `(200,100) (900,100)
  (900,300) (450,300) (450,700) (200,700)` closed — and a circle
  `(600.5, -350.25, r 180)`; `argb` `0x9900897B` (teal at alpha 153) and
  `0x998E24AA` (purple). Tests:
  - **PU1** PNG: the pixel at the image of the L's local point `(300, 600)`
    (inside its tall arm, away from the line; compute it forward:
    `T.transformPoint`, then the page camera's `worldToScreenMatrix` —
    `pageCamera(page, dpi/25.4).camera`) is teal over white, per channel
    `round(153/255·s + (1−153/255)·255)` within ±2; the pixel at the image
    of `(800, 600)` (outside the L, inside its bounding box) is white; the
    pixel at the image of the circle's centre is purple over white; a
    pixel on the LINE where it crosses the L is the line's black (the
    underlay is under the drawing).
  - **PU2** PDF: `PdfContent.parse(...)`'s fill paths: the first two
    fills precede every stroke (`operatorIndex`), the first's vertices
    mapped through its `state.ctm` equal the PNG's device points of the
    L's six corners at 72/25.4 per mm (`closeTo` 1e-6 pt) in order, its
    `fillRgb` is teal's `[0, 0x89/255, 0x7B/255]`; the circle's path has
    cubic segments (`isCubic`), not a polygon.
  - **PU3** an empty `underlay` writes exactly the bytes the export wrote
    without the parameter (PDF with `compress: false`; PNG), for the same
    document.
  - **PU4** `PageUnderlayPolygon` with empty `triangles`, or `count * 2 >
    xy.length`, throws `ArgumentError` at construction.
  - **PU5** `drawPageUnderlay` on a `RecordingDrawSink` (from
    `package:jet_cad_2d_flutter/...` — read how `draft_painter_order_test`
    records ops) emits, per fill, `beginResidual(camera ·
    placement)`, then `fillPolygon(xy, count, triangles, style)` or
    `fillCircle(cx, cy, r, style)` with `style.argb == argb`, then
    `endResidual`, in the fills' order.

- [ ] **Step 2: Run them; see them fail** (`flutter test
  test/export/page_underlay_test.dart` in `packages/jet_cad_2d_flutter`):
  compile errors, the names do not exist.

- [ ] **Step 3: Implement `page_underlay.dart`** with the interface above.
  `drawPageUnderlay`:

```dart
void drawPageUnderlay(DrawSink sink, ViewportTransform camera,
    List<PageUnderlayFill> fills) {
  final world = camera.worldToScreenMatrix;
  for (final f in fills) {
    final style = ResolvedStyle(
        argb: f.argb,
        lineweightHundredths: 0,
        linetype: ReservedHandles.continuousLinetype,
        linetypeScale: 1);
    sink.beginResidual(world.multiply(f.placement));
    switch (f) {
      case PageUnderlayPolygon(:final xy, :final count, :final triangles):
        sink.fillPolygon(xy, count, triangles, style);
      case PageUnderlayCircle(:final cx, :final cy, :final r):
        sink.fillCircle(cx, cy, r, style);
    }
    sink.endResidual();
  }
}
```

  `PageUnderlayPolygon`'s constructor throws `ArgumentError` for empty
  `triangles` or `count < 4` or `count * 2 > xy.length`. In
  `page_export.dart`, after the ground (PNG: after `drawPaint`; PDF: before
  `DraftPainter(...).paint`), inside `_withExportIndex`'s callback, call
  `drawPageUnderlay(sink, camera.camera, underlay)` when `underlay` is not
  empty, then the painter. Each function's doc gains a bullet: "[underlay]
  is drawn after the ground and before the document (plan colours spec
  PC-7); empty, the bytes are today's."

- [ ] **Step 4: Run; see them pass**; then the render package through the
  standing comparison, `flutter analyze`, format; `jet_cad_2d_gpu` and
  `jet_cad_floor_plan` (`--enable-vmservice`) green (they read the export).

- [ ] **Step 5: The mutants:**
  - **M-C7a** — the placement ignored (`sink.beginResidual(world)`).
    Killer: PU1, PU2, PU5.
  - **M-C7b** — the linear part ignored (`world.multiply(
    Transform2.translation(f.placement.e, f.placement.f))`). Killer: PU1
    (the L's arm is mirrored/turned away), PU2.
  - **M-PU-a** — the underlay drawn after the document. Killer: PU1's line
    pixel; PU2's operator order.
  - **M-PU-b** — the circle tessellated (`fillPolygon` of 64 points).
    Killer: PU2's `isCubic`.
  - **M-PU-c** — an empty underlay still touches the sink (`beginResidual`
    and `endResidual` always). Killer: PU3.

- [ ] **Step 6: Commit** — `feat(2d_flutter): a page export's underlay of
  fills under the drawing` (plan colours spec PC-7).

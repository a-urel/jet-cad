# Export and print (13) — design

**Date:** 2026-10-01. **Status:** design, **revision 1**, not yet reviewed.
**Sub-project:** `roadmap/13-export-and-print.md`. **Size:** M, one plan
(the human's decision 9), about nine tasks.
**Branch:** `spec-13/export-and-print`, cut from `main` at `a0a1920`.
**Depends on:** 04 (the page), 12a (the file flows and the command table).
**Brainstormed with the human on 2026-10-01**, on `main`, after a survey of
the page model, the painter, the sinks, the differential oracle, the golden
suite, the app's file flows and the `pdf` and `printing` packages (the facts
below are from `main` at `a0a1920` and from `pdf` 3.13.1 as published).

**Inputs read:** `CLAUDE.md`; `STATUS.md`; `roadmap/13-export-and-print.md`;
`packages/jet_cad_2d/lib/src/document/{page_component,page_geometry,
style_resolver,draft_document}.dart`;
`packages/jet_cad_2d_flutter/lib/src/{draft_painter,draw_sink,
canvas_draw_sink,reference_walk,viewport_transform,page_fit,
page_chrome_painter,symbol_thumbnails,flutter_text_measurer,tile_cache,
draft_canvas}.dart`; `test/golden/fonts/README.md`;
`apps/floor_planner/lib/{main,document_host,document_files,
document_files_io,document_files_web,document_toolbar,shell_commands}.dart`,
`lib/parametric/separator.dart`; `apps/floor_planner/pubspec.yaml`,
`macos/Runner/*.entitlements`; `pdf` 3.13.1's `lib/src/pdf/{document,
graphics}.dart`; pub.dev's metadata for `pdf` 3.13.1 and `printing` 5.15.1.

## Decisions the human made on 2026-10-01

1. **Vector PDF**, through a new `DrawSink` (`PdfDrawSink`) that emits PDF
   operators. Not a rasterised PDF.
2. **Text in the PDF is an embedded Roboto**, the same file the screen uses.
3. **The source of that font is the file already in the repository**,
   `packages/jet_cad_2d_flutter/test/golden/fonts/Roboto-Regular.ttf`
   (Roboto 2.137, Apache 2.0, its licence beside it, SHA-256 recorded): no
   new import. Copied byte-identical into the app.
4. **One page, at its scale.** The page's world rectangle maps one-to-one to
   the sheet; a 1 m line at 1:50 is 20 mm on paper. Whatever lies outside
   the sheet is clipped. The screen's camera plays no part.
5. **Only the drawing.** No grid, rulers, sheet edge, page breaks, selection
   or paper fill (a PNG gets a white ground). No title block in this
   version.
6. **PNG resolution is a DPI choice of 96, 150 or 300, default 150**, and the
   PNG carries it in its `pHYs` chunk.
7. **The system print dialog, through the `printing` package**, printing the
   same vector PDF.
8. **Verification is two-layered and differential**: the painter against
   `referenceWalk` at the page camera; the PDF's own content stream parsed
   back and compared to the expected points and widths in pt; PNG pixels at
   known positions.
9. **The code lives in `jet_cad_2d_flutter` and the app**: the sink and the
   export functions in the render package (which gains `pdf`), the dialog,
   saving and printing in the app (which gains `printing`). The engine is
   untouched.
10. **Two commands, `Export…` (Cmd/Ctrl+E) and `Print…` (Cmd/Ctrl+P)**;
    Export opens a small dialog (format PDF / PNG; DPI when PNG), then the
    platform's save; Print opens the system dialog.
11. **What must not plot is passed to the export as a set of owners**
    (`omitOwners`): a leaf whose owner is in it is not drawn. The app puts
    every `SeparatorParams` group in it. No plot flag, no engine or codec
    change.
12. **One plan.**

## What this delivers

- `Export…`: a PDF of the page (vector, embedded font, the page's paper
  size and orientation, true scale, true lineweights) or a PNG of it at
  96 / 150 / 300 dpi, saved through the macOS save panel or downloaded on
  the web.
- `Print…`: the same PDF handed to the system print dialog (macOS) or the
  browser's (web).
- The app's text drawn in the bundled Roboto on every platform, so the
  screen, the text golden and the PDF use one font.

## Non-goals

- DXF export (its own sub-project, roadmap 13's trap); several pages or
  tiling by `pageBreaks`; a chosen window; fit-to-page; a title block or
  sheet border; a plot flag on layers or entities; PDF/A; fonts other than
  the one Roboto (every text style plots in it, R-3); export of a document
  without a page (the commands are disabled, D9); a print preview of our
  own (the system's is the preview); remembering the format or DPI across
  app launches.

## Facts established (verified on `main` at `a0a1920`)

- **F-1. The page.** `PageComponent` (`page_component.dart:75`) holds the
  portrait sheet `widthMm` × `heightMm`, `orientation`
  (`effectiveWidthMm/HeightMm` swap for landscape), `scaleDenominator`,
  `originX/Y` (the sheet's lower-left corner in world), `background`,
  `gridVisible`, `pageBreaks`. `sheetWorldRect(page)`
  (`page_geometry.dart:7`) is `originX..originX + effW·den`,
  `originY..originY + effH·den`. A document may have **no** page
  (`main.dart:497-502` fits extents then).
- **F-2. The painter.** `DraftPainter.paint(sink, camera, viewport)`
  (`draft_painter.dart:329`) draws in the camera's screen space (y down);
  every primitive is either in screen space or under a residual
  `beginResidual(residual)` that maps its local coordinates to screen
  space. It needs no widget. Its `minTextCapPixels` (default 3.0) culls a
  text whose cap height on screen is below it (`:944`); `0.0` disables
  level of detail.
- **F-3. The sinks.** `DrawSink` (`draw_sink.dart:17`) has nine drawing
  methods plus `shadesDashes`. `CanvasDrawSink.shadesDashes` is false
  (`canvas_draw_sink.dart:86`), so the painter cuts dashes into spans
  itself. Stroke width is `lineweightHundredths / 100 · pixelsPerPaperMm ·
  lineweightScale`, divided by the residual's scale magnitude; 0 is a
  hairline (`:263-270`). Fills are filled paths, non-zero, one `Paint`
  reused. `point` draws a screen-space square. `text` lifts by the
  paragraph's `alphabeticBaseline` and flips y, because the residual maps
  **glyph space** (y up, origin on the baseline, size
  `kNominalTextPixels`) to screen (`:218-241`).
- **F-4. The oracle.** `referenceWalk(doc, sink, camera, viewport,
  resolver, {minTextCapPixels})` (`reference_walk.dart:31`) walks the tree
  from the root with no `SpatialIndex`; `RecordingDrawSink` records
  `DrawOp`s; `test/support/sink_comparison.dart` compares two op lists;
  `test/differential_test.dart` runs them at screen cameras.
- **F-5. Lineweight is paper-based** (no camera term), as roadmap 13 says.
  `kLogicalPixelsPerMm = 96 / 25.4` (`draft_canvas.dart:22`).
- **F-6. The thumbnail recipe** (`symbol_thumbnails.dart:105-140`):
  `DocumentStyleResolver(doc, foreground:)`, `SpatialIndex(doc)` disposed
  in `finally`, `PictureRecorder`, `paint`, `flush`, `Picture.toImage`.
  Under `testWidgets`, `toImage` needs `tester.runAsync`.
- **F-7. Foreground.** `DocumentStyleResolver.foreground` defaults to white;
  ACI 7 and BYBLOCK-under-default resolve to it; the shell passes
  `foregroundFor(page.background)` (`main.dart:258`). On a dark page the
  screen's foreground is white.
- **F-8. Separators.** A separator is a parametric group whose handle
  carries `SeparatorParams` and whose one generated leaf is a dashed
  polyline (`separator.dart:88-100`); `entities.ownerAt(slot)` names the
  group. `liveObjectsOf<SeparatorParams>(doc)` lists them.
- **F-9. The tile cache** is built only by `DraftCanvas`
  (`draft_canvas.dart:380`); a painter called directly never meets it.
- **F-10. The golden suite**: 5 files under `test/golden/`, run with
  `flutter test --tags golden`. `text_ladder_golden_test.dart` loads the
  vendored Roboto under the family `Roboto`, which is what the Standard
  text style names (`draft_document.dart:143`). Outside that test,
  `flutter_test` draws text in Ahem.
- **F-11. The vendored font** (`test/golden/fonts/`): Roboto 2.137, 171,676
  bytes, SHA-256 `79e85140…16d95` (README), Apache 2.0 with
  `Roboto_LICENSE.txt` beside it; its `cmap` covers ş ğ İ ı Ç Ö Ü ç ö ü
  ² × ° (checked with fontTools on 2026-10-01). The app bundles **no**
  font today; `fontFamily: 'Roboto'` falls back to a platform font on
  macOS and web.
- **F-12. File flows.** `DocumentFiles` (`document_files.dart`) is
  `.jetplan`-specific: `saveLocation(suggestedName)` offers only
  `kJetplanTypeGroup`, the web `write` makes an `application/json` blob
  (`document_files_web.dart:66`). Tests inject a fake.
- **F-13. Commands.** `DocumentHost.fileCommands` (`document_host.dart:247`)
  is a list of `ShellCommand(id, label, icon, shortcuts, enabled, run)`
  shown by `DocumentToolbar` as icon buttons; each runs as a flow under
  the host's busy flag, after `_settlePendingInput`. Cmd/Ctrl+E and
  Cmd/Ctrl+P are free (bare `P` is a tool letter, `main.dart:360`).
- **F-14. macOS sandbox.** Both entitlement files enable the app sandbox
  and `files.user-selected.read-write`; neither has
  `com.apple.security.print`.
- **F-15. `pdf` 3.13.1** (pure Dart, Apache 2.0, `sdk >=3.12.0`):
  `PdfDocument({compress = true, …})`; `PdfGraphics` has `moveTo`,
  `lineTo`, `curveTo`, `closePath`, `strokePath`, `fillPath`,
  `setTransform`, `saveContext`/`restoreContext`, `setLineWidth`,
  `setLineCap`, `setLineJoin`, `setStrokeColor`/`setFillColor`,
  `setGraphicState` (opacity), `drawString(font, size, s, x, y, {scale,
  …})`. **The trailer's `/ID` is SHA-256 of `DateTime.now()` and 32
  secure-random bytes** (`document.dart:180-193`): two exports of one
  drawing differ in their bytes.
- **F-16. `printing` 5.15.1** (Apache 2.0, `sdk >=3.12.0`, **`flutter
  >=3.41.0`**) depends on `pdf`, `http`, `image`, `pdf_widget_wrapper`,
  `web`; `Printing.layoutPdf(onLayout:, name:)` opens the system dialog on
  macOS and the browser's on the web. The app's pubspec says `flutter:
  ">=3.38.0"`; this container has Flutter 3.47.2 (Dart 3.13.2).

## Decisions

### D1 — Where the pieces live

- `packages/jet_cad_2d_flutter/lib/src/export/`
  - `page_camera.dart`: `PageCamera` and `pageCamera(page, unitsPerPaperMm)`
    (D2).
  - `pdf_draw_sink.dart`: `PdfDrawSink` (D3).
  - `page_export.dart`: `exportPagePdf`, `exportPagePng`, `ExportDpi`
    (D4, D5).
  - All three exported from `jet_cad_2d_flutter.dart`.
- `DraftPainter` and `referenceWalk` gain `omitOwners` (D6).
- `apps/floor_planner/lib/export/`
  - `export_dialog.dart`: the format / DPI dialog (D8).
  - `export_flow.dart`: the two flows and the `PagePrinter` seam (D8, D9).
- `apps/floor_planner/assets/fonts/`: the font, its licence and a README
  (D7).
- `document_files*.dart` generalised to a file kind (D8).
- Dependencies: `pdf` in the render package; `printing` in the app. The
  plan pins the newest versions this workspace resolves (at the time of
  writing `pdf ^3.13.1`, `printing ^5.15.1`), records their licences, and
  raises the app's `flutter` bound to what `printing` requires (R-4).

### D2 — The page camera

For a page `p` and a unit `u` per paper millimetre (`72 / 25.4` pt for the
PDF, `dpi / 25.4` px for the PNG), with `S = sheetWorldRect(p)` and
`k = u / p.scaleDenominator`:

- `matrix`: `x' = (x − S.minX)·k`, `y' = (S.maxY − y)·k` — a
  `ViewportTransform` whose screen is the sheet, y down, no margin.
- `size`: `Size(effW·u, effH·u)` (unrounded).
- `pixelsPerPaperMm = u`.

`pageCamera` reads nothing but the page: no camera, no viewport, no
extents. The painter is built with `minTextCapPixels: 0.0` — level of
detail is a screen economy, and a 2.5 mm label at 1:100 has a cap height
of 0.07 pt, which LOD would cull from a deliverable.

### D3 — `PdfDrawSink`

A `DrawSink` over one `PdfGraphics` page, in the painter's screen space
(pt, y down). Per op:

- **Page set-up**, once: `cm [1 0 0 −1 0 H]` with `H` the page height in pt,
  so screen space is the PDF's user space; `J 0` (butt cap), `j 0` (miter
  join) — `Paint`'s defaults, which `CanvasDrawSink` uses.
- **`beginResidual` / `endResidual`**: `q` and `cm residual`, deferred to the
  first primitive under it as `CanvasDrawSink` defers its `save`
  (`canvas_draw_sink.dart:113-120`); `Q` only if pushed.
- **Stroke width**: `lineweightHundredths / 100 · u` divided by the
  residual's scale magnitude, the same formula as `CanvasDrawSink` (F-3);
  0 writes `0 w`, PDF's thinnest line. No camera term (roadmap trap).
- **`polyline`**: `m`, `l`…, `h` when closed, `S`.
- **`circle`** / **`arc`**: cubic Béziers, at most 90° per segment, with
  the standard `4/3·tan(θ/4)` handle; an arc's angles are the local frame's
  (point = centre + r·(cos θ, sin θ), the sweep's sign kept), exactly what
  `Canvas.drawArc` draws in the same frame. A full circle is four
  segments.
- **`fillPolygon`** / **`fillCircle`**: the same path, `f` (non-zero).
- **`point`**: the screen-space square `CanvasDrawSink.point` draws, outside
  any residual.
- **Colour**: `RG` / `rg` from the ARGB's RGB; an alpha below 255 sets an
  `ExtGState` with `CA` and `ca` = alpha / 255, one object per distinct
  alpha, reused.
- **`text`**: under the residual, which maps glyph space (y up, baseline
  origin) to screen; the page's y flip cancels the camera's, so the glyphs
  stand upright with no further flip: `BT /F size Tf Tz 0 0 Td (…) Tj ET`,
  `size = kNominalTextPixels`, the fill colour the entity's. **`Tz`** is
  `100 · w_flutter / w_pdf`, where `w_flutter` is the advance the painter
  laid the box out with (`FlutterTextMeasurer`, the same record) and
  `w_pdf` the string's advance in the embedded font at `size`: the PDF's
  string fills the box the painter, the picker and `entityBounds` agree on.
  The font is one `PdfTtfFont` built from the bytes the caller passes
  (D4), whatever the style's `fontFamily` (R-3).
- **`shadesDashes`** is false (the painter cuts dashes, as for
  `CanvasDrawSink`); `beginDash` / `endDash` throw.

### D4 — `exportPagePdf`

```dart
Future<Uint8List> exportPagePdf({
  required DraftDocument document,
  required PageComponent page,
  required Uint8List fontBytes,
  Set<Handle> omitOwners = const {},
  @visibleForTesting bool compress = true,
});
```

One page of the effective paper size in pt. Builds a `SpatialIndex`
(disposed in `finally`), a `DocumentStyleResolver(document, foreground:
0x000000)` — **the paper is white whatever `page.background` is** (F-7) —
a `DraftPainter(minTextCapPixels: 0.0, omitOwners:)`, the page camera at
`u = 72 / 25.4`, and a `PdfDrawSink`; paints; returns `save()`'s bytes. It
reads the document and writes nothing to it. No `DraftCanvas`, no
`TileCache`, no `VerticesDrawSink` (D10).

### D5 — `exportPagePng`

```dart
enum ExportDpi { d96, d150, d300 }  // .value: 96, 150, 300

Future<Uint8List> exportPagePng({
  required DraftDocument document,
  required PageComponent page,
  ExportDpi dpi = ExportDpi.d150,
  Set<Handle> omitOwners = const {},
});
```

- Pixel size: `round(effW / 25.4 · dpi)` × `round(effH / 25.4 · dpi)`
  (A4 landscape at 150 dpi: 1754 × 1240).
- The camera at `u = dpi / 25.4`, unrounded: the last column is a part
  pixel at most.
- White ground (`0xFFFFFFFF`) filled first, then the drawing through a
  **`CanvasDrawSink`** (`pixelsPerPaperMm: u`, its own
  `FlutterTextMeasurer`), resolver and painter as D4, `Picture.toImage`,
  `toByteData(format: png)`.
- A `pHYs` chunk inserted after `IHDR`: pixels per metre
  `round(dpi / 0.0254)` on both axes, unit 1, CRC-32 computed.
- Text is drawn by Flutter in whatever font the `Roboto` family resolves
  to in the running app — the bundled one (D7).

### D6 — `omitOwners`

`DraftPainter` gains a constructor parameter `Set<Handle> omitOwners =
const {}`. A leaf is skipped before anything is resolved for it when
`omitOwners.isNotEmpty && omitOwners.contains(entities.ownerAt(slot))`, at
the root stream and inside containers alike. On the screen the set is the
empty constant: one `isNotEmpty` per leaf, no allocation; the two
allocation invariant tests stay untouched and green.

`referenceWalk` gains the same parameter and honours it **by its own
route**: it does not descend into a tree node whose handle is in the set
(the walk reaches leaves through `leavesByOwner`, so it never sees them).
Two routes, one meaning: a test where they disagree is red.

The app's set: `liveObjectsOf<SeparatorParams>(document)` at the moment of
export.

### D7 — The font

- `packages/jet_cad_2d_flutter/test/golden/fonts/Roboto-Regular.ttf` copied
  byte-identical to `apps/floor_planner/assets/fonts/Roboto-Regular.ttf`,
  with `Roboto_LICENSE.txt` copied unmodified and a `README.md` giving the
  source (that file, which came from Flutter 3.27.3's `material_fonts`),
  the SHA-256 and the licence. A test asserts the two files' bytes are
  equal and the SHA-256 is the recorded one.
- `pubspec.yaml`: `fonts: - family: Roboto, fonts: - asset:
  assets/fonts/Roboto-Regular.ttf`. The screen's text now draws in it on
  macOS and web (look item L-1).
- `LicenseRegistry.addLicense` registers the Apache 2.0 text under
  `Roboto`, so it reaches Flutter's licence page.
- The flows read the bytes once per app with `rootBundle.load` and pass
  them to `exportPagePdf`.

### D8 — `Export…`

- A `ShellCommand(id: 'export', label: 'Export…', icon:
  Icons.ios_share_outlined, shortcuts: Cmd/Ctrl+E)` after `Save As…` in
  `fileCommands`, a flow under busy, after `_settlePendingInput`.
- **Enabled** while not busy **and** the document has a page.
- The dialog: a `SegmentedButton` PDF | PNG; when PNG, a second one
  96 | 150 | 300 dpi; `Export` and `Cancel`. It opens on the last choice
  made in this app session (PDF, 150 dpi at first). `Esc` cancels.
- Then `DocumentFiles.saveLocation` with the suggested name `<document
  name>.pdf` or `.png` (`Untitled` when none) and the file kind's type
  group; then `write`. A cancel at either step writes nothing.
- `DocumentFiles` gains a `FileKind` (`jetplan`, `pdf`, `png`) with its
  extension, type-group label and MIME type: `saveLocation(name, {kind =
  FileKind.jetplan})`, `write(location, name, bytes, {kind =
  FileKind.jetplan})`; the web blob takes the kind's MIME type. Existing
  callers are unchanged by the defaults.
- A failure (a throw from the export or the write) is reported the way a
  failed save is today.

### D9 — `Print…`

- `ShellCommand(id: 'print', label: 'Print…', icon: Icons.print_outlined,
  shortcuts: Cmd/Ctrl+P)`, after `Export…`; enabled as D8.
- Runs `exportPagePdf` once and hands those bytes to a `PagePrinter`
  (`Future<void> print(Uint8List pdf, String name)`); the production one
  calls `Printing.layoutPdf(onLayout: (_) async => pdf, name:)`, ignoring
  the format the dialog offers (the sheet is the page's). Tests inject a
  fake.
- Both entitlement files gain `com.apple.security.print`.

### D10 — What the export is not allowed to use

The export path uses no `VerticesDrawSink` (whose `drawVertices` ignores
`isAntiAlias`, roadmap 13 decision 1) and no `TileCache` (decision 2). The
PNG draws through `CanvasDrawSink`, the PDF through `PdfDrawSink`. Both are
asserted (Testing, T-5 and T-11).

### D11 — Changes to roadmap 13

- Decision 1, "export uses `CanvasDrawSink`", becomes: the PNG uses
  `CanvasDrawSink`, the PDF `PdfDrawSink`; neither uses `VerticesDrawSink`.
- Decision 4: separators are omitted by D6's set; no plot flag.
- Open questions answered by the human's decisions 1–12.

## Architecture

### Files

| File | Change |
|---|---|
| `packages/jet_cad_2d_flutter/lib/src/export/page_camera.dart` | new |
| `packages/jet_cad_2d_flutter/lib/src/export/pdf_draw_sink.dart` | new |
| `packages/jet_cad_2d_flutter/lib/src/export/page_export.dart` | new |
| `packages/jet_cad_2d_flutter/lib/src/draft_painter.dart` | `omitOwners` |
| `packages/jet_cad_2d_flutter/lib/src/reference_walk.dart` | `omitOwners` |
| `packages/jet_cad_2d_flutter/lib/jet_cad_2d_flutter.dart` | exports |
| `packages/jet_cad_2d_flutter/pubspec.yaml` | `pdf` |
| `packages/jet_cad_2d_flutter/test/support/pdf_content.dart` | new: the test-side content-stream reader |
| `apps/floor_planner/lib/export/{export_dialog,export_flow}.dart` | new |
| `apps/floor_planner/lib/document_files*.dart` | `FileKind` |
| `apps/floor_planner/lib/document_host.dart` | two commands |
| `apps/floor_planner/lib/main.dart` | font bytes, licence |
| `apps/floor_planner/assets/fonts/*` | new |
| `apps/floor_planner/pubspec.yaml` | `printing`, font, `flutter` bound |
| `apps/floor_planner/macos/Runner/*.entitlements` | print |

The engine (`packages/jet_cad_2d`) is not touched.

### Invariants

- **I-1.** The exported drawing is the page: nothing the screen camera
  holds reaches it.
- **I-2.** Lineweight in the output is `lineweight mm` on paper, at any page
  scale and any screen zoom.
- **I-3.** Export reads the document and never writes it: the codec's bytes
  and the dispatcher's `stateId` are equal before and after.
- **I-4.** A leaf whose owner is in `omitOwners` is in neither output; every
  other leaf the page meets is in both.
- **I-5.** The screen path is unchanged: no golden PNG moves, no allocation
  invariant is edited, the default `omitOwners` is the empty constant.

## Testing

The fixture, used throughout unless a test says otherwise (the degenerate
fixture is the failure mode): a page **A4 landscape at 1:50 with
`originX = 3,000`, `originY = −1,500`**, `background` dark grey
(`0xFF303030`, so the screen's foreground is white); on it a line, a closed
polyline, a dashed polyline, an arc of sweep −110° and a circle, a filled
polygon with alpha 0x80, a text "Yatak Odası" 250 mm high, an instance
**rotated 30°, scaled (1.5, −0.75)**, with **colour and lineweight
overrides** (red, 0.70 mm) over a definition whose `basePoint` is not the
origin, an ACI 7 line, a separator group, and one line wholly outside the
sheet.

- **T-1. The page camera.** Sheet corners map to `(0, 0)`, `(W, 0)`,
  `(W, H)`, `(0, H)` within `Tolerance`; at 1:50 and 1:100, portrait and
  landscape; a 1,000 mm world segment is `1000 / den · u` long.
- **T-2. Differential at the page camera.** The painter and
  `referenceWalk`, both with `omitOwners = {separator}` and
  `minTextCapPixels: 0`, into `RecordingDrawSink`, compared by
  `sink_comparison.dart`. Both lists contain the instance's leaves and the
  text and contain no separator op and nothing from the outside line.
- **T-3. `PdfDrawSink` geometry.** Ops recorded at the page camera replayed
  into a `PdfDrawSink`, `compress: false`; the test reader parses the
  content stream (`q Q cm m l c h S f w RG rg gs BT Tf Tz Td Tj ET`) and
  composes the CTM; each path's points, carried to page space, match the
  recorded op's points carried through the same residual, to `1e-6` pt; a
  sampled point on each Bézier arc lies on its circle to `1e-3` pt; the
  arc's mid-point is on the side its sweep's sign says.
- **T-4. Lineweight in millimetres.** The instance's 0.70 mm override is
  `0.70 · 72 / 25.4 = 1.98425…` pt in device space (the `w` operand times
  the CTM's scale), at 1:50 and at 1:100 and whatever camera the app's
  screen holds; a 0.35 mm line is `0.99213…` pt; lineweight 0 writes
  `0 w`.
- **T-5. The text.** `Tf` size is `kNominalTextPixels`; the font object is
  a TrueType font with a `FontFile2`; the string's PDF advance times `Tz`
  equals the measured width to `1e-6`; the glyph run, mapped through the
  CTM, starts at the box's baseline origin; "Yatak Odası" round-trips its
  glyph ids through the font's `cmap`.
- **T-6. Colour and alpha.** The ACI 7 line strokes black (`0 0 0 RG`) on a
  page whose screen foreground is white; the instance's leaves stroke red;
  the 0x80 fill is under an `ExtGState` with `ca` 0.50196…
- **T-7. The PNG.** Pixel sizes for A4 and A3, portrait and landscape, at
  96, 150, 300 dpi; `pHYs` is present with `round(dpi / 0.0254)`; at 300
  dpi a horizontal 0.50 mm line at a known paper position is dark at its
  expected row and white at ±(width/2 + 2) px; an oblique line has pixels of
  intermediate coverage (anti-aliasing); the corners outside the drawing
  are white, not transparent.
- **T-8. Separators.** In the PDF and the PNG of the fixture there is no
  trace of the separator (no path at its points; its pixels white) while
  the screen painter, with the default set, draws it.
- **T-9. The document is untouched.** Codec bytes and `stateId` are equal
  before and after `exportPagePdf` and `exportPagePng`.
- **T-10. The flows.** With a fake `DocumentFiles` and a fake printer, in
  a pumped shell whose camera is **zoomed to 400 % and panned off the
  sheet**: Export → PDF writes `<name>.pdf` whose content, read by the
  reader, has the instance's first point where T-3 puts it (not where the
  screen camera would); Export → PNG at 300 dpi writes a PNG of A4's 300
  dpi size; Cancel in the dialog or the save writes nothing; Print hands
  the fake printer bytes whose content stream equals an export's (F-15:
  the bytes themselves differ in `/ID`); both commands are disabled with
  no page and while busy; Cmd/Ctrl+E and +P invoke them.
- **T-11. What export does not use.** A test reads
  `lib/src/export/page_export.dart` and asserts it names neither
  `VerticesDrawSink` nor `TileCache` nor `DraftCanvas`, and that it names
  `CanvasDrawSink` and `PdfDrawSink`; T-7's anti-aliasing check is the
  behavioural half.
- **T-12. The font.** The app's copy equals the vendored file byte for byte
  and has the recorded SHA-256; the licence file is present and equal.
- **T-13. The goldens.** `flutter test --tags golden` passes; `git status`
  shows no change under `test/golden/`.

## Named mutants

| ID | Mutation | Goes red |
|---|---|---|
| M-13a | `exportPagePng` paints with `VerticesDrawSink` | T-11, T-7 (AA) |
| M-13b | drop `pixelsPerPaperMm` (`u`) from the stroke width | T-4 |
| M-13c | multiply the stroke width by the camera's scale | T-4 at 1:100 |
| M-13d | the flow passes the screen camera instead of the page's | T-10 |
| M-13e | `exportPagePng` bakes through a `TileCache` | T-11 |
| M-13f | `pageCamera` ignores `originX` / `originY` | T-1, T-3 |
| M-13g | `pageCamera` without the y flip | T-1, T-3 |
| M-13h | `PdfDrawSink` page set-up without `cm [1 0 0 −1 0 H]` | T-3 |
| M-13i | `PdfDrawSink` ignores the residual | T-3 (the instance) |
| M-13j | the Bézier arc uses `|sweep|` | T-3 (sweep −110°) |
| M-13k | a closed polyline without `h` | T-3 |
| M-13l | `Tz` omitted (100) | T-5 |
| M-13m | text with an extra y flip | T-5 |
| M-13n | the export resolver keeps the default (white) foreground | T-6 |
| M-13o | alpha ignored in the PDF | T-6 |
| M-13p | `minTextCapPixels` left at the default | T-2, T-5 (the label) |
| M-13q | the painter ignores `omitOwners` | T-2, T-8 |
| M-13r | `omitOwners` tested on the leaf's handle, not its owner | T-2, T-8 |
| M-13s | PNG size with `floor` instead of `round` | T-7 (A4 at 150 dpi) |
| M-13t | `pHYs` from dpi / 0.254 | T-7 |
| M-13u | no white ground in the PNG | T-7 |
| M-13v | the print flow exports a second time with `omitOwners` empty | T-10 |
| M-13w | export enabled without a page | T-10 |
| M-13x | `exportPagePdf` runs a command (e.g. attaches the page) | T-9 |

Equivalent mutants are recorded by experiment, never by argument.

## Exit gate

- Engine: `dart test`, `dart analyze`, `dart format` green; the engine is
  byte-unchanged.
- Render: `flutter test` (all tags), `flutter analyze`, `dart format` green;
  **`flutter test --tags golden` green with no golden PNG regenerated**;
  the two allocation invariant tests untouched and green.
- App: `flutter test`, `flutter analyze`, `dart format` green;
  `flutter build web` succeeds.
- Every named mutant red, or equivalent by recorded experiment.
- The licences of `pdf`, `printing` and their new transitive packages
  recorded in the results note.
- **The human's look on macOS and web** (below), which only the human marks
  done.

### The look (the human's, macOS and web)

- **L-1.** Text on screen now draws in Roboto (room labels, dimensions,
  symbol names in the gallery): it reads correctly, Turkish letters
  included.
- **L-2.** Export → PDF, opened in Preview / the browser: the page is the
  sheet's size and orientation; the drawing sits where it sits on the
  sheet on screen; a wall or dimension measured with a ruler on a 100 %
  print agrees with the scale.
- **L-3.** Lines are sharp at any zoom in the PDF viewer; thick and thin
  lines read as on screen; text is selectable and reads correctly.
- **L-4.** No grid, no sheet edge, no room separators in the PDF or PNG.
- **L-5.** Export → PNG at each DPI opens at the expected size; the ground
  is white.
- **L-6.** Print… opens the macOS print dialog (sandboxed build) and the
  browser's on the web, with the right paper and orientation; printed at
  100 %, the scale holds.
- **L-7.** Cmd+E / Cmd+P on macOS, Ctrl+E / Ctrl+P on the web (the browser's
  own print must not open instead), and the dialog's Esc.

## Risks

- **R-1. PDF bytes are not deterministic** (F-15). Tests compare content
  streams, never whole files; the print flow is checked the same way.
- **R-2. `Tz` scales a whole string** to Flutter's advance; kerning inside
  the string can still differ by a fraction of a glyph. Accepted.
- **R-3. One font.** Every text style plots in the embedded Roboto. A file
  read from elsewhere naming another family looks different in the PDF than
  on a screen that has that family. Accepted for v1.
- **R-4. `printing` needs Flutter ≥ 3.41.** The human's macOS Flutter must
  meet it; the plan states the bound in the app's pubspec and the results
  note.
- **R-5. The browser may scale a print** ("fit to page"); L-6 checks 100 %.
- **R-6. A3 at 300 dpi is 3508 × 4961 px, about 70 MB** of RGBA while it is
  encoded; on the web this is near the limit. Accepted; 150 is the default.
- **R-7. The screen font changes** on macOS and web once Roboto is bundled;
  text metrics move with it, so labels may sit slightly differently than
  before. No golden moves (they load their own font or draw Ahem).
- **R-8. Cmd/Ctrl+P on the web** competes with the browser's own print
  shortcut; the shell must consume it (L-7).

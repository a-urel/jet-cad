# Export and print (13) — design

**Date:** 2026-10-01. **Status:** design, **revision 3**. Revision 1
(`054d6df`) was reviewed independently: "Ready with amendments", 0
blocking, 10 major, 8 minor, 2 nit (W-1 to W-20), each applied below; see
[Revision 2](#revision-2). Its spot check (`818b835`): "Ready with
amendments" (S-1 to S-7), applied in [Revision 3](#revision-3).
**Approved by the human on 2026-10-01** ("onaylıyorum, planı yaz").
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
  text whose cap height on screen is below it (`:949`); `0.0` disables
  level of detail.
- **F-3. The sinks.** `DrawSink` (`draw_sink.dart:17`) has eleven
  methods plus the `shadesDashes` getter. `CanvasDrawSink.shadesDashes` is false
  (`canvas_draw_sink.dart:86`), so the painter cuts dashes into spans
  itself. Stroke width is `lineweightHundredths / 100 · pixelsPerPaperMm ·
  lineweightScale`, divided by the residual's scale magnitude; 0 is a
  hairline (`:263-270`). Fills are filled paths, non-zero, one `Paint`
  reused. `point` draws a screen-space square. `text` lifts by the
  paragraph's `alphabeticBaseline` and flips y, because the residual maps
  **glyph space** (y up, origin on the baseline, size
  `kNominalTextPixels`) to screen (`:218-241`).
- **F-4. The oracle.** `referenceWalk(doc, sink, camera, viewport,
  resolver, {minTextCapPixels})` (`reference_walk.dart:30`) walks the tree
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
  `flutter test --tags golden`. The golden PNGs are macOS-generated
  (`dart_test.yaml`); **7 of them fail on Linux as standing failures**
  (STATUS.md), so the Linux gate is "the same 7, no new one".
  `text_ladder_golden_test.dart` loads the vendored Roboto under the family `Roboto`, which is what the Standard
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
  drawing differ in their bytes. Further: every number is written with
  **5 decimals** (`PdfNum.precision`, `format/num.dart:26-38`);
  `drawString` writes `[<hex>] TJ`, its `scale` a fraction written ×100
  as `Tz` (`graphics.dart:530-620`); a Unicode TTF is written as `/Type0`
  over a subset `CIDFontType2`, Identity-H, whose CIDs are subset indices,
  with a `/ToUnicode` map and `/W` widths truncated to integer thousandths
  of an em (`ttffont.dart:51-55,130-200`); `save()` runs `Isolate.run` on
  native (`document.dart:281-289`), while `write(PdfStream)` does not
  (`:299`). **`pdf` 3.13.x itself requires `sdk >=3.12.0`.**
- **F-16. `printing` 5.15.1** (Apache 2.0, `sdk >=3.12.0`, **`flutter
  >=3.41.0`**) depends on `pdf`, `http`, `image`, `pdf_widget_wrapper`,
  `flutter_web_plugins`, `plugin_platform_interface`, `web`; `Printing.layoutPdf(onLayout:, name:, format:, dynamicLayout:)` opens
  the system dialog on macOS and the browser's on the web; `format`
  defaults to `PdfPageFormat.standard` (`printing.dart:52-61`). The app's pubspec says `flutter:
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
  raises the `flutter:` bounds of the app **and** of `jet_cad_2d_flutter`
  (today `">=3.24.0"`) to what `printing` and `pdf` require; no `sdk:`
  bound moves (R-4).

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
  join), `4 M` (miter limit) — Skia's `Paint` defaults, which
  `CanvasDrawSink` uses (PDF's own miter limit is 10).
- **Precision.** The `pdf` package writes 5 decimals (F-15). Coordinates
  stay in the painter's spaces and `cm` carries the residual; the tests'
  tolerances are derived from the rounding (T-3), not wished smaller.
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
- **`point`**: as `CanvasDrawSink.point` (`canvas_draw_sink.dart:140-164`):
  the point is carried through the current residual by hand (no `cm`) and
  an axis-aligned square of side `lineweight / 100 · u` is filled around it
  in screen space; at lineweight 0 nothing is drawn.
- **Graphics state is written in full for every primitive**: its colour
  (`RG` or `rg` from the ARGB's RGB), its width (`w`, strokes) and its
  alpha as a `gs` — an `ExtGState` with `CA` and `ca` = alpha / 255, one
  object per distinct alpha, **alpha 255 included** — so nothing a
  previous op or a `Q` left behind is relied on. No state cache.
- **`text`**: under the residual, which maps glyph space (y up, baseline
  origin) to screen; the page's y flip cancels the camera's, so the glyphs
  stand upright with no further flip: `BT /F size Tf Tz 0 0 Td […] TJ ET`,
  `size = kNominalTextPixels`, the fill colour the entity's. **`Tz`** is
  `100 · w_flutter / w_pdf`, where `w_flutter` is the advance the painter
  laid the box out with (`FlutterTextMeasurer`, the same record) and
  `w_pdf` the string's advance at `size` **from the `/W` widths as the
  package writes them** (integer thousandths of an em, F-15), so a viewer
  draws exactly that advance: the PDF's
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

The bytes come from `PdfDocument.write(PdfStream)`, not `save()`, so no
isolate is spawned (F-15) and a pumped test can drive it.

One page of the effective paper size in pt. Builds a `SpatialIndex`
(disposed in `finally`), a `DocumentStyleResolver(document, foreground:
0x000000)` — **the paper is white whatever `page.background` is** (F-7) —
a `DraftPainter(minTextCapPixels: 0.0, omitOwners:)`, the page camera at
`u = 72 / 25.4`, and a `PdfDrawSink`; paints; returns the bytes `write(PdfStream)` produced. It
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
  `toByteData(format: png)`; the export's own measurer is `clear()`ed in
  `finally`.
- Exactly one `pHYs` chunk, inserted after `IHDR` and before the first
  `IDAT`: pixels per metre
  `round(dpi / 0.0254)` on both axes, unit 1, CRC-32 computed.
- Text is drawn by Flutter in whatever font the `Roboto` family resolves
  to in the running app — the bundled one (D7).

### D6 — `omitOwners`

**Meaning: a leaf whose direct owner is in the set is not drawn.** Nothing
else is skipped: a nested group's leaves (owned by the inner group) and an
instance under an omitted group still draw. A separator is a childless
group with one leaf (F-8), so for the one use today the two readings
coincide; the narrow one is chosen because both routes below can state it
exactly.

`DraftPainter` gains a constructor parameter `Set<Handle> omitOwners =
const {}`. A leaf is skipped before anything is resolved for it when
`omitOwners.isNotEmpty && omitOwners.contains(entities.ownerAt(slot))`, at
the root stream and inside containers alike. Groups are flattened into the
root index (`container_index.dart:186-194`), so a separator's leaf arrives
on the root stream and `ownerAt` names the group. On the screen the set is the
empty constant: one `isNotEmpty` per leaf, no allocation; the two
allocation invariant tests stay untouched and green.

`referenceWalk` gains the same parameter and honours it **by its own
route**: when it visits a node `h` in the set it skips `leavesByOwner[h]`
and still recurses into `h`'s child nodes. Two routes, one meaning: a test
where they disagree is red (T-2 includes a nested group under an omitted
group, whose leaves must draw).

The app's set: `liveObjectsOf<SeparatorParams>(document).toSet()` at the
moment of export (`liveObjectsOf` returns a list).

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
  `Roboto`, read through `rootBundle`, so `Roboto_LICENSE.txt` is listed
  under `assets:` too.
- The flows read the bytes once per app with `rootBundle.load` and pass
  them to `exportPagePdf`.

### D8 — `Export…`

- A `ShellCommand(id: 'export', label: 'Export…', icon:
  Icons.ios_share_outlined, shortcuts: Cmd/Ctrl+E)` after `Save As…` in
  `fileCommands`, a flow under busy, after `_settlePendingInput`.
- **Enabled** while not busy **and** the document has a page. The host
  knows only busy (`document_host.dart:237`); the page lives in the shell
  (`PageNotifier`, `main.dart:242`), which already re-wraps the file
  commands (`main.dart:529-536`). The shell adds, for `export` and
  `print` only, a `DerivedFlag` over its `PageNotifier` (`page != null`).
  The flow re-reads the page after `_settlePendingInput` and returns
  without effect if it is null.
- The chords join `kFileChords` (`shell_commands.dart:41`), so they are
  consumed above the Navigator (`main.dart:136-141`) and Ctrl+P with the
  dialog open does not reach the browser's print.
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
  callers are unchanged by the defaults. The web `saveLocation` appends
  `.jetplan` today (`document_files_web.dart:52-56`); it calls a new
  `fileNameFor(typed, kind)` instead (`jetplanFileName` becomes its
  `jetplan` case), unit-tested per kind. The test fake
  (`test/support/fake_document_files.dart`) takes and records `kind`.
- A failure (a throw from the export or the write) is reported the way a
  failed save is today.

### D9 — `Print…`

- `ShellCommand(id: 'print', label: 'Print…', icon: Icons.print_outlined,
  shortcuts: Cmd/Ctrl+P)`, after `Export…`; enabled as D8.
- Runs `exportPagePdf` once and hands those bytes to a `PagePrinter`
  (`Future<void> print(Uint8List pdf, String name, PdfPageFormat format)`,
  `format` the page's size in pt); the production one
  calls `Printing.layoutPdf(onLayout: (_) async => pdf, name:, format:
  PdfPageFormat(effW · 72 / 25.4, effH · 72 / 25.4), dynamicLayout:
  false)` — without `format` the dialog opens on `PdfPageFormat.standard`
  (F-16). `PagePrinter.print` takes that size; tests inject a fake that
  records the bytes, the name and the size.
- Both entitlement files gain `com.apple.security.print`.

### D10 — What the export is not allowed to use

The export path uses no `VerticesDrawSink` (whose `drawVertices` ignores
`isAntiAlias`, roadmap 13 decision 1) and no `TileCache` (decision 2). The
PNG draws through `CanvasDrawSink`, the PDF through `PdfDrawSink`. Both are
asserted (T-7's anti-aliasing check and T-11). T-11 is **structural** (a
read of the source), not the counter roadmap 13 sketched: `TileCache` is
built only by `DraftCanvas` (F-9), which the export never builds.

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
polygon with alpha 0x80, a text "Yatak Odası" 250 mm high **and a text "WC" 25 mm high** (0.5 mm
on paper, a cap height of 1.42 pt, below the default LOD cull of 3), a
**point entity inside the instance**, a nested group (with one line) inside
a group (the "outer group") that is in `omitOwners` in T-2 and that also
has **one line of its own** and **an instance of its own** (whose leaves
must draw: D6), an instance
**rotated 30°, scaled (1.5, −0.75)**, with **colour and lineweight
overrides** (red, 0.70 mm) over a definition whose `basePoint` is not the
origin, an ACI 7 line, a separator group, and one line wholly outside the
sheet.

**Route per test** (a mutant in `page_export.dart` is seen only by a test
that goes through it): T-1 calls `pageCamera`; T-2 builds its own painter
and walk; T-3 and T-3b feed `PdfDrawSink` directly (ops recorded at the
page camera, or calls by hand); **T-4, T-5, T-6, T-8 (PDF) and T-9 call
`exportPagePdf(compress: false)`**; **T-7, T-8 (PNG) and T-9 call
`exportPagePng`**; T-10 goes through the app's flows.

- **T-1. The page camera.** Sheet corners map to `(0, 0)`, `(W, 0)`,
  `(W, H)`, `(0, H)` within `Tolerance`; at 1:50 and 1:100, portrait and
  landscape; a 1,000 mm world segment is `1000 / den · u` long.
- **T-2. Differential at the page camera.** The painter and
  `referenceWalk`, both with `omitOwners = {separator, outer group}` and
  `minTextCapPixels: 0`, into `RecordingDrawSink`, compared by
  `sink_comparison.dart`. Both lists contain the instance's leaves, both
  texts ("WC" included), the nested group's line and the outer group's
  instance's leaves, and contain no
  separator op, nothing of the outer group's own leaves and nothing from
  the outside line.
- **T-3. `PdfDrawSink` geometry.** Ops recorded at the page camera replayed
  into a `PdfDrawSink`, `compress: false`; the test reader parses the
  content stream (`q Q cm m l c h S f re w J j M RG rg gs BT Tf Tz Td TJ
  ET`) and composes the CTM; each path's points, carried to page space,
  match the recorded op's points carried through the same residual. **The
  tolerance is derived from the 5-decimal rule** (F-15): `1e-5` pt for an
  op in screen space; under a residual, `5e-6 · (|x| + |y| + 1)` per
  matrix entry and operand, propagated through the CTM (the plan writes
  the bound as a function). A sampled point on each Bézier arc lies on its
  circle within the same bound plus the cubic's own `2.7e-4 · r`; the
  arc's mid-point is on the side its sweep's sign says. The point entity
  is an axis-aligned square in device space with side `lw · u`.
- **T-3b. `PdfDrawSink` directly.** A `polyline(…, closed: true)` writes
  `h` before `S`, one with `closed: false` does not. The painter always
  passes `closed: false` today (`draft_painter.dart:305,613-650`), so this
  path is reached only by this test; it is kept because `DrawSink` has it.
  An opaque stroke after a translucent fill runs under an `ExtGState` with
  `CA` and `ca` 1; a stroke after a residual's `Q` writes its colour and
  width again.
- **T-4. Lineweight in millimetres.** The instance's 0.70 mm override is
  `0.70 · 72 / 25.4 = 1.98425…` pt in device space (the `w` operand times
  the CTM's scale), at 1:50 and at 1:100 and whatever camera the app's
  screen holds; a 0.35 mm line is `0.99213…` pt; lineweight 0 writes
  `0 w`.
- **T-5. The text.** Run with flutter_test's default font in the measurer
  (Ahem: every glyph one em), so `Tz` is far from 100 and its omission is
  visible. `Tf` size is `kNominalTextPixels`; the font is a `/Type0` over a
  `CIDFontType2` with a `FontFile2`; the string's advance from the written
  `/W` widths times `Tz / 100` equals the measured width within the
  5-decimal bound; the run, mapped through the CTM, starts at the box's
  baseline origin; **the direction of text space** — the PDF page-space
  image of text-space `(0, 1)` under the parsed CTM and text matrix —
  equals `pageSetUp · residual · (0, 1)` as a direction, `pageSetUp` being
  `[1 0 0 −1 0 H]` (an extra flip reverses it; the expected value already
  contains the page flip, so it must not be "fixed" by adding one); "Yatak Odası" round-trips through
  the font's `/ToUnicode`; "WC" is present.
- **T-6. Colour and alpha.** The ACI 7 line strokes black (`0 0 0 RG`) on a
  page whose screen foreground is white; the instance's leaves stroke red;
  the 0x80 fill is under an `ExtGState` with `ca` 0.50196…; the opaque op
  drawn after it is under `ca` / `CA` 1.
- **T-7. The PNG.** The "WC" label's box has dark pixels at 300 dpi.
  Pixel sizes for A4 and A3, portrait and landscape, at
  96, 150, 300 dpi; `pHYs` is present with `round(dpi / 0.0254)`; at 300
  dpi a horizontal 0.50 mm line at a known paper position is dark at its
  expected row and white at ±(width/2 + 2) px; an oblique line, sampled
  away from any text (text is anti-aliased on both sinks), has pixels of
  intermediate coverage — `drawvertices_antialiasing_test.dart` pins that
  `drawVertices` gives none under flutter_test; the corners outside the
  drawing are white, not transparent; exactly one `pHYs`, before `IDAT`.
  PNG tests run under `tester.runAsync` (F-6).
- **T-8. Separators.** In the PDF and the PNG of the fixture there is no
  trace of the separator (no path at its points; **every pixel of its
  segment's band** white, since a single sample can fall in a dash gap)
  while the screen painter, with the default set, draws it.
- **T-9. The document is untouched.** Codec bytes and `stateId` are equal
  before and after `exportPagePdf` and `exportPagePng`.
- **T-10. The flows.** With a fake `DocumentFiles` and a fake printer, in
  a pumped shell whose document **contains a separator** and whose camera
  is **zoomed to 400 % and panned off the sheet** (the export API takes no
  camera, so passing the screen's is ruled out by construction; this
  checks the whole flow); the PNG flows run under `tester.runAsync`
  (`toImage`); the PDF flows need it not (D4's `write`): Export → PDF writes `<name>.pdf` whose content, read by the
  reader, has the instance's first point where T-3 puts it (not where the
  screen camera would); Export → PNG at 300 dpi writes a PNG of A4's 300
  dpi size; Cancel in the dialog or the save writes nothing; Print hands
  the fake printer bytes whose content stream equals an export's (F-15:
  the bytes themselves differ in `/ID`) and the page's size in pt, and
  neither the export nor the print has the separator; both commands are
  disabled with no page and while busy; Cmd/Ctrl+E and +P invoke them, and
  are consumed with the dialog open. `fileNameFor` per kind: `plan` →
  `plan.pdf`, `plan.png`, `plan.jetplan`; `plan.png` as PNG unchanged.
- **T-11. What export does not use.** A test reads
  `lib/src/export/page_export.dart` and asserts it names neither
  `VerticesDrawSink` nor `TileCache` nor `DraftCanvas`, and that it names
  `CanvasDrawSink` and `PdfDrawSink`; T-7's anti-aliasing check is the
  behavioural half.
- **T-12. The font.** The app's copy equals the vendored file byte for byte
  and has the recorded SHA-256; the licence file is present and equal.
- **T-13. The goldens.** `flutter test --tags golden` on Linux fails
  exactly the 7 standing failures recorded at `a0a1920` and no other;
  `git diff --stat -- packages/jet_cad_2d_flutter/test/golden/` is empty.
  A green macOS run is the human's to confirm.

## Named mutants

| ID | Mutation | Goes red |
|---|---|---|
| M-13a | `exportPagePng` paints with `VerticesDrawSink` | T-11, T-7 (AA) |
| M-13b | drop `pixelsPerPaperMm` (`u`) from the stroke width | T-4 |
| M-13c | multiply the stroke width by the camera's scale | T-4 at 1:100 |
| M-13d | `page_export.dart` builds its camera with `fitToPage(page, size)` or `ViewportTransform.fit(extents)` instead of `pageCamera` | T-5 (baseline origin), T-10 |
| M-13e | `exportPagePng` bakes through a `TileCache` | T-11 |
| M-13f | `pageCamera` ignores `originX` / `originY` | T-1, T-3 |
| M-13g | `pageCamera` without the y flip | T-1, T-3 |
| M-13h | `PdfDrawSink` page set-up without `cm [1 0 0 −1 0 H]` | T-3 |
| M-13i | `PdfDrawSink` ignores the residual | T-3 (the instance) |
| M-13j | the Bézier arc uses `|sweep|` | T-3 (sweep −110°) |
| M-13k | a closed polyline without `h` | T-3b |
| M-13l | `Tz` omitted (100) | T-5 |
| M-13m | text with an extra y flip | T-5 |
| M-13n | the export resolver keeps the default (white) foreground | T-6 |
| M-13o | alpha ignored in the PDF | T-6 |
| M-13p | `page_export.dart` leaves `minTextCapPixels` at the default | T-5 ("WC"), T-7 ("WC" pixels) |
| M-13q | the painter ignores `omitOwners` | T-2, T-8 |
| M-13r | `omitOwners` tested on the leaf's handle, not its owner | T-2, T-8 |
| M-13s | PNG size with `floor` instead of `round` | T-7 (A4 at 150 dpi) |
| M-13t | `pHYs` from dpi / 0.254 | T-7 |
| M-13u | no white ground in the PNG | T-7 |
| M-13v | the print flow exports a second time with `omitOwners` empty | T-10 |
| M-13w | export enabled without a page | T-10 |
| M-13x | `exportPagePdf` runs a command (e.g. attaches the page) | T-9 |
| M-13y | alpha not reset: no `gs` for an opaque op | T-3b, T-6 |
| M-13z | state cached across a `Q` (colour and width skipped when unchanged) | T-3b |
| M-13aa | `referenceWalk` skips the omitted node's subtree | T-2 (the nested group) |
| M-13ab | print without `format` (the standard page) | T-10 |
| M-13ac | the web save appends `.jetplan` to every kind | T-10 (`fileNameFor`) |
| M-13ad | the point marker drawn under `cm` (turned with the instance) | T-3 |

Equivalent mutants are recorded by experiment, never by argument.

## Exit gate

- Engine: `dart test`, `dart analyze`, `dart format` green; the engine is
  byte-unchanged.
- Render: `flutter test`, `flutter analyze`, `dart format` green, the
  golden tag failing **only the 7 standing Linux failures**, **no golden PNG
  regenerated** (T-13);
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
- **R-4. Toolchain.** `printing` needs Flutter ≥ 3.41 and `pdf` 3.13
  needs Dart ≥ 3.12, which raises the minimum toolchain of the render
  package and of everything that depends on it (`dev_harness_2d`
  included). The plan raises **only the `flutter:` bounds, never `sdk:`**
  (`sdk: ^3.5.0` sets the language version; a bump would flip `dart format`
  to the tall style). `flutter pub get` rewrites `analysis_options.yaml`,
  which is never committed. The human's macOS Flutter must meet the bound.
  If staying on Flutter 3.38 matters, `printing` 5.14.3 with `pdf` ≤ 3.12
  is the fallback.
- **R-5. The browser may scale a print** ("fit to page"); L-6 checks 100 %.
- **R-6. A3 at 300 dpi is 3508 × 4961 px, about 70 MB** of RGBA while it is
  encoded; on the web this is near the limit, and 4961 exceeds a 4096
  maximum texture size on some WebGL GPUs, where `toImage` may fail (the
  failure is reported as D8 says). Accepted; 150 is the default.
- **R-7. The screen font changes** on macOS and web once Roboto is bundled;
  text metrics move with it, so labels may sit slightly differently than
  before. No golden moves (they load their own font or draw Ahem).
- **R-8. Cmd/Ctrl+P on the web** competes with the browser's own print
  shortcut; the shell must consume it (D8, L-7).
- **R-9. Dashes differ between outputs.** The dasher's collapse threshold
  (`kDashCollapsePx = 3`, `dasher.dart:21`) is judged in output units (pt,
  or px at the chosen dpi), so a fine dash pattern may read solid in one
  output and dashed in another.

## Revision 3

The spot check of revision 2 (S-1 to S-7): S-1 the route per test stated
above T-1, M-13d and M-13p remapped to tests that go through
`page_export.dart`, T-7's "WC" check; S-2 D4 returns `write`'s bytes; S-3
T-5's direction check written in page space; S-4 the outer group has a
line and an instance of its own; S-5 `PagePrinter.print` takes the
format; S-6 D1 names both `flutter:` bounds; S-7 `runAsync` for the PNG
flows only.

## Revision 2

The independent review of revision 1 (W-1 to W-20) and where each landed:
W-1 tolerances derived from the 5-decimal rule (D3 "Precision", T-3);
W-2 T-3b, M-13k; W-3 the "WC" label; W-4 T-5's direction check; W-5 state
written in full, `4 M`, M-13y, M-13z; W-6 D9's `format`, M-13ab; W-7 D6's
meaning and the walk's route, M-13aa; W-8 M-13d restated; W-9 the Linux
golden gate; W-10 the reader's operators, `/W` widths, `/ToUnicode`, Ahem
in T-5; W-11 D3's `point`, M-13ad; W-12 `write(PdfStream)`, `runAsync`;
W-13 the shell's page flag, `kFileChords`; W-14 `fileNameFor`, M-13ac;
W-15 R-4; W-16 T-7's refinements, `clear()`; W-17 D10; W-18 T-8's band,
T-10's separator, R-9; W-19 the licence asset (the font in the pubspec does
not change widget tests: the reviewer's experiment); W-20 R-6. Facts
F-2, F-3, F-4, F-10, F-15, F-16 corrected.

## Amended at execution (Plan 13)

Where execution made this spec precise or departed from it, each with the
ruling or review that decided it (the plan's ledger,
`ledgers/2026-10-01-plan-13/progress.md`, archived by a later commit;
results: [2026-10-01-plan-13-results.md](../notes/2026-10-01-plan-13-results.md)).
This section rewrites nothing above it.

- **R-4, F-15, F-16, D1: the toolchain floor is Flutter 3.44.0 (R-13-7,
  Task 3).** `pdf` 3.13 needs Dart 3.12, and the first stable Flutter with
  Dart 3.12 is 3.44.0 (3.41.x ship Dart 3.11; the official releases index).
  So the `flutter:` bound of `jet_cad_2d_flutter` (`babfcc1`) and of the app
  (`6a726a9`) is `>=3.44.0`, not printing's 3.41. No `sdk:` bound moved. The
  human's macOS Flutter must be 3.44.0 or newer.
- **D3 "text", D4: the PDF measures with `document.textMeasurer`
  (R-13-14, Task 4 review finding 1, `d3063ab`, `c134c14`).** The painter
  lays every text box out with `document.textMeasurer`, so `PdfDrawSink`'s
  `measurer` is typed `TextMeasurer` and `exportPagePdf` passes the
  document's own measurer and `textStyleOf`; `w_flutter` is that measurer's
  advance. The plan's "own `FlutterTextMeasurer` cleared in `finally`" is
  dropped for the PDF path; D5's PNG keeps its own (`CanvasDrawSink` needs
  `paragraphFor`). In the app both are `FlutterTextMeasurer`s over one font
  set, so the two agree (R-13-19: the PNG differs only for a non-Flutter
  measurer, which cannot reach the app's export). `text()` refuses a font
  that is not on the CID path (`StateError`), and the font is built on the
  first text (R-13-12: a page without text embeds none).
- **D4, D5, I-3: an export leaves the dispatcher's mutation hooks as it
  found them (R-13-17, Task 5 review finding 1, `8fe438b`).** A
  `SpatialIndex` takes the dispatcher's single `onBeforeMutate` /
  `onAfterMutate` hooks and nulls them on `dispose()`, which unhooked the
  app's screen index after an export (demonstrated). The engine has no
  detached index, so both exports paint inside `_withExportIndex`, which
  saves both hooks, runs a **synchronous** body, disposes the index and
  restores both hooks in `finally` (on a throw as well); `toImage` and
  `write` run outside it. I-3 therefore reads: the codec's bytes, the
  `stateId` **and both mutation hooks** are equal before and after. Pinned
  by `export_pdf_test.dart`, `export_png_test.dart` and the app's EX2.
- **D3: a page that paints nothing has no `/Contents` (R-13-9, R-13-16).**
  The package drops a content stream that holds only the set-up and state
  operators; nothing may expect the set-up `cm` on an empty page. "One
  `ExtGState` object per distinct alpha" is, as written by the package, one
  `ExtGState` dictionary with one `/aN` entry per distinct alpha (Task 3
  report): the same meaning.
- **Architecture, plan P-2: the reader lives in `lib/` (R-13-2).** It is
  `packages/jet_cad_2d_flutter/lib/src/export/testing/pdf_content.dart`,
  exported by the separate library `package:jet_cad_2d_flutter/export_testing.dart`
  that nothing in `lib/` imports, not `test/support/pdf_content.dart`, so
  the app's tests read PDFs with it. It has its own tests
  (`pdf_content_test.dart`).
- **T-2: the comparison is `test/support/differential.dart` (R-13-5,
  R-13-6).** `sink_comparison.dart` compares the canvas and vertices
  backends by pixels; the painter-versus-walk oracle is
  `expectPainterSupersetOfReference` / `flatten` in `differential.dart`,
  with an equal-count assertion added so T-2 checks equality. The painter
  records with `RecordingDrawSink(shadesDashes: true)` (the walk does not
  cut dashes), so T-2 does not cover the painter's dash cutting (the
  dasher's own tests do). T-2 also omits a definition (the container route,
  which the plan's set never reaches) and an instance's attribute (Task 2
  review findings 1-2, `ff0d853`).
- **Unplanned screen fix `32d488f` (R-13-4, Task 2).** A root-level instance
  whose parent is a group was drawn with its own transform only (groups fold
  into the root index; the painter dropped the group's transform, while
  culling, picking, snapping and outlines used the composed one). T-2 could
  not pass without the fix: a grouped root instance now takes the index's
  composed transform; an ungrouped one is unchanged. It moves an instance
  inside a user group on screen (to where everything else already put it).
  No golden moved; allocation-free by reading; its linear lookup per frame is
  found-not-fixed.
- **Testing, the fixture: `basePoint` is stored, never read (R-13-1).** No
  renderer or engine path reads `Definition.basePoint` (the placer applies
  it), so the fixture's (120, 45) cannot make any test red and is not a
  coverage trait. The separator keeps the real separator's style (ByLayer,
  DASHED, 35), the one deliberate default (R-13-3). "WC" uses its own text
  style record (Task 4 review finding 2).
- **Named mutants, as fired.**
  - **M-13k, M-13y, M-13ad are red by T-3b only (R-13-8).** The painter
    always passes `closed: false`, every fixture primitive runs in its own
    `q … Q`, and the fixture's point sits under a translation-only residual,
    so the T-3 replay cannot see them; the direct calls do.
  - **M-13c** as written (the width times the camera's scale) is red at
    both scales; the form that only 1:100 sees (a width following the
    camera's scale, normalised to be right at 1:50) was fired as well (R-13-15).
  - **M-13p on the PNG is red at 150 dpi only (R-13-18).** "WC" is 5.9 px
    high at 300 dpi, above the default cull of 3; at 150 dpi it is 2.95 px.
    T-7's "WC" check runs at 150 and 300 dpi.
  - **M-13x** uses `SetComponentCommand<PageComponent>` (the engine has no
    `AttachComponentCommand`); T-9's `stateId` half kills it (R-13-15).
  - **M-13q / M-13r** were fired against T-2; T-8's omission is pinned by
    the export's own "set not passed" mutants (Tasks 5 and 6).
  - **M-13ac** at `fileNameFor` is red by FK1; at the web call site (the
    spec's wording) it is red by the source test `document_files_sources_test.dart`
    (Task 11), which also pins the web MIME type and the io type group.
  - The print flow exporting twice (E2) is equivalent by observation: the
    export is pure (T-9) and the font cached (R-13-24).
- **F-11, R-7, L-1 on the web (R-13-22, Task 7 review finding 2).** The
  web engine (CanvasKit, skwasm) already fetched Roboto from
  `fonts.gstatic.com` when the font manifest had no `Roboto`; so on the web
  the text was already Roboto (a newer cut). Bundling 2.137 changes the
  version only, and start-up no longer fetches a font from Google. On macOS
  only the drawing's text changes; the Material chrome keeps the system font.
- **D8: the io side adds no extension (R-13-21, Task 8).** The macOS panel
  offers the kind's type group (`saveTypeGroupsFor`) and appends the
  extension itself; the sandbox grants exactly the returned URL, so the
  path is returned unchanged for every kind. Extension matching is
  case-sensitive, as `jetplanFileName` always was (`plan.PDF` downloads as
  `plan.PDF.pdf` on the web). That the panel appends `.pdf` / `.png` is
  Apple's behaviour and is on the human's look list.
- **D8, D9, layout: DC12b and DC12c moved (R-13-23, R-13-24).** Two new
  toolbar buttons (40 px each) raise 12a's narrowest top bar without
  overflow from 576 to 656 px, and the status line's slot is 40 px narrower
  (DC12b's room name shortened to fit). On the human's look list.
- **D9: the app depends on `pdf` directly (R-13-24).** `PdfPageFormat`, in
  the `PagePrinter` signature, is not re-exported by `printing`. New
  packages: `printing` 5.15.1 and `pdf_widget_wrapper` 1.0.4 (Apache 2.0).
  On the web, `layoutPdf` ignores `name` and `format`; the paper comes from
  the PDF's `MediaBox` (Task 10 review).

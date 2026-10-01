# Task 6 report — exportPagePng (spec D5, D10; T-7, T-8 PNG, T-9 PNG, T-11)

**Commit** (on `8fe438b`, not pushed): `ca163b9` feat(render): exportPagePng

Files changed (render package only):
- `lib/src/export/page_export.dart`: the PNG half, +137 lines.
- `test/export/export_png_test.dart`: new, 24 tests.
- `test/export/export_sources_test.dart`: new, 2 tests.

## Implementation (`page_export.dart`)

**`ExportDpi { d96, d150, d300 }`** has `int get value` (a switch returning 96, 150, 300).

**`exportPagePng({document, page, dpi = ExportDpi.d150, omitOwners = const {}})`** does the following, in order:
- Camera: `pageCamera(page, dpi / 25.4)`, unrounded.
- Size: `round(effW / 25.4 · dpi)` × `round(effH / 25.4 · dpi)`.
- Measurer: its own `FlutterTextMeasurer`.
- Recording:
  - A `PictureRecorder` and a `Canvas`.
  - First, `drawPaint` in opaque white `0xFFFFFFFF`.
  - Then, **inside `_withExportIndex`** (R-13-17), a `CanvasDrawSink(canvas, pixelsPerPaperMm: u, measurer: own, textStyleOf: document.textStyleOf)` and a `DraftPainter(resolver: DocumentStyleResolver(document, foreground: 0x000000), minTextCapPixels: 0.0, omitOwners:)`, which paints at `camera.camera, camera.size`.
  - `endRecording` runs in a `finally`.
- Encoding: `toImage(width, height)` and then `toByteData(png)` run **outside** the synchronous body, after the index is disposed and the hooks are restored.
- `_withPhys`: drops any `pHYs` the encoder wrote (the engine writes none today). It inserts one chunk directly after `IHDR`: length 9, ppm `round(dpi / 0.0254)` on both axes, unit 1. The CRC-32 over the type and data comes from a table-driven Dart implementation (`0xEDB88320`).
- Outer `finally`: `image?.dispose()`, `picture?.dispose()`, `measurer.clear()`. The measurer is cleared after `toImage`, so the recorded paragraphs are still alive when the picture is rasterised.

`page_export.dart` names neither `VerticesDrawSink`, `TileCache` nor `DraftCanvas`, not even in comments.

## Tests

`test/export/export_png_test.dart` (24 tests):
- Every test goes through `exportPagePng`.
- The export, `toImage`, the decode (`instantiateImageCodec` → rawRgba) and the reads all run under `tester.runAsync`.
- Pixel positions come from the page's numbers: `((x − ox)/den·u, (oy + effH·den − y)/den·u)`. They are never computed through `pageCamera`.
- The fixture measures with `FlutterTextMeasurer` (Ahem).

**T-7: sizes.** 12 tests: A4 and A3, portrait and landscape, at 96, 150 and 300 dpi.
- Each test reads `IHDR` and compares it against **literal** expected sizes, not against the formula. For example, A4 landscape at 150 dpi is 1754 × 1240, and A3 portrait at 300 dpi is 3508 × 4961.
- One more test checks `ExportDpi.values.map(value) == [96, 150, 300]`.

**T-7: `pHYs`.** One test per dpi. Each checks:
- exactly one `pHYs`;
- it is chunk 1, right after `IHDR` and before the first `IDAT`;
- its data is `[ppm, ppm, 1]` with ppm 3780, 5906 or 11811 (written out);
- its CRC equals a **bit-by-bit** CRC-32 in the test, independent of the export's table;
- every other chunk's CRC still holds.

**T-7: pixels.**
- **"WC" has dark pixels in its box**, at 150 dpi **and** at 300 dpi. 150 is where M-13p bites (see spec finding 1).
- **Horizontal line, on a non-A4-landscape page.** The page is A3 portrait at 1:100, origin (3000, −1500), and the image is 3508 × 4961. A test-local line, 0.50 mm and 0x5D4037, runs at world y 20000, which is row 2421.26.
  - At three columns, the line's row is exactly `[0x5D, 0x40, 0x37, 0xFF]`.
  - Rows `floor(row ∓ (w/2 + 2))` are exactly white and opaque.
- **The oblique fixture line** (4000, 500)–(9000, 2500), 0x1565C0, is crossed by 13-pixel columns at three points along it, at 300 dpi.
  - At least one pixel must be exactly the ink colour.
  - At least one pixel must be neither the ink colour nor white (partial coverage).
- **Corners.** The four corners of the 1754 × 1240 image are `[255, 255, 255, 255]`.

**T-8 (PNG).** At 150 dpi, the band is every pixel whose centre is within `lw/2·u + 1.5` px of the separator's segment, between its ends. That is more than 500 pixels.
- With `omitOwners: {separatorGroup}`, every pixel in the band is exactly white.
- Without the set, some pixels in the band are dark (every channel < 0x80).

**T-9 (PNG).**
- The codec's bytes and the `stateId` (≠ 0) are equal before and after an export.
- **Hook tests**, with a screen index present:
  - Both hooks are `==` after a normal PNG export.
  - Both hooks are `==` after a throwing PNG export.
  - After that, an edit by command is seen by the screen index's `forEachInRect`: the count goes from 0 to 1.
- **The no-index case:** the hooks are null after a normal export and after a throwing one.
- **How the throwing export is made.** `_ArmedMeasurer` wraps a `FlutterTextMeasurer`. While armed, it throws `_Boom` only when the call comes from `DraftPainter.` (by stack trace).
  - So the index's own measurements still succeed, and the throw happens **inside the paint body**.
  - The test asserts the caught error is a `_Boom`.

`test/export/export_sources_test.dart` (T-11, 2 tests): `page_export.dart` contains none of `VerticesDrawSink`, `TileCache`, `DraftCanvas`; it contains `CanvasDrawSink(` and `PdfDrawSink(`.

## Gates (real tails)

Render package, at `ca163b9`'s tree:

**`CI=true flutter test`:**
```
01:04 +1153 ~1 -7: Some tests failed.
```
- That is 1127 + 26, with 1 skip.
- The 7 deduplicated `[E]` failures are exactly text ladder rungs 1–5 and text lod ladder rungs 1–2 (RenderBackend.canvas), the standing set.

**`CI=true flutter analyze`:**
```
No issues found! (ran in 1.6s)
```

**`CI=true dart format --output=none --set-exit-if-changed .`:**
```
Formatted 200 files (0 changed)
```
`format_exit=0`.

**`CI=true flutter test --tags golden`:**
```
00:33 +28 -7: Some tests failed.
```
The same 7 standing failures, and no other.

**Golden files:** `git diff --stat 7fab442 -- packages/jet_cad_2d_flutter/test/golden/` is empty.

**Scope:** `git diff --stat 8fe438b..HEAD -- apps packages/jet_cad_2d packages/jet_cad_2d_flutter/test/golden packages/jet_cad_2d_flutter/test/invariants` is empty.
- The allocation invariant files are untouched and ran green inside the suite.
- **The engine and the app are unchanged and were not re-run.** No pubspec was touched, and the app does not reference `exportPagePng` yet.
- `analysis_options.yaml` was left unstaged.

## Mutants

**How they were run.**
- Runner: `scratchpad/e6/mut.py`. It copies the file to `e6/<id>.bak`, makes exact replacements (each must match exactly once), runs the named test file in the foreground, copies the file back and diffs it. Every run printed `RESTORED diff=0`.
- Logs are in `scratchpad/e6/<id>.log`.
- Abbreviations: E = `lib/src/export/page_export.dart`; PT = `test/export/export_png_test.dart`; ST = `test/export/export_sources_test.dart`.

| id | mutation (E) | test | red tests / real output |
|---|---|---|---|
| M-13a (T-11 half) | `VerticesDrawSink(canvas:, pixelsPerPaperMm:, fallback: CanvasDrawSink(...))` + `sink.flush()` + import | ST | "names no VerticesDrawSink…" `Expected: false Actual: <true>`. `00:00 +1 -1: Some tests failed.` |
| M-13a (AA half) | same three edits | PT | **only** the oblique-line coverage test: `Expected: a value greater than <0> Actual: <0>`, reason `every pixel is either the ink or white: no anti-aliasing`. `00:06 +23 -1: Some tests failed.` |
| M-13e | `TileCache().dispose();` before the paint + import | ST | `Expected: false Actual: <true>`. `00:00 +1 -1: Some tests failed.` |
| M-13s | `.floor()` for width and height | PT | all 12 size tests, e.g. `Expected: [1754, 1240] Actual: [1753, 1240]` (A4 landscape 150); also the A3 horizontal-line test and the corners test (size asserts). `00:06 +10 -14: Some tests failed.` |
| M-13t | `(dotsPerInch / 0.254).round()` | PT | 3 pHYs tests: `Expected: [3780, 3780, 1] Actual: [378, 378, 1]`, `[591…]`, `[1181…]`. `00:05 +21 -3: Some tests failed.` |
| M-13u | no `drawPaint` (no white ground) | PT | horizontal line (`Expected: [255, 255, 255, 255] Actual: [0, 0, 0, 0]`), oblique (`Expected: <255> Actual: <0>` alpha), corners (`Actual: [0, 0, 0, 0]`), T-8 band. `00:06 +20 -4: Some tests failed.` |
| M-13p (PNG) | `minTextCapPixels: 0.0` removed from the PNG painter | PT | "WC" test, reason `no dark pixel in "WC"'s box at 150 dpi`. `00:05 +23 -1: Some tests failed.` |
| H-png-bypass | the PNG path builds `SpatialIndex(document)` itself with try/finally `dispose()` instead of `_withExportIndex` | PT | screen-index hook test: `Expected: <Closure: (DocChange) => void from Function '_onChange@…'> Actual: <null>`, reason `normal export`. `00:06 +23 -1: Some tests failed.` |
| H-norestore | `_withExportIndex`'s outer `finally` restores nothing | PT | same test, `Actual: <null>`, reason `normal export`. `00:05 +23 -1: Some tests failed.` |
| OWN-normalonly | no outer try/finally; restore after a normal return only | PT | same test, `Actual: <null>`, reason **`throwing export`** (the PNG throwing path is the one that sees it). `00:06 +23 -1: Some tests failed.` |
| OWN-unit0 | pHYs unit byte 0 | PT | 3 pHYs tests. `00:06 +21 -3: Some tests failed.` |
| OWN-crc-data | CRC over the data only, not type + data | PT | 3 pHYs tests (`Actual: <63835626>`). `00:05 +21 -3: Some tests failed.` |
| OWN-phys-end | pHYs appended after `IEND` instead of after `IHDR` | PT | 3 pHYs tests (`indexOf('pHYs')` `Actual: <19>`). `00:06 +21 -3: Some tests failed.` |
| OWN-omit | `omitOwners:` not passed to the PNG painter | PT | T-8 (`Expected: every element([255, 255, 255, 255]) Actual: [`). `00:06 +23 -1: Some tests failed.` |
| OWN-fg | `DocumentStyleResolver(document)` (white foreground) | PT | T-8 "some dark" (`Expected: non-empty Actual: WhereIterable<List<int>>:[]`): the ByLayer separator plots white on white. `00:06 +23 -1: Some tests failed.` |
| OWN-clear | `measurer.clear()` removed | PT | **survives**, `00:06 +24: All tests passed!`. The measurer is local to the call and not observable from the output. Its paragraphs' native memory waits for the GC's finalizers instead of being released at once. Recorded, not pinned: pinning it would need an injection seam that the spec does not have. |

## The PNG text: the painter's box vs the export's own measurer (brief question)

**How the two measurers meet.**
- The painter lays every box out (justification offset, rebase, residual) with `document.textMeasurer`.
- `CanvasDrawSink` draws the paragraph from the export's own `FlutterTextMeasurer`, at the residual's glyph-space origin.
- The two disagree only if their metrics for the same `(text, style record)` differ.

**In the app they cannot differ.**
- `DraftCanvas` refuses a document whose measurer is not a `FlutterTextMeasurer` (`draft_canvas.dart:310-318`), and the app builds every document with one.
- Two `FlutterTextMeasurer`s in one process resolve the same family to the same font and lay the same paragraph out.
- Measured (scratch probe, flutter_test): "Yatak Odası" under Standard gives `advanceWidth 1100.0, capHeight 70.0` from two separate instances, identical.
- So the misplacement in the app is **0**.

**It can be non-zero only for a document whose measurer is not Flutter-backed** (a `MetricModelMeasurer`, headless tooling).
- **Left/baseline text:** the glyphs start at the right origin, but their drawn width is Flutter's, not the box's. The PDF's `Tz` corrects that width; the PNG does not.
- **Centred/right text:** the glyphs shift by the justification fraction × (w_doc − w_flutter).
  - Example: "Yatak Odası" measures 605 with `MetricModelMeasurer(0.55)` against Flutter's 1100. That is a 495-unit difference, or **7.1 cap heights** for right alignment and **3.5 cap heights** for centred.
  - For a 5 mm label, centred text would sit about 18 mm off.
- **Vertical alignments** use the ascent: 80 against 75, about 0.07 cap height.

Not redesigned. A non-Flutter document cannot reach the app's export.

## What the spec / plan got wrong or left open

1. **M-13p on T-7 at 300 dpi cannot go red.**
   - Spec T-7 says "WC"'s box has dark pixels **at 300 dpi**, and the mutant table says M-13p goes red there.
   - But "WC"'s cap height is 25/50 mm × 300/25.4 = **5.9 px**, above the default cull of 3. At 300 dpi the default LOD keeps "WC".
   - At 150 dpi the cap height is 2.95 px, which is culled; at 96 dpi it is 1.89 px.
   - The test checks both 150 and 300 dpi. M-13p is red at 150, as the log's reason says.
   - Spec amendment at Task 11: T-7's "WC" check at 150 (or 96) dpi.
2. **M-13a's behavioural half is the oblique-line coverage check only.**
   - Under `VerticesDrawSink` every other PNG test stays green. That includes the horizontal line, because axis-aligned full-coverage rows look the same without AA.
   - So T-11 and the coverage check are the only guards, as D10 intends.
3. **The plan's "index disposed in finally"** is satisfied through `_withExportIndex` (R-13-17), not by a dispose in `exportPagePng` itself.
4. **"Exactly one pHYs" is defined as follows:** the engine's PNG encoder writes no `pHYs` today, and `_withPhys` drops one if a future encoder does. The drop path is not exercised by a test, because no input reaches it.
5. **The T-9 throwing export** needs a throw inside the PNG paint, and the PNG has no font-bytes parameter to break. A stack-gated measurer does it (see Tests). It is test-only and works through the public `TextMeasurer` interface.
6. **`measurer.clear()` is unobservable** (OWN-clear survives); see the mutant table.

The render layer is frozen after this task.

## Task 6b — the Task 6 review's findings 1 and 3

**Commit:** `d538aa2` test(render): pin the PNG stroke width from below; the existing-pHYs branch (Task 6 review), on `ca163b9`. Not pushed.

**Finding 1 (stroke width from below).**
- The horizontal-line test now also checks the rows `(row − halfWidth + 1).floor()` and `(row + halfWidth − 1).floor()`, which are 2419 and 2423, at all three columns.
- At each of them it expects the exact ink, `[0x5D, 0x40, 0x37, 0xFF]`.

**Finding 3 (the existing-pHYs branch).**
- Lib change: `_withPhys(png, pixelsPerMetre:)` becomes the top-level `@visibleForTesting Uint8List withPhysChunk(Uint8List png, int dpi)`, which computes `round(dpi / 0.0254)` itself. `exportPagePng` calls it.
- New test, "withPhysChunk replaces a pHYs already in the PNG". The input is a real 96 dpi export, reassembled by `_assemble` with a `pHYs` of 1234 px/m, unit 0, placed after `IHDR` and given valid CRCs. The test checks:
  - the input has exactly one `pHYs`;
  - after `withPhysChunk(input, 300)` there is exactly one `pHYs`, as chunk 1, holding `[11811, 11811, 1]`;
  - every CRC is valid by the bit-by-bit CRC;
  - every chunk other than `pHYs` has unchanged data.
- T-11 still passes: `page_export.dart` still names no `VerticesDrawSink`, `TileCache` or `DraftCanvas`.

**Gates** (real tails):
- `CI=true flutter test` (render): `00:55 +1154 ~1 -7: Some tests failed.`
  - That is 1153 + 1.
  - The 7 deduplicated `[E]` failures are exactly text ladder rungs 1–5 and text lod ladder rungs 1–2 (RenderBackend.canvas).
- `flutter analyze`: `No issues found! (ran in 1.5s)`.
- `dart format --output=none --set-exit-if-changed .`: `Formatted 200 files (0 changed)`, `format_exit=0`.
- `export_png_test.dart` + `export_sources_test.dart`: `00:06 +27: All tests passed!`
- Only `page_export.dart` and `export_png_test.dart` changed.

**Mutants** (runner `scratchpad/e6/mut.py`, test `export_png_test.dart`; every run printed `RESTORED diff=0`):

| id | mutation | result |
|---|---|---|
| B6-halfwidth | PNG sink `pixelsPerPaperMm: camera.pixelsPerPaperMm / 2` (stroke width halved) | RED: horizontal-line test, `Expected: [93, 64, 55, 255] Actual: [214, 207, 205, 255]`, reason `inside the stroke, row 2419 at x 2125`. `00:06 +24 -1: Some tests failed.` |
| B6-nodrop | `if (typeAt(at) == 'pHYs') continue;` removed | RED: withPhysChunk test, `Expected: an object with length of <1> Actual: WhereIterable<String>:['pHYs', 'pHYs']`. `00:06 +24 -1: Some tests failed.` |

This supersedes item 4 of "What the spec / plan got wrong": the drop branch is now exercised.
